#!/bin/bash
# Connect to TryHackMe OpenVPN *through* Happ Plus (outer VPN).
# macOS. Run after Happ Plus is connected.
#
# 1) Put your THM TCP .ovpn here (download from THM → Access → OpenVPN → EU-West TCP):
#    ~/thm-vpn/thm-tcp.ovpn
# 2) Start Happ Plus → Connect
# 3) Double-click this file or: bash ~/thm-vpn/macos/connect-thm.command

set -u

CONFIG="${THM_OVPN_CONFIG:-$HOME/thm-vpn/thm-tcp.ovpn}"

echo "=== Connect to TryHackMe ==="
echo ""

if ! pgrep -f "Happ.app" > /dev/null; then
    echo "⚠️  Happ Plus is not running."
    echo "Start Happ Plus, connect the VPN, then run this script again."
    echo ""
    read -r -p "Press Enter to exit..."
    exit 1
fi

echo "✅ Happ Plus is running"

if [ ! -f "$CONFIG" ]; then
    echo "❌ OpenVPN config not found: $CONFIG"
    echo "Download .ovpn from THM → Access → OpenVPN → TCP (EU-West)"
    echo "and save it as ~/thm-vpn/thm-tcp.ovpn"
    echo "(or set THM_OVPN_CONFIG=/path/to/your.ovpn)"
    read -r -p "Press Enter to exit..."
    exit 1
fi

echo "✅ Config found: $CONFIG"
echo ""
echo "Connecting to THM (TCP 443 via Happ Plus)..."
echo "Disconnect with Ctrl+C, then run disconnect-thm.command"
echo ""

sudo openvpn --config "$CONFIG" --verb 3
