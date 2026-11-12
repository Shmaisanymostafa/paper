#ifndef CAVE_PAPER_DOCUMENT_BRIDGE_H_
#define CAVE_PAPER_DOCUMENT_BRIDGE_H_
#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <map>
#include <memory>
#include <string>
#include <vector>

inline constexpr wchar_t kPaperEndpoint[] = L"technology.cave.paper.documents.v1";
inline constexpr ULONG_PTR kPaperCopyData = 0x43504431;
inline constexpr size_t kPaperMaxUnits = 32768;
inline constexpr size_t kPaperMaxFiles = 8;

// Same-user IPC requests only file imports, never code, commands or deletion.
bool DecodePaperPaths(const COPYDATASTRUCT* data, std::vector<std::wstring>* paths);
std::vector<wchar_t> EncodePaperPaths(const std::vector<std::wstring>& paths);

class DocumentBridge {
 public:
  void Connect(flutter::BinaryMessenger* messenger);
  void Disconnect();
  bool Accept(const std::vector<std::wstring>& paths);
 private:
  void Failure();
  void Emit(const std::string& path);
  bool ready_ = false;
  bool failure_pending_ = false;
  ULONGLONG last_failure_ = 0;
  size_t outstanding_ = 0;
  std::map<std::string, size_t> active_;
  std::vector<std::string> queued_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};
#endif
