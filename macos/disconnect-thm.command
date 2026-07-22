#!/bin/bash
# Safely tear down THM OpenVPN + Happ Plus and restore normal internet on macOS.
#
# Important: do NOT only pkill Happ — that can leave NECP kill-switch stuck
# ("no internet until reboot"). This script stops the VPN profile cleanly first.

set -u

WIFI_SERVICE="${WIFI_SERVICE:-Wi-Fi}"
HAPP_VPN_NAME="${HAPP_VPN_NAME:-Happ Plus}"
PRIMARY_IF="${PRIMARY_IF:-en0}"
# Optional: your LAN gateway for a quick ping check (change if needed)
LAN_GATEWAY="${LAN_GATEWAY:-192.168.0.1}"

echo "=== Disconnect THM / Happ + restore internet ==="
echo ""

if ! sudo -v; then
    echo "❌ Administrator password required"
    read -r -p "Press Enter to exit..."
    exit 1
fi

# Keep sudo alive while the script runs
while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

step() { echo ""; echo "→ $1"; }

########################################
# 1. OpenVPN (THM)
########################################
step "1/7 Stop OpenVPN (THM)"
if pgrep -x openvpn >/dev/null 2>&1 || pgrep -f '/openvpn ' >/dev/null 2>&1; then
    sudo killall openvpn 2>/dev/null || true
    sleep 1
    if pgrep -x openvpn >/dev/null 2>&1; then
        sudo killall -9 openvpn 2>/dev/null || true
        sleep 1
    fi
    echo "   OpenVPN: stopped"
else
    echo "   OpenVPN: was not running"
fi

########################################
# 2. Clean disconnect of Happ VPN profile
########################################
step "2/7 Disconnect VPN profile «Happ Plus»"
if scutil --nc list 2>/dev/null | grep -q "Happ Plus"; then
    for _ in 1 2 3; do
        scutil --nc stop "$HAPP_VPN_NAME" 2>/dev/null || true
        sleep 1
        status="$(scutil --nc status "$HAPP_VPN_NAME" 2>/dev/null | head -1 || true)"
        echo "   status: ${status:-unknown}"
        case "$status" in
            Disconnected*|Disconnecting*) break ;;
        esac
    done
else
    echo "   Happ Plus profile not found in scutil"
fi

########################################
# 3. Quit Happ app
########################################
step "3/7 Quit Happ"
osascript -e 'tell application "Happ" to quit' 2>/dev/null || true
osascript -e 'quit app "Happ"' 2>/dev/null || true
sleep 2

pkill -f 'Happ.app/Contents/MacOS/Happ' 2>/dev/null || true
pkill -f 'su.ffg.happ.plus.tunnel' 2>/dev/null || true
pkill -f 'Tunnel.appex' 2>/dev/null || true
sleep 1

if pgrep -f 'Happ.app/Contents/MacOS/Happ' >/dev/null 2>&1; then
    echo "   Happ still alive — force kill"
    pkill -9 -f 'Happ.app/Contents/MacOS/Happ' 2>/dev/null || true
    pkill -9 -f 'su.ffg.happ.plus.tunnel' 2>/dev/null || true
    pkill -9 -f 'Tunnel.appex' 2>/dev/null || true
    sleep 1
fi
echo "   Happ: $(pgrep -f 'Happ.app/Contents/MacOS/Happ' >/dev/null 2>&1 && echo 'STILL RUNNING' || echo 'stopped')"

########################################
# 4. Reset NECP / Network Extension session
########################################
step "4/7 Reset Network Extension (NECP kill-switch)"
sudo killall -9 nesessionmanager 2>/dev/null || true
sleep 2
sudo launchctl kickstart -k system/com.apple.nesessionmanager 2>/dev/null || true
sleep 2
echo "   nesessionmanager restarted"

########################################
# 5. Clear proxy / DNS / refresh DHCP on Wi-Fi
########################################
step "5/7 Clear proxy, DNS, renew DHCP"

