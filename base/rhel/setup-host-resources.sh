#!/bin/bash
#
# Cuttlefish Host Resources Setup Script
# Configures network infrastructure for Cuttlefish Android Virtual Devices
#
# Copyright (C) 2025 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

# Source configuration from /etc/sysconfig/
if [ -f /etc/sysconfig/cuttlefish-host-resources ]; then
    source /etc/sysconfig/cuttlefish-host-resources
fi

# Configuration defaults
num_cvd_accounts=${num_cvd_accounts:-10}
wifi_bridge_interface=${wifi_bridge_interface:-cvd-wbr}
ethernet_bridge_interface=${ethernet_bridge_interface:-cvd-ebr}
ipv4_bridge=${ipv4_bridge:-1}
ipv6_bridge=${ipv6_bridge:-1}
dns_servers=${dns_servers:-8.8.8.8,8.8.4.4}
dns6_servers=${dns6_servers:-2001:4860:4860::8888,2001:4860:4860::8844}

if [ -z ${bridge_interface} ]; then
  create_bridges=1
fi

# Detect ebtables (prefer legacy for broute support)
ebtables=$(which ebtables-legacy 2>/dev/null)
ebtables=${ebtables:-ebtables}

# Detect iptables (prefer legacy for consistency)
iptables=$(which iptables-legacy 2>/dev/null)
iptables=${iptables:-iptables}

# Detect firewalld vs iptables (Task 3.2.3)
use_firewalld=0
default_zone=""
if systemctl is-active --quiet firewalld; then
    use_firewalld=1
    default_zone=$(firewall-cmd --get-default-zone)
    echo "Detected firewalld active, using zone: $default_zone"
else
    echo "firewalld inactive, using direct iptables"
fi

# Ensure runtime directories exist
mkdir -p /run /var/run

#
# Function: start_dnsmasq
# Start DHCP server on an interface (Task 3.2.5)
#
start_dnsmasq() {
    local interface="$1"
    local listen_address="$2"
    local dhcp_range="$3"
    local ipv6_prefix="$4"
    local ipv6_prefix_length="$5"

    local ipv6_args=""
    if [ -n "${ipv6_prefix}" ] && [ -n "${ipv6_prefix_length}" ]; then
        ipv6_args="--dhcp-range=${ipv6_prefix},ra-stateless,${ipv6_prefix_length} --enable-ra"
    fi

    dnsmasq \
      --port=0 \
      --strict-order \
      --except-interface=lo \
      --interface="${interface}" \
      --listen-address="${listen_address}" \
      --bind-interfaces \
      --dhcp-range="${dhcp_range}" \
      --dhcp-option="option:dns-server,${dns_servers}" \
      --dhcp-option="option6:dns-server,${dns6_servers}" \
      --conf-file="" \
      --pid-file=/var/run/cuttlefish-dnsmasq-"${interface}".pid \
      --dhcp-leasefile=/var/run/cuttlefish-dnsmasq-"${interface}".leases \
      --dhcp-no-override \
      ${ipv6_args}
}

#
# Function: stop_dnsmasq
# Stop DHCP server on an interface
#
stop_dnsmasq() {
    local interface="$1"
    if [ -f /var/run/cuttlefish-dnsmasq-"${interface}".pid ]; then
        kill $(cat /var/run/cuttlefish-dnsmasq-"${interface}".pid) 2>/dev/null || true
        rm -f /var/run/cuttlefish-dnsmasq-"${interface}".pid
    fi
}

#
# Function: create_tap
# Create a tap interface (Task 3.2.2)
#
create_tap() {
    local tap="$1"
    ip tuntap add dev "${tap}" mode tap group cvdnetwork vnet_hdr
    ip link set dev "${tap}" up
}

#
# Function: destroy_tap
# Destroy a tap interface
#
destroy_tap() {
    local tap="$1"
    ip link set dev "${tap}" down 2>/dev/null || true
    ip link delete "${tap}" 2>/dev/null || true
}

