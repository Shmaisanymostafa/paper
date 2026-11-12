#include "single_instance.h"
#include "document_bridge.h"
#include <sddl.h>

namespace {
std::wstring UserSid(HANDLE process) {
  HANDLE token = nullptr;
  if (!OpenProcessToken(process, TOKEN_QUERY, &token)) return {};
  DWORD size = 0;
  GetTokenInformation(token, TokenUser, nullptr, 0, &size);
  if (size == 0 || size > 65536) { CloseHandle(token); return {}; }
  std::vector<BYTE> buffer(size);
  bool ok = GetTokenInformation(token, TokenUser, buffer.data(), size, &size) != FALSE;
  CloseHandle(token);
  if (!ok) return {};
  LPWSTR text = nullptr;
  if (!ConvertSidToStringSidW(reinterpret_cast<TOKEN_USER*>(buffer.data())->User.Sid, &text)) return {};
  std::wstring sid(text);
  LocalFree(text);
  return sid;
}
std::wstring Executable(HANDLE process) {
  std::vector<wchar_t> text(32768);
  DWORD size = static_cast<DWORD>(text.size());
  if (!QueryFullProcessImageNameW(process, 0, text.data(), &size)) return {};
  return std::wstring(text.data(), size);
}
struct Search {
  const std::wstring& sid;
  const std::wstring& executable;
  HWND window = nullptr;
  DWORD pid = 0;
};
BOOL CALLBACK FindEndpoint(HWND window, LPARAM parameter) {
  auto* search = reinterpret_cast<Search*>(parameter);
  if (!GetPropW(window, kPaperEndpoint)) return TRUE;
  DWORD pid = 0;
  GetWindowThreadProcessId(window, &pid);
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (!process) return TRUE;
  const auto exe = Executable(process);
  bool match = !exe.empty() && _wcsicmp(exe.c_str(), search->executable.c_str()) == 0 &&
      UserSid(process) == search->sid;
  CloseHandle(process);
  if (!match) return TRUE;
  search->window = window;
  search->pid = pid;
  return FALSE;
}
}

SingleInstance::SingleInstance() {
  sid_ = UserSid(GetCurrentProcess());
  executable_ = Executable(GetCurrentProcess());
  if (sid_.empty() || executable_.empty()) return;
  // Restrict mutex access to this user and SYSTEM; no machine-wide default or
  // registry setting is modified. Named-object collisions fail closed.
  const std::wstring sddl = L"D:P(A;;GA;;;SY)(A;;GA;;;" + sid_ + L")";
  PSECURITY_DESCRIPTOR descriptor = nullptr;
  if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl.c_str(), SDDL_REVISION_1, &descriptor, nullptr)) return;
  SECURITY_ATTRIBUTES attributes{sizeof(SECURITY_ATTRIBUTES), descriptor, FALSE};
  const std::wstring name = L"Global\\CavePaper.Documents.v1." + sid_;
  mutex_ = CreateMutexW(&attributes, FALSE, name.c_str());
  LocalFree(descriptor);
  if (!mutex_) return;
  DWORD wait = WaitForSingleObject(mutex_, 0);
  primary_ = wait == WAIT_OBJECT_0 || wait == WAIT_ABANDONED;
}
SingleInstance::~SingleInstance() {
  if (mutex_) {
    if (primary_) ReleaseMutex(mutex_);
    CloseHandle(mutex_);
  }
}
bool SingleInstance::Forward(const std::vector<std::wstring>& paths) const {
  if (!mutex_ || sid_.empty() || executable_.empty()) return false;
  const auto payload = EncodePaperPaths(paths);
  if (payload.empty()) return false;
  // Retry discovery only, never retry a send with an uncertain outcome.
  // A same-user process in another Windows session stays locked; ask the user
  // to close it rather than starting another writer across desktop sessions.
  for (int attempt = 0; attempt < 50; ++attempt) {
    Search search{sid_, executable_};
    EnumWindows(FindEndpoint, reinterpret_cast<LPARAM>(&search));
    if (search.window) {
      AllowSetForegroundWindow(search.pid);
      COPYDATASTRUCT data{kPaperCopyData, static_cast<DWORD>(payload.size() * sizeof(wchar_t)),
                          const_cast<wchar_t*>(payload.data())};
      DWORD_PTR reply = 0;
      const auto sent = SendMessageTimeoutW(search.window, WM_COPYDATA, 0,
          reinterpret_cast<LPARAM>(&data), SMTO_ABORTIFHUNG | SMTO_BLOCK, 3000, &reply);
      return sent != 0 && reply == 1;
    }
    Sleep(100);
  }
  return false;
}
