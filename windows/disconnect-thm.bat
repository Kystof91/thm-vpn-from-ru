@echo off
REM Soft disconnect helper for Windows.
REM Prefer: stop OpenVPN first, then Disconnect in Happ Plus UI.
REM Avoid killing Happ from Task Manager while the tunnel is up — kill-switch leftovers hurt.

echo === Disconnect THM / Happ (Windows) ===
echo.

echo [1/3] Stopping openvpn.exe ...
taskkill /IM openvpn.exe /F >nul 2>&1
if errorlevel 1 (
  echo     openvpn was not running (or already stopped)
) else (
  echo     openvpn stopped
)

echo [2/3] Open Happ Plus → click Disconnect (do this in the app UI).
echo       Do NOT only End Task the app if you can avoid it.
echo.

echo [3/3] Optional: reset Winsock / flush DNS if internet stays dead
echo       (run Command Prompt as Administrator):
echo         ipconfig /flushdns
echo         netsh winsock reset
echo         netsh int ip reset
echo       Then reboot if still broken.
echo.

pause