#
# Function: create_interface
# Create a tap interface with IP and NAT
# Used for mobile and WiFi AP interfaces (standalone, not bridged)
#
create_interface() {
    local tap="$1"
    local ip_base="$2"
    local index="$3"
    local ipv6_prefix="$4"
    local ipv6_prefix_length="$5"

    local gateway="${ip_base}.$((4*${index} - 3))"
    local netmask="/30"
    local network="${ip_base}.$((4*${index} - 4))${netmask}"

    create_tap "${tap}"
    ip addr add "${gateway}${netmask}" broadcast + dev "${tap}"

    if [ -n "${ipv6_prefix}" ] && [ -n "${ipv6_prefix_length}" ]; then
        ip -6 addr add "${ipv6_prefix}1/${ipv6_prefix_length}" dev "${tap}"
    fi

    # Configure NAT (Task 3.2.4)
    if [ $use_firewalld -eq 1 ]; then
        # Use firewalld for NAT
        firewall-cmd --zone="${default_zone}" --add-rich-rule="rule family=ipv4 source address=${network} masquerade" --permanent 2>/dev/null || true
    else
        # Use iptables for NAT
        "${iptables}" -t nat -A POSTROUTING -s "${network}" -j MASQUERADE
    fi
}

#
# Function: destroy_interface
# Destroy a tap interface and remove NAT rules
#
destroy_interface() {
    local tap="$1"
    local ip_base="$2"
    local index="$3"
    local ipv6_prefix="$4"
    local ipv6_prefix_length="$5"

    local gateway="${ip_base}.$((4*${index} - 3))"
    local netmask="/30"
    local network="${ip_base}.$((4*${index} - 4))${netmask}"

    # Remove NAT rules
    if [ $use_firewalld -eq 1 ]; then
        firewall-cmd --zone="${default_zone}" --remove-rich-rule="rule family=ipv4 source address=${network} masquerade" --permanent 2>/dev/null || true
    else
        "${iptables}" -t nat -D POSTROUTING -s "${network}" -j MASQUERADE 2>/dev/null || true
    fi

    ip addr del "${gateway}${netmask}" dev "${tap}" 2>/dev/null || true

    if [ -n "${ipv6_prefix}" ] && [ -n "${ipv6_prefix_length}" ]; then
        ip -6 addr del "${ipv6_prefix}1/${ipv6_prefix_length}" dev "${tap}" 2>/dev/null || true
    fi

    destroy_tap "${tap}"
}

#
# Function: create_bridged_interfaces
# Create multiple tap devices on a single bridge (Task 3.2.1, 3.2.2)
#
create_bridged_interfaces() {
    local ip_base="$1"
    local bridge="$2"
    local tap_prefix="$3"
    local ipv6_prefix="$4"
    local ipv6_prefix_length="$5"

    if [ "${create_bridges}" = "1" ]; then
        # Create bridge
        ip link add name "${bridge}" type bridge forward_delay 0 stp_state 0
        ip link set dev "${bridge}" up

        # Configure IPv6 on bridge
        echo 0 > /proc/sys/net/ipv6/conf/${bridge}/disable_ipv6
        echo 0 > /proc/sys/net/ipv6/conf/${bridge}/addr_gen_mode
        echo 1 > /proc/sys/net/ipv6/conf/${bridge}/autoconf
    fi

    # Create tap interfaces
    for i in $(seq ${num_cvd_accounts}); do
        tap="$(printf ${tap_prefix}-%02d $i)"
        create_tap "${tap}"
        ip link set dev "${tap}" master "${bridge}"

        # ebtables configuration for non-bridged mode (Task 3.2.8)
        if [ "${create_bridges}" != "1" ]; then
            if [ "$ipv4_bridge" != "1" ]; then
                $ebtables -t broute -A BROUTING -p ipv4 --in-if  "${tap}" -j DROP 2>/dev/null || true
                $ebtables -t filter -A FORWARD  -p ipv4 --out-if "${tap}" -j DROP 2>/dev/null || true
            fi
            if [ "$ipv6_bridge" != "1" ]; then
                $ebtables -t broute -A BROUTING -p ipv6 --in-if  "${tap}" -j DROP 2>/dev/null || true
                $ebtables -t filter -A FORWARD  -p ipv6 --out-if "${tap}" -j DROP 2>/dev/null || true
            fi
        fi
    done

    if [ "${create_bridges}" = "1" ]; then
        # Configure bridge IP
        local gateway="${ip_base}.1"
        local netmask="/24"
        local network="${ip_base}.0${netmask}"
        local dhcp_range="${ip_base}.2,${ip_base}.255"

        ip addr add "${gateway}${netmask}" broadcast + dev "${bridge}"

        if [ -n "${ipv6_prefix}" ] && [ -n "${ipv6_prefix_length}" ]; then
            ip -6 addr add "${ipv6_prefix}1/${ipv6_prefix_length}" dev "${bridge}"
        fi

        # Start dnsmasq
        start_dnsmasq "${bridge}" "${gateway}" "${dhcp_range}" "${ipv6_prefix}" "${ipv6_prefix_length}"

        # Configure NAT (Task 3.2.4)
        if [ $use_firewalld -eq 1 ]; then
            # Use firewalld for NAT
            firewall-cmd --zone="${default_zone}" --add-masquerade --permanent
            firewall-cmd --zone="${default_zone}" --add-rich-rule="rule family=ipv4 source address=${network} masquerade" --permanent
            # Open ports for operator and orchestrator
            firewall-cmd --zone="${default_zone}" --add-port=1080/tcp --permanent  # Operator HTTP
            firewall-cmd --zone="${default_zone}" --add-port=1443/tcp --permanent  # Operator HTTPS
            firewall-cmd --zone="${default_zone}" --add-port=2080/tcp --permanent  # Orchestrator
        else
            # Use iptables for NAT
            "${iptables}" -t nat -A POSTROUTING -s "${network}" -j MASQUERADE
        fi
    fi
}

