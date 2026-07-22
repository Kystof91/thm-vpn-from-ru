@echo off
REM Connect to TryHackMe OpenVPN THROUGH Happ Plus (outer VPN).
REM Windows — short helper. Install OpenVPN first.
REM
REM 1) Save your THM TCP .ovpn as: %USERPROFILE%\thm-vpn\thm-tcp.ovpn
REM    (THM → Access → OpenVPN → EU-West TCP / TCP 443)
REM 2) Start Happ Plus → Connect
REM 3) Run this script as Administrator (or use OpenVPN GUI)

set "CONFIG=%THM_OVPN_CONFIG%"
if "%CONFIG%"=="" set "CONFIG=%USERPROFILE%\thm-vpn\thm-tcp.ovpn"

echo === Connect to TryHackMe ===
echo.

where openvpn >nul 2>&1
if errorlevel 1 (
  echo [!] openvpn.exe not in PATH.
  echo     Install OpenVPN and either add it to PATH or open the .ovpn in OpenVPN GUI.
  echo     Config expected at: %CONFIG%
  pause
  exit /b 1
)

if not exist "%CONFIG%" (
  echo [!] Config not found: %CONFIG%
  echo     Download TCP .ovpn from TryHackMe Access and save it there.
  pause
  exit /b 1
)

echo [*] Make sure Happ Plus is ALREADY connected.
echo [*] Starting OpenVPN with: %CONFIG%
echo [*] Stop with Ctrl+C, then disconnect Happ in the app UI.
echo.

openvpn --config "%CONFIG%" --verb 3
pause
