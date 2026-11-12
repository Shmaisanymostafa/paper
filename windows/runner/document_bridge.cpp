#include "document_bridge.h"
#include <cwctype>
#include <cstring>

namespace {
bool ValidPdfPath(const std::wstring& input, std::string* utf8) {
  // Accept fully qualified local drive paths only; no UNC/network URLs, device
  // paths, alternate data streams, command flags or relative paths.
  if (input.size() < 7 || input.size() >= kPaperMaxUnits ||
      !((input[0] >= L'A' && input[0] <= L'Z') || (input[0] >= L'a' && input[0] <= L'z')) ||
      input[1] != L':' || (input[2] != L'\\' && input[2] != L'/') ||
      input.find(L':', 2) != std::wstring::npos ||
      input.find(L'\0') != std::wstring::npos) return false;
  std::wstring suffix = input.substr(input.size() - 4);
  for (auto& c : suffix) c = static_cast<wchar_t>(towlower(c));
  if (suffix != L".pdf") return false;
  DWORD required = GetFullPathNameW(input.c_str(), 0, nullptr, nullptr);
  if (required == 0 || required > kPaperMaxUnits) return false;
  std::vector<wchar_t> full(required);
  DWORD count = GetFullPathNameW(input.c_str(), required, full.data(), nullptr);
  if (count == 0 || count >= required) return false;
  const wchar_t drive[] = {full[0], L':', L'\\', L'\0'};
  const auto drive_type = GetDriveTypeW(drive);
  if (drive_type != DRIVE_FIXED && drive_type != DRIVE_REMOVABLE && drive_type != DRIVE_RAMDISK) return false;
  // Reject directory junctions/symlinks as well, rather than accidentally
  // following a local-looking path to a network location.
  const std::wstring resolved(full.data(), count);
  for (size_t i = 3; i < resolved.size(); ++i) {
    if (resolved[i] != L'\\' && resolved[i] != L'/') continue;
    const DWORD attributes = GetFileAttributesW(resolved.substr(0, i).c_str());
    if (attributes == INVALID_FILE_ATTRIBUTES || (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0) return false;
  }
  WIN32_FILE_ATTRIBUTE_DATA info{};
  if (!GetFileAttributesExW(full.data(), GetFileExInfoStandard, &info) ||
      (info.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_OFFLINE)) != 0 ||
      info.nFileSizeHigh != 0 || info.nFileSizeLow == 0 || info.nFileSizeLow > 200u * 1024u * 1024u) return false;
  int bytes = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, full.data(),
      static_cast<int>(count), nullptr, 0, nullptr, nullptr);
  if (bytes <= 0) return false;
  utf8->resize(static_cast<size_t>(bytes));
  return WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, full.data(),
      static_cast<int>(count), utf8->data(), bytes, nullptr, nullptr) == bytes;
}
}

std::vector<wchar_t> EncodePaperPaths(const std::vector<std::wstring>& paths) {
  if (paths.size() > kPaperMaxFiles) return {};
  std::vector<wchar_t> result;
  for (const auto& path : paths) {
    if (path.empty() || path.find(L'\0') != std::wstring::npos ||
        path.size() + result.size() + 2 > kPaperMaxUnits) return {};
    result.insert(result.end(), path.begin(), path.end());
    result.push_back(L'\0');
  }
  result.push_back(L'\0');
  return result;
}

bool DecodePaperPaths(const COPYDATASTRUCT* data, std::vector<std::wstring>* paths) {
  paths->clear();
  if (!data || data->dwData != kPaperCopyData || !data->lpData ||
      data->cbData < sizeof(wchar_t) || data->cbData > kPaperMaxUnits * sizeof(wchar_t) ||
      data->cbData % sizeof(wchar_t) != 0) return false;
  // memcpy avoids making alignment assumptions about the IPC buffer.
  const size_t units = data->cbData / sizeof(wchar_t);
  std::vector<wchar_t> text(units);
  memcpy(text.data(), data->lpData, data->cbData);
  if (text.back() != L'\0') return false;
  size_t start = 0;
  for (size_t i = 0; i < units; ++i) {
    if (text[i] != L'\0') continue;
    if (i == start) return i == units - 1;
    if (paths->size() >= kPaperMaxFiles) return false;
    paths->emplace_back(text.data() + start, i - start);
    start = i + 1;
  }
  return false;  // Missing final empty terminator.
}

void DocumentBridge::Connect(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "technology.cave.paper/documents", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "ready") {
      ready_ = true;
      flutter::EncodableList paths;
      for (const auto& path : queued_) paths.emplace_back(path);
      queued_.clear();
      result->Success(flutter::EncodableValue(paths));
    } else if (call.method_name() == "release") {
      const auto* path = call.arguments() ? std::get_if<std::string>(call.arguments()) : nullptr;
      if (path) {
        if (path->empty()) failure_pending_ = false;
        auto found = active_.find(*path);
        if (found != active_.end()) {
          --outstanding_;
          if (--found->second == 0) active_.erase(found);
        }
      }
      // These are source paths, not temporary copies. Never delete on release.
      result->Success();
    } else {
      result->NotImplemented();
    }
  });
}

void DocumentBridge::Disconnect() {
  if (channel_) channel_->SetMethodCallHandler(nullptr);
  channel_.reset();
  ready_ = false;
}

void DocumentBridge::Emit(const std::string& path) {
  if (ready_ && channel_) {
    channel_->InvokeMethod("open", std::make_unique<flutter::EncodableValue>(path));
  } else {
    queued_.push_back(path);
  }
}

void DocumentBridge::Failure() {
  const auto now = GetTickCount64();
  if (failure_pending_ || (last_failure_ != 0 && now - last_failure_ < 2000)) return;
  failure_pending_ = true;
  last_failure_ = now;
  Emit("");  // Existing Dart validation displays localized importError.
}

bool DocumentBridge::Accept(const std::vector<std::wstring>& paths) {
  if (paths.size() > kPaperMaxFiles || paths.size() + outstanding_ > kPaperMaxFiles) {
    Failure();
    return false;
  }
  std::vector<std::string> validated;
  for (const auto& path : paths) {
    std::string utf8;
    if (!ValidPdfPath(path, &utf8)) { Failure(); return false; }
    validated.push_back(std::move(utf8));
  }
  for (const auto& path : validated) {
    ++outstanding_;
    ++active_[path];
    Emit(path);
  }
  return true;
}