#
# Function: destroy_bridged_interfaces
# Destroy multiple tap devices and a bridge
#
destroy_bridged_interfaces() {
    local ip_base="$1"
    local bridge="$2"
    local tap_prefix="$3"
    local ipv6_prefix="$4"
    local ipv6_prefix_length="$5"

    if [ "${create_bridges}" = "1" ]; then
        local gateway="${ip_base}.1"
        local netmask="/24"
        local network="${ip_base}.0${netmask}"

        # Remove NAT rules
        if [ $use_firewalld -eq 1 ]; then
            firewall-cmd --zone="${default_zone}" --remove-masquerade --permanent 2>/dev/null || true
            firewall-cmd --zone="${default_zone}" --remove-rich-rule="rule family=ipv4 source address=${network} masquerade" --permanent 2>/dev/null || true
            firewall-cmd --zone="${default_zone}" --remove-port=1080/tcp --permanent 2>/dev/null || true
            firewall-cmd --zone="${default_zone}" --remove-port=1443/tcp --permanent 2>/dev/null || true
            firewall-cmd --zone="${default_zone}" --remove-port=2080/tcp --permanent 2>/dev/null || true
        else
            "${iptables}" -t nat -D POSTROUTING -s "${network}" -j MASQUERADE 2>/dev/null || true
        fi

        stop_dnsmasq "${bridge}"

        ip addr del "${gateway}${netmask}" dev "${bridge}" 2>/dev/null || true

        if [ -n "${ipv6_prefix}" ] && [ -n "${ipv6_prefix_length}" ]; then
            ip -6 addr del "${ipv6_prefix}1/${ipv6_prefix_length}" dev "${bridge}" 2>/dev/null || true
        fi
    fi

    # Destroy tap interfaces
    for i in $(seq ${num_cvd_accounts}); do
        tap="$(printf ${tap_prefix}-%02d $i)"

        # Remove ebtables rules
        if [ "${create_bridges}" != "1" ]; then
            if [ "$ipv4_bridge" != "1" ]; then
                $ebtables -t filter -D FORWARD  -p ipv4 --out-if "${tap}" -j DROP 2>/dev/null || true
                $ebtables -t broute -D BROUTING -p ipv4 --in-if  "${tap}" -j DROP 2>/dev/null || true
            fi
            if [ "$ipv6_bridge" != "1" ]; then
                $ebtables -t filter -D FORWARD  -p ipv6 --out-if "${tap}" -j DROP 2>/dev/null || true
                $ebtables -t broute -D BROUTING -p ipv6 --in-if  "${tap}" -j DROP 2>/dev/null || true
            fi
        fi

        destroy_tap "${tap}"
    done

    if [ "${create_bridges}" = "1" ]; then
        ip link set dev "${bridge}" down 2>/dev/null || true
        ip link delete "${bridge}" 2>/dev/null || true
    fi
}

