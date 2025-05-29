#!/bin/bash

# Interface to monitor (your RAP interface)
IFACE="eth1"

# Output log file
LOG_FILE="device_fingerprint_log.txt"

# Capture duration (in seconds, optional)
CAPTURE_DURATION=60

# Temporary pcap file
PCAP_FILE="capture_temp.pcap"

# Local OUI file (optional: download from IEEE or use macchanger)
OUI_FILE="/usr/share/ieee-data/oui.txt"

echo "[+] Starting passive fingerprint logging on $IFACE..."
echo "[+] Logging to $LOG_FILE"
echo "Timestamp: $(date)" > "$LOG_FILE"
echo "==============================================" >> "$LOG_FILE"

# Capture packets (DNS and HTTP)
sudo timeout "$CAPTURE_DURATION" tcpdump -i "$IFACE" -nn -s 0 port 53 or port 80 -w "$PCAP_FILE"

# Parse packets using tshark (requires tshark)
if ! command -v tshark &> /dev/null; then
    echo "[!] tshark not found. Installing..."
    sudo apt install -y tshark
fi

echo "[+] Extracting IPs, DNS queries, and User-Agents..."

tshark -r "$PCAP_FILE" \
    -Y 'dns.qry.name or http.request' \
    -T fields \
    -e eth.src -e ip.src -e dns.qry.name -e http.user_agent |
while IFS=$'\t' read -r MAC IP DNS_QUERY UA; do
    [ -z "$MAC" ] && continue

    # Get vendor from macchanger (fallback to OUI file)
    VENDOR=$(macchanger -l | grep -i "${MAC:0:8}" | awk -F'\t' '{print $3}')
    [ -z "$VENDOR" ] && VENDOR="Unknown Vendor"

    echo "------------------------------" >> "$LOG_FILE"
    echo "MAC: $MAC" >> "$LOG_FILE"
    echo "IP: $IP" >> "$LOG_FILE"
    echo "Vendor: $VENDOR" >> "$LOG_FILE"
    [ -n "$DNS_QUERY" ] && echo "DNS Query: $DNS_QUERY" >> "$LOG_FILE"
    [ -n "$UA" ] && echo "User-Agent: $UA" >> "$LOG_FILE"
done

echo "[+] Log complete: $LOG_FILE"
rm -f "$PCAP_FILE"

