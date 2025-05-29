# 🛡️ Rogue Access Point Setup with Kali Linux & Physical Router

> **Note:** This guide is intended strictly for educational and ethical hacking purposes in a controlled environment. Unauthorized use on real-world networks is illegal.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [System Requirements](#system-requirements)
3. [Step-by-Step Implementation](#step-by-step-implementation)

   * [1. Windows Host Internet Sharing](#1-windows-host-internet-sharing)
   * [2. VirtualBox Configuration](#2-virtualbox-configuration)
   * [3. Kali Linux Guest Setup](#3-kali-linux-guest-setup)
   * [4. Spare Router Configuration](#4-spare-router-configuration)
   * [5. DNSMasq Setup](#5-dnsmasq-setup)
   * [6. Network Monitoring (Optional)](#6-network-monitoring-optional)
4. [Testing & Verification](#testing--verification)
5. [Security Considerations](#security-considerations)
6. [Troubleshooting](#troubleshooting)

---

## ✅ Overview

This project simulates a **Rogue Access Point (RAP)** using:

* A physical **spare router** (Wi-Fi AP)
* **Kali Linux VM** acting as the DHCP/DNS gateway using `dnsmasq`
* **Windows host with ICS** for Internet routing

---

## 💻 System Requirements

| Component       | Details                                                                             |
| --------------- | ----------------------------------------------------------------------------------- |
| Host OS         | Windows 11                                                                          |
| Virtual Machine | VirtualBox 7.0+                                                                     |
| Guest OS        | Kali Linux (Debian 64-bit)                                                          |
| Interfaces      | - Internal Wi-Fi (for internet) <br> - TP-Link USB 3.0 Ethernet Adapter (to router) |
| Router          | Spare physical router (with configurable SSID, DHCP)                                |

---

## 🔧 Step-by-Step Implementation

### 1. Windows Host Internet Sharing

* Open **Network Connections** (`Win + R` → `ncpa.cpl`)
* Right-click your **Wi-Fi** connection → `Properties`
* Go to **Sharing** tab:

  * ✅ Check: "Allow other network users to connect..."
  * Select the **TP-Link Ethernet adapter**
  * Apply and restart networking if prompted

---

### 2. VirtualBox Configuration

**Adapter 1 (Primary):**

* Attached to: `Bridged Adapter`
* Name: Your **host's Wi-Fi adapter**
* Promiscuous Mode: `Allow All`
* Cable Connected: ✅ Enabled

**Adapter 2 (Secondary):**

* Attached to: `Bridged Adapter`
* Name: `TP-Link USB GbE Controller`
* Promiscuous Mode: `Allow All`
* Cable Connected: ✅ Enabled

> You can also set Adapter 2 to "Attached to: Host-only Adapter" if needed for isolation.

---

### 3. Kali Linux Guest Setup

#### Update & Install Tools:

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install dnsmasq iptables-persistent netfilter-persistent -y
```

#### Set Up IP on `eth1`:

```bash
sudo ip addr flush dev eth1
sudo ip addr add 192.168.137.1/24 dev eth1
sudo ip link set eth1 up
```

#### Enable IP Forwarding:

```bash
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
```

#### Configure NAT (iptables):

```bash
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
sudo iptables -A FORWARD -i eth0 -o eth1 -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo netfilter-persistent save
```

#### Set Static DNS:

```bash
sudo chattr -i /etc/resolv.conf
echo -e "nameserver 1.1.1.1\nnameserver 1.0.0.1" | sudo tee /etc/resolv.conf
sudo chattr +i /etc/resolv.conf
```

---

### 4. Spare Router Configuration

#### Access Router Admin Panel:

* Connect via browser: `http://192.168.1.1` or `192.168.0.1`
* Login (default): `admin / admin` or as per model

#### Configure:

| Setting         | Value                                    |
| --------------- | ---------------------------------------- |
| SSID            | e.g., `Campus_Free_WiFi`                 |
| Password        | e.g., `freeaccess2025`                   |
| **DHCP Server** | ✅ Disabled                               |
| Operating Mode  | Access Point / Bridge Mode               |
| LAN Port        | Connect to Kali’s `eth1` via TP-Link NIC |

---

### 5. DNSMasq Setup

#### Configuration:

```bash
sudo systemctl stop dnsmasq
sudo nano /etc/dnsmasq.conf
```

Insert:

```ini
interface=eth1
dhcp-range=192.168.137.10,192.168.137.100,12h
dhcp-option=3,192.168.137.1
dhcp-option=6,1.1.1.1,1.0.0.1
log-dhcp
log-queries
log-facility=/var/log/dnsmasq.log
```

Start & Enable Service:

```bash
sudo systemctl start dnsmasq
sudo systemctl enable dnsmasq
```

---

### 6. Network Monitoring (Optional)

#### `network_monitor.sh` Logging Script:

```bash
#!/bin/bash
LOG_DIR="/var/log/rogue_ap"
mkdir -p $LOG_DIR

monitor_connections() {
    while true; do
        date >> $LOG_DIR/connections.log
        arp -a >> $LOG_DIR/connections.log
        echo "---" >> $LOG_DIR/connections.log
        sleep 60
    done
}

monitor_dns() {
    tail -f /var/log/dnsmasq.log | grep --line-buffered "query" >> $LOG_DIR/dns_queries.log
}

monitor_connections &
monitor_dns &
```

Make it executable:

```bash
chmod +x network_monitor.sh
sudo ./network_monitor.sh
```

---

## ✅ Testing & Verification

1. Connect a client device (mobile/laptop) to the **configured SSID**
2. Confirm the assigned IP is from the `192.168.137.x` range:

   ```bash
   ip a
   ```
3. Verify internet access
4. Review `dnsmasq.log` for DHCP and DNS records:

   ```bash
   sudo tail -f /var/log/dnsmasq.log
   ```

---

## 🔐 Security Considerations

* Disable all unnecessary services on Kali
* Regularly review DHCP/DNS logs for suspicious activity
* Add MAC filters (if needed)
* Physically secure your rogue AP hardware

---

## 🛠️ Troubleshooting

| Issue                     | Solution                                             |
| ------------------------- | ---------------------------------------------------- |
| No internet on clients    | Verify NAT and IP forwarding on Kali                 |
| No IP assigned to clients | Ensure `dnsmasq` is running, and router DHCP is off  |
| Interface not found       | Check VirtualBox Adapter assignment                  |
| DNS not resolving         | Reconfigure `/etc/resolv.conf` and restart `dnsmasq` |

---

## 📁 Recommended Repo Structure (For GitHub)

```
rogue-ap-project/
├── README.md
├── dnsmasq.conf
├── network_monitor.sh
├── setup_logs/
│   ├── dnsmasq.log
│   └── connections.log
└── screenshots/
    ├── router_config.png
    └── iptables_rules.png
```

---

Would you like me to generate this as a `README.md` file for your GitHub repo with Markdown formatting preserved?