#
# Function: start
# Start all Cuttlefish network infrastructure
#
start() {
    echo "Starting Cuttlefish host resources..."

    # Load kernel modules (Task 3.2.6)
    modprobe bridge || echo "Warning: bridge module not loaded"
    modprobe vhost-net || echo "Warning: vhost-net module not loaded"
    modprobe vhost-vsock || echo "Warning: vhost-vsock module not loaded"

    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo 1 > /proc/sys/net/ipv6/conf/all/forwarding

    # Ethernet bridge and tap interfaces
    # 192.168.98.X for cvd-ebr and cvd-etap-XX
    create_bridged_interfaces \
      192.168.98 "${ethernet_bridge_interface}" cvd-etap \
      "${ethernet_ipv6_prefix}" "${ethernet_ipv6_prefix_length}"

    # Mobile Network tap interfaces (standalone, not bridged)
    # 192.168.97.X from cvd-mtap-01 to cvd-mtap-64
    # 192.168.93.X from cvd-mtap-65 to cvd-mtap-128
    for i in $(seq ${num_cvd_accounts}); do
        tap="$(printf cvd-mtap-%02d $i)"
        if [ $i -lt 65 ]; then
            create_interface $tap 192.168.97 $i
        elif [ $i -lt 129 ]; then
            create_interface $tap 192.168.93 $(($i - 64))
        fi
    done

    # WiFi bridge and tap interfaces
    # 192.168.96.X for cvd-wbr and cvd-wtap-XX
    create_bridged_interfaces \
      192.168.96 "${wifi_bridge_interface}" cvd-wtap \
      "${wifi_ipv6_prefix}" "${wifi_ipv6_prefix_length}"

    # WiFi AP tap interfaces (standalone, not bridged)
    # 192.168.94.X from cvd-wifiap-01 to cvd-wifiap-64
    # 192.168.95.X from cvd-wifiap-65 to cvd-wifiap-128
    for i in $(seq ${num_cvd_accounts}); do
        tap="$(printf cvd-wifiap-%02d $i)"
        if [ $i -lt 65 ]; then
            create_interface $tap 192.168.94 $i
        elif [ $i -lt 129 ]; then
            create_interface $tap 192.168.95 $(($i - 64))
        fi
    done

    # Docker environment handling (Task 3.2.7)
    if test -f /.dockerenv; then
        echo "Detected Docker environment, setting device permissions..."
        if [ -e /dev/kvm ]; then
            chown root:cvdnetwork /dev/kvm
            chmod ug+rw /dev/kvm
        fi
        if [ -e /dev/vhost-net ]; then
            chown root:cvdnetwork /dev/vhost-net
            chmod ug+rw /dev/vhost-net
        fi
        if [ -e /dev/vhost-vsock ]; then
            chown root:cvdnetwork /dev/vhost-vsock
            chmod ug+rw /dev/vhost-vsock
        fi
    fi

    # Try to preload Nvidia module if present
    /usr/bin/nvidia-modprobe --modeset 2>/dev/null || true

    # Reload firewalld if using it
    if [ $use_firewalld -eq 1 ]; then
        firewall-cmd --reload
        echo "Firewalld configuration reloaded"
    fi

    echo "Cuttlefish host resources started successfully"
}

#
# Function: stop
# Stop all Cuttlefish network infrastructure
#
stop() {
    echo "Stopping Cuttlefish host resources..."

    # Ethernet
    destroy_bridged_interfaces \
      192.168.98 "${ethernet_bridge_interface}" cvd-etap \
      "${ethernet_ipv6_prefix}" "${ethernet_ipv6_prefix_length}"

    # Mobile Network
    for i in $(seq ${num_cvd_accounts}); do
        tap="$(printf cvd-mtap-%02d $i)"
        if [ $i -lt 65 ]; then
            destroy_interface $tap 192.168.97 $i
        elif [ $i -lt 129 ]; then
            destroy_interface $tap 192.168.93 $(($i - 64))
        fi
    done

    # WiFi
    destroy_bridged_interfaces \
      192.168.96 "${wifi_bridge_interface}" cvd-wtap \
      "${wifi_ipv6_prefix}" "${wifi_ipv6_prefix_length}"

    # WiFi AP
    for i in $(seq ${num_cvd_accounts}); do
        tap="$(printf cvd-wifiap-%02d $i)"
        if [ $i -lt 65 ]; then
            destroy_interface $tap 192.168.94 $i
        elif [ $i -lt 129 ]; then
            destroy_interface $tap 192.168.95 $(($i - 64))
        fi
    done

    # Reload firewalld if using it
    if [ $use_firewalld -eq 1 ]; then
        firewall-cmd --reload 2>/dev/null || true
        echo "Firewalld configuration reloaded"
    fi

    echo "Cuttlefish host resources stopped successfully"
}

# Main script logic
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac

exit 0
