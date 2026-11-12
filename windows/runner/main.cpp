#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shellapi.h>
#include "single_instance.h"

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  int count = 0;
  LPWSTR* args = CommandLineToArgvW(GetCommandLineW(), &count);
  if (!args) return EXIT_FAILURE;
  std::vector<std::wstring> documents;
  if (count > static_cast<int>(kPaperMaxFiles) + 1) {
    LocalFree(args);
    MessageBoxW(nullptr, L"Please open at most eight PDFs at a time.", L"Cave Paper", MB_OK | MB_ICONWARNING);
    return EXIT_FAILURE;
  }
  for (int i = 1; i < count; ++i) documents.emplace_back(args[i]);
  LocalFree(args);
  if (EncodePaperPaths(documents).empty()) return EXIT_FAILURE;
  SingleInstance instance_lock;
  if (!instance_lock.primary()) {
    if (instance_lock.Forward(documents)) return EXIT_SUCCESS;
    MessageBoxW(nullptr,
        L"Cave Paper could not accept this request. It may be busy, running in another session, or unable to access the PDFs. Close its other window and retry. A second copy will not open.",
        L"Cave Paper", MB_OK | MB_ICONWARNING);
    return EXIT_FAILURE;
  }
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Cave Paper", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);
  window.OpenDocuments(documents);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0) > 0) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
