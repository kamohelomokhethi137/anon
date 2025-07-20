#!/bin/bash
SCRIPT_NAME="anon"
INSTALL_PATH="/usr/local/bin/$SCRIPT_NAME"
MAC_IFACE="wlan0"
STARTUP_SERVICE="/etc/systemd/system/anon-start.service"

#=== DEPENDENCY CHECK ===#
install_deps() {
    echo "[*] Checking required packages..."
    for pkg in lolcat figlet macchanger tor cloudflared; do
        if ! command -v $pkg &> /dev/null; then
            echo "[+] Installing missing package: $pkg"
            apt install -y $pkg
        fi
    done
}

banner() {
    clear
    figlet "A N O N" | lolcat
    echo "Anonymity Toolkit - $(date)" | lolcat
    echo "--------------------------------------------------" | lolcat
}
spinner() {
    local pid=$!
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %8 ))
        printf "\r[%s] Working..." "${spin:$i:1}"
        sleep 0.1
    done
    printf "\r[✔] Done.             \n"
}

generate_hostname() {
    echo "DESKTOP-$(tr -dc A-Z0-9 </dev/urandom | head -c6)"
}
start_anonymity() {
    echo "[+] Starting anonymity setup..." | lolcat
    (
        # MAC Spoofing
        ifconfig "$MAC_IFACE" down
        macchanger -r "$MAC_IFACE"
        ifconfig "$MAC_IFACE" up

        # Hostname Spoofing
        CURRENT_HOST=$(hostname)
        if [[ "$CURRENT_HOST" == "kali" || "$CURRENT_HOST" == DESKTOP-* ]]; then
            NEW_HOST=$(generate_hostname)
            echo "[*] Spoofing hostname to $NEW_HOST..."
            echo "$NEW_HOST" > /etc/hostname
            hostnamectl set-hostname "$NEW_HOST"
            sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$NEW_HOST/" /etc/hosts
        else
            echo "[*] Hostname already spoofed as '$CURRENT_HOST'. Skipping."
        fi

        # DNS Over HTTPS
        chattr -i /etc/resolv.conf 2>/dev/null
        echo "nameserver 127.0.0.1" > /etc/resolv.conf
        chattr +i /etc/resolv.conf
        nohup cloudflared proxy-dns --address 127.0.0.1 --port 53 >/dev/null 2>&1 &

        # Block Telemetry Domains
        echo "Blocking telemetry domains..."
        cat <<EOF >> /etc/hosts
127.0.0.1 facebook.com
127.0.0.1 google-analytics.com
127.0.0.1 telemetry.microsoft.com
EOF

       
        systemctl enable tor
        systemctl start tor

        sed -i 's/^strict_chain/#strict_chain/' /etc/proxychains.conf
        sed -i 's/^dynamic_chain/#dynamic_chain/' /etc/proxychains.conf
        sed -i 's/^#dynamic_chain/dynamic_chain/' /etc/proxychains.conf
        sed -i '/socks5/d' /etc/proxychains.conf
        echo "socks5 127.0.0.1 9050" >> /etc/proxychains.conf

        # Firewall
        iptables -F
        iptables -P OUTPUT DROP
        iptables -A OUTPUT -m owner --uid-owner debian-tor -j ACCEPT
        iptables -A OUTPUT -d 127.0.0.1 -j ACCEPT
        iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
        iptables -A OUTPUT -p tcp --dport 9050 -j ACCEPT
        iptables -A OUTPUT -j DROP

    
        cat <<EOF > /etc/network/if-pre-up.d/macspoof
#!/bin/bash
macchanger -r $MAC_IFACE
EOF
        chmod +x /etc/network/if-pre-up.d/macspoof
    ) & spinner
}

stop_anonymity() {
    echo "[+] Reverting settings..." | lolcat
    (
        systemctl stop tor
        systemctl disable tor
        pkill -f "cloudflared proxy-dns"

        iptables -F
        iptables -P OUTPUT ACCEPT

        chattr -i /etc/resolv.conf 2>/dev/null
        echo "nameserver 1.1.1.1" > /etc/resolv.conf
        chattr +i /etc/resolv.conf

        echo "kali" > /etc/hostname
        hostnamectl set-hostname kali
        sed -i "s/^127\.0\.1\.1.*/127.0.1.1\tkali/" /etc/hosts

        rm -f /etc/network/if-pre-up.d/macspoof

        sysctl -w net.ipv6.conf.all.disable_ipv6=0
        sysctl -w net.ipv6.conf.default.disable_ipv6=0

        systemctl disable anon-start.service >/dev/null 2>&1
        rm -f "$STARTUP_SERVICE"
    ) & spinner
}

