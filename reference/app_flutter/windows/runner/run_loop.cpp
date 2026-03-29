#include "run_loop.h"

#include <flutter_windows.h>
#include <windows.h>

RunLoop::RunLoop() {}

RunLoop::~RunLoop() {}

void RunLoop::Run() {
  // Run the message loop.
  MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }
}

void RunLoop::RegisterFlutterInstance(
    uint64_t flutter_instance_id,
    std::function<void()> idle_callback) {
  // Not used in this minimal runner.
}

void RunLoop::UnregisterFlutterInstance(uint64_t flutter_instance_id) {
  // Not used in this minimal runner.
}

void RunLoop::WakeUp() {
  PostMessage(nullptr, WM_NULL, 0, 0);
}

DWORD RunLoop::WaitUntilEventOrTimeout(DWORD timeout_ms) {
  return ::MsgWaitForMultipleObjectsEx(0, nullptr, timeout_ms, QS_ALLINPUT,
                                       MWMO_INPUTAVAILABLE);
}

void RunLoop::ProcessMessages() {
  MSG msg;
  while (::PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) {
    if (msg.message == WM_QUIT) {
      return;
    }
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }
}
