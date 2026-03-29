#ifndef RUNNER_RUN_LOOP_H_
#define RUNNER_RUN_LOOP_H_

#include <windows.h>

#include <cstdint>
#include <functional>

// A runloop that will service flutter engine tasks.
class RunLoop {
 public:
  RunLoop();
  ~RunLoop();

  // Prevent copying.
  RunLoop(RunLoop const&) = delete;
  RunLoop& operator=(RunLoop const&) = delete;

  // Runs the main loop until the window is closed.
  void Run();

  // Registers a callback to be called when the next run loop iteration
  // completes.
  void RegisterFlutterInstance(
      uint64_t flutter_instance_id,
      std::function<void()> idle_callback);

  // Unregisters a previously registered callback.
  void UnregisterFlutterInstance(uint64_t flutter_instance_id);

  // Wakes up the run loop to service tasks.
  void WakeUp();

 private:
  struct FlutterTaskTimePoint;

  // Returns the timeout value to use for the next MsgWaitForMultipleObjectsEx
  // call.
  DWORD WaitUntilEventOrTimeout(DWORD timeout_ms);

  // Processes all currently pending messages.
  void ProcessMessages();

  // Runs a single iteration of the run loop.
  bool RunOnce();
};

#endif  // RUNNER_RUN_LOOP_H_