spoof_time() {
    echo "[+] Spoofing system time..." | lolcat
    RANDOM_TIME=$(date -d "$((RANDOM % 365)) days ago" "+%Y-%m-%d %H:%M:%S")
    date -s "$RANDOM_TIME"
    echo "[✔] Time spoofed to $RANDOM_TIME"
}

spoof_browser() {
    echo "[+] Launching Firefox with spoofed user-agent..." | lolcat
    UA_LIST=(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
        "Mozilla/5.0 (X11; Linux x86_64)"
    )
    RAND_UA=${UA_LIST[$RANDOM % ${#UA_LIST[@]}]}
    PROFILE_DIR="/tmp/fx_spoof_$RANDOM"
    mkdir -p "$PROFILE_DIR"
    echo "user_pref(\"general.useragent.override\", \"$RAND_UA\");" > "$PROFILE_DIR/user.js"
    firefox -no-remote -profile "$PROFILE_DIR" &
    echo "[✔] Firefox launched with UA: $RAND_UA"
}

wipe_logs() {
    echo "[+] Wiping logs..." | lolcat
    (
        echo "" > ~/.bash_history
        history -c
        unset HISTFILE

        journalctl --rotate
        journalctl --vacuum-time=1s
        rm -rf /var/log/journal/*
        rm -f /var/log/*.log /var/log/syslog /var/log/auth.log
    ) & spinner
}

disable_ipv6() {
    echo "[+] Disabling IPv6..." | lolcat
    sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1
}

check_environment() {
    echo "[+] Checking environment..." | lolcat
    echo -n "Public IP: " && curl -s https://api.ipify.org || echo "Unavailable"
    echo -n "DNS Leak Test: " && dig +short whoami.opendns.com @resolver1.opendns.com || echo "Unavailable"
    echo "Tor Status:" && curl --socks5 127.0.0.1:9050 https://check.torproject.org || echo "Tor check failed"
}

enable_startup() {
    echo "[+] Enabling startup..." | lolcat
    cat <<EOF > "$STARTUP_SERVICE"
[Unit]
Description=Anon Start Service
After=network.target

[Service]
ExecStart=/usr/local/bin/anon -start
Type=oneshot

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 "$STARTUP_SERVICE"
    systemctl daemon-reexec
    systemctl enable anon-start.service
}

disable_startup() {
    echo "[+] Disabling startup..." | lolcat
    systemctl disable anon-start.service
    rm -f "$STARTUP_SERVICE"
}

show_help() {
    echo ""
    echo "Usage: anon [options]" | lolcat
    echo ""
    echo "Options:"
    echo "  -start           Enable anonymity mode"
    echo "  -stop            Restore all settings to default"
    echo "  -spoof-time      Spoof system clock"
    echo "  -spoof-browser   Launch browser with fake user-agent"
    echo "  -wipe-logs       Clear logs and shell history"
    echo "  -disable-ipv6    Disable IPv6 system-wide"
    echo "  -check-env       Check for IP, DNS, and Tor leaks"
    echo "  -boot-enable     Run anon -start at boot"
    echo "  -boot-disable    Remove auto-start from boot"
    echo "  -help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  anon -start -spoof-time -wipe-logs"
    echo "  anon -stop -boot-disable"
}

install_globally() {
    if [[ "$(realpath "$0")" != "$INSTALL_PATH" ]]; then
        echo "[+] Installing script to '$INSTALL_PATH'..."
        cp "$0" "$INSTALL_PATH"
        chmod +x "$INSTALL_PATH"
        echo "[✔] Installed. Use 'anon' from anywhere."
        exit 0
    fi
}

#=== MAIN ===#
install_deps
install_globally
banner

if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

for arg in "$@"; do
    case "$arg" in
        -start)         start_anonymity ;;
        -stop)          stop_anonymity ;;
        -spoof-time)    spoof_time ;;
        -spoof-browser) spoof_browser ;;
        -wipe-logs)     wipe_logs ;;
        -disable-ipv6)  disable_ipv6 ;;
        -check-env)     check_environment ;;
        -boot-enable)   enable_startup ;;
        -boot-disable)  disable_startup ;;
        -help)          show_help ;;
        *)              echo "[!] Unknown option: $arg"; show_help; exit 1 ;;
    esac
done
