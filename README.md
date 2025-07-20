<h1 align="center">Bash Anonymity Toolkit</h1>

<p align="center">
  <img src="https://img.shields.io/badge/Bash-Script-green?logo=gnubash">
  <img src="https://img.shields.io/badge/Privacy-Toolkit-blueviolet">
  <img src="https://img.shields.io/badge/Linux-Compatible-lightgrey">
</p>

> ⚠️ This tool is intended for **educational and ethical use only**.

---

## Overview

`anon` is a powerful shell script designed to automate key anonymity and privacy-enhancing tasks for Linux users. It includes:

-  MAC address spoofing
-  Hostname randomization
-  DNS-over-HTTPS (via Cloudflare)
-  Tor network integration
-  ProxyChains configuration
-  Firewall hardening (egress filtering)
-  Telemetry domain blocking
-  Browser user-agent spoofing
-  System log wiping
-  IPv6 disabling
-  Auto-start service configuration

---

## ⚙️ Installation

```bash
git clone https://github.com/yourusername/anon
cd anon
chmod +x anon.sh
sudo ./anon.sh
```
📦 Dependencies
These are automatically installed on first run:

macchanger

tor

proxychains

cloudflared

lolcat

figlet

usage
```bash
anon [options]
```

Example Commands

```bash
anon -start -spoof-time -wipe-logs
anon -stop -boot-disable
```

Available Options

Option	Description
-start	Enable anonymity mode
-stop	Revert settings
-spoof-time	Randomize system clock
-spoof-browser	Launch Firefox with fake user-agent
-wipe-logs	Clear logs and shell history
-disable-ipv6	Disable IPv6 system-wide
-check-env	Check public IP, DNS leaks, and Tor status
-boot-enable	Auto-start at system boot
-boot-disable	Remove auto-start service
-help	Show help message



 How It Works
Uses macchanger to spoof your network MAC address
Edits /etc/hostname and /etc/hosts to randomize hostname
Configures DNS to go through Cloudflare DoH via cloudflared
Starts the tor service and sets up proxychains accordingly
Locks down outgoing network traffic via iptables rules
Optionally wipes logs and disables IPv6 for better stealth

Disclaimer
This tool is provided as-is for research and educational purposes. The author is not responsible for misuse or damage caused by this script. Use responsibly and within the bounds of the law