sudo networksetup -setwebproxystate "$WIFI_SERVICE" off
sudo networksetup -setsecurewebproxystate "$WIFI_SERVICE" off
sudo networksetup -setsocksfirewallproxystate "$WIFI_SERVICE" off
sudo networksetup -setftpproxystate "$WIFI_SERVICE" off 2>/dev/null || true
sudo networksetup -setproxyautodiscovery "$WIFI_SERVICE" off 2>/dev/null || true
sudo networksetup -setautoproxystate "$WIFI_SERVICE" off 2>/dev/null || true

sudo networksetup -setwebproxy "$WIFI_SERVICE" "" 0 off 2>/dev/null || true
sudo networksetup -setsecurewebproxy "$WIFI_SERVICE" "" 0 off 2>/dev/null || true
sudo networksetup -setsocksfirewallproxy "$WIFI_SERVICE" "" 0 off 2>/dev/null || true

sudo networksetup -setdnsservers "$WIFI_SERVICE" Empty
sleep 1

if ifconfig "$PRIMARY_IF" >/dev/null 2>&1; then
    sudo ipconfig set "$PRIMARY_IF" DHCP 2>/dev/null || true
    sleep 2
fi

sudo dscacheutil -flushcache 2>/dev/null || true
sudo killall -HUP mDNSResponder 2>/dev/null || true
echo "   Wi-Fi: proxy off, DNS=DHCP, lease renewed"

########################################
# 6. Final stop of Happ profile
########################################
step "6/7 Final stop Happ Plus"
scutil --nc stop "$HAPP_VPN_NAME" 2>/dev/null || true
sleep 1

########################################
# 7. Connectivity check
########################################
step "7/7 Check normal internet"

ok=0

echo -n "   LAN gateway ${LAN_GATEWAY}: "
if ping -c 1 -W 2000 "$LAN_GATEWAY" >/dev/null 2>&1; then
    echo "OK"
else
    echo "FAIL (set LAN_GATEWAY if your router IP differs)"
fi

echo -n "   ping 1.1.1.1: "
if ping -c 2 -W 2000 1.1.1.1 >/dev/null 2>&1; then
    echo "OK"
    ok=1
else
    echo "FAIL (ICMP often blocked — checking TCP)"
fi

echo -n "   TCP 1.1.1.1:443: "
if nc -z -G 3 1.1.1.1 443 >/dev/null 2>&1; then
    echo "OK"
    ok=1
else
    echo "FAIL"
fi

echo -n "   HTTPS example.com: "
if curl -sS -m 5 -o /dev/null -w "%{http_code}" https://example.com 2>/dev/null | grep -qE '^[23]'; then
    echo "OK"
    ok=1
else
    echo "FAIL"
fi

echo -n "   public IP: "
pub="$(curl -4 -sS -m 5 https://api.ipify.org 2>/dev/null || true)"
if [ -n "$pub" ]; then
    echo "$pub"
    ok=1
else
    echo "not received"
fi

echo ""
echo "=== Summary ==="
echo "Happ app:  $(pgrep -f 'Happ.app/Contents/MacOS/Happ' >/dev/null 2>&1 && echo 'STILL RUNNING' || echo 'stopped')"
echo "OpenVPN:   $(pgrep -x openvpn >/dev/null 2>&1 && echo 'STILL RUNNING' || echo 'stopped')"
vpn_line="$(scutil --nc status "$HAPP_VPN_NAME" 2>/dev/null | head -1 || echo n/a)"
echo "Happ VPN:  $vpn_line"
echo ""

if [ "$ok" -eq 1 ]; then
    echo "✅ Internet should work on the normal path (no Happ / THM)."
else
    echo "⚠️  Still down. Usually helps:"
    echo "   1) open Happ → Connect → immediately Disconnect in the UI"
    echo "   2) reboot Mac (full NECP reset)"
    echo ""
    echo "Soft-reset retry in 3s..."
    sleep 3
    sudo killall -9 nesessionmanager 2>/dev/null || true
    sleep 2
    sudo ipconfig set "$PRIMARY_IF" DHCP 2>/dev/null || true
    echo -n "   HTTPS example.com again: "
    if curl -sS -m 5 -o /dev/null https://example.com 2>/dev/null; then
        echo "OK — recovered"
    else
        echo "FAIL — reboot Mac"
    fi
fi

echo ""
read -r -p "Press Enter to exit..."
