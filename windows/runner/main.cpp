#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <wchar.h>
#include <stdlib.h>

#include "flutter_window.h"
#include "utils.h"

// Disables ggml-vulkan's cooperative-matrix code paths via process env
// vars set before any DLL load. The upstream ggml-vulkan.dll crashes
// inside its cooperative-matrix code on NVIDIA Blackwell drivers and
// AMD AMDVLK iGPUs (see project_gpu_blackwell_cuda memory). The DLL
// reads GGML_VK_DISABLE_COOPMAT[2] via getenv() at backend load time;
// experimentally, setting them in-process from this runner doesn't
// reach the DLL's CRT (it's statically linked, with its own env
// block). The only reliable path is to spawn a fresh process with the
// env vars already on its environment block, so do that exactly once
// when this is the unprepared entry process.
static int RelaunchWithVulkanEnvIfNeeded() {
  wchar_t probe[8];
  if (::GetEnvironmentVariableW(L"GGML_VK_DISABLE_COOPMAT", probe, 8) != 0) {
    return -1;  // already set (launch.json env or prior relaunch), continue
  }
  ::SetEnvironmentVariableW(L"GGML_VK_DISABLE_COOPMAT", L"1");
  ::SetEnvironmentVariableW(L"GGML_VK_DISABLE_COOPMAT2", L"1");

  wchar_t exePath[MAX_PATH];
  if (::GetModuleFileNameW(nullptr, exePath, MAX_PATH) == 0) {
    return EXIT_FAILURE;
  }
  // CreateProcessW writes into lpCommandLine; pass a writable copy.
  wchar_t* cmdBuf = ::_wcsdup(::GetCommandLineW());
  if (!cmdBuf) {
    return EXIT_FAILURE;
  }
  STARTUPINFOW si = {sizeof(si)};
  PROCESS_INFORMATION pi = {};
  BOOL ok = ::CreateProcessW(exePath, cmdBuf, nullptr, nullptr, FALSE, 0,
                             nullptr, nullptr, &si, &pi);
  ::free(cmdBuf);
  if (!ok) {
    return EXIT_FAILURE;
  }
  ::CloseHandle(pi.hThread);
  ::CloseHandle(pi.hProcess);
  return EXIT_SUCCESS;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  const int relaunchResult = RelaunchWithVulkanEnvIfNeeded();
  if (relaunchResult != -1) {
    return relaunchResult;
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

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"cardwave", origin, size)) {
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
