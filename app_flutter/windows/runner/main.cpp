#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "run_loop.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., started from "flutter run") or create
  // a new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);

  // Compact phone-sized default, resizable but enforces a minimum size.
  // Center on the primary monitor.
  const int kWidth  = 360;
  const int kHeight = 680;
  int screenX = GetSystemMetrics(SM_CXSCREEN);
  int screenY = GetSystemMetrics(SM_CYSCREEN);
  int originX = (screenX - kWidth)  / 2;
  int originY = (screenY - kHeight) / 2;

  Win32Window::Point origin(originX > 0 ? originX : 0,
                            originY > 0 ? originY : 0);
  Win32Window::Size size(kWidth, kHeight);
  if (!window.Create(L"PacketDial", origin, size)) {
    return EXIT_FAILURE;
  }

  window.SetQuitOnClose(true);


  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
