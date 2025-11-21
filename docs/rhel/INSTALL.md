# Cuttlefish Installation Guide for RHEL 10, CentOS Stream 10, and Fedora 43

This guide provides detailed instructions for installing Cuttlefish on Red Hat-based systems.

## Table of Contents

- [System Requirements](#system-requirements)
- [Repository Setup](#repository-setup)
- [Package Installation](#package-installation)
- [Post-Installation Configuration](#post-installation-configuration)
- [Service Management](#service-management)
- [Multi-Device Configuration](#multi-device-configuration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

## System Requirements

### Minimum Requirements

- **Operating System**: One of the following:
  - RHEL 10 (fully supported)
  - CentOS Stream 10 (fully supported)
  - Fedora 43 (fully supported)
  - RHEL 9 (deprecated, upgrade recommended)

- **Hardware**:
  - CPU: x86_64 or aarch64 with virtualization support (Intel VT-x or AMD-V)
  - RAM: Minimum 8GB (16GB recommended for multiple devices)
  - Disk: Minimum 20GB free space (50GB+ recommended)
  - Network: Internet connection for repository access

- **Privileges**: Root or sudo access required

### Check Virtualization Support

```bash
# Check for virtualization support
lscpu | grep Virtualization

# Expected output (Intel):
# Virtualization:      VT-x

# Expected output (AMD):
# Virtualization:      AMD-V

# Verify KVM module is available
lsmod | grep kvm
```

If KVM is not loaded:
```bash
# For Intel CPUs
sudo modprobe kvm_intel

# For AMD CPUs
sudo modprobe kvm_amd
```

## Repository Setup

### For RHEL 10

```bash
# 1. Enable required repositories
sudo subscription-manager repos --enable codeready-builder-for-rhel-10-$(arch)-rpms

# 2. Install EPEL repository
sudo dnf install -y epel-release

# 3. Update repository metadata
sudo dnf makecache
```

### For CentOS Stream 10

```bash
# 1. Enable CRB repository
sudo dnf config-manager --set-enabled crb

# 2. Install EPEL repository
sudo dnf install -y epel-release

# 3. Update repository metadata
sudo dnf makecache
```

### For Fedora 43

```bash
# Fedora 43 has all required packages in default repositories
# No additional repository setup needed

# Update system
sudo dnf update -y
```

## Package Installation

### Install Cuttlefish Meta-Package

The easiest way to install Cuttlefish is using the meta-package, which installs all required components:

```bash
sudo dnf install -y cuttlefish-common
```

This will install:
- `cuttlefish-base` - Core Cuttlefish binaries and services
- `cuttlefish-user` - WebRTC operator service
- `cuttlefish-integration` - System integration utilities
- `cuttlefish-defaults` - Default configuration files

### Individual Package Installation

If you need specific components only:

```bash
# Core package (required)
sudo dnf install -y cuttlefish-base

# Operator service (for WebRTC support)
sudo dnf install -y cuttlefish-user

# Orchestration service (for multi-device management)
sudo dnf install -y cuttlefish-orchestration

# Integration utilities
sudo dnf install -y cuttlefish-integration

# Default configurations
sudo dnf install -y cuttlefish-defaults
```

### Installation Progress

During installation, the following will occur:
1. System users and groups creation (`cvdnetwork`, `_cutf-operator`, `httpcvd`)
2. SELinux policy modules installation
3. Systemd service registration
4. Udev rules installation
5. Network configuration preparation

## Post-Installation Configuration

### Add User to cvdnetwork Group

To run Cuttlefish as a non-root user:

```bash
# Add your user to the cvdnetwork group
sudo usermod -aG cvdnetwork $USER

# Add your user to the kvm group
sudo usermod -aG kvm $USER

# Log out and log back in for group changes to take effect
# Or run: newgrp cvdnetwork
```

### Configure Firewall

#### For firewalld (default on RHEL/CentOS Stream)

```bash
# Check if firewalld is active
sudo systemctl is-active firewalld

# If active, open required ports
sudo firewall-cmd --permanent --add-port=1080/tcp  # Operator HTTP
sudo firewall-cmd --permanent --add-port=1443/tcp  # Operator HTTPS
sudo firewall-cmd --permanent --add-port=2080/tcp  # Orchestrator HTTP
sudo firewall-cmd --permanent --add-port=2081/tcp  # Orchestrator HTTPS

# Enable masquerading for VM network
sudo firewall-cmd --permanent --add-masquerade

# Reload firewall
sudo firewall-cmd --reload

# Verify configuration
sudo firewall-cmd --list-all
```

#### For iptables

```bash
# If using iptables instead of firewalld
sudo iptables -I INPUT -p tcp --dport 1080 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 1443 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 2080 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 2081 -j ACCEPT

# Enable masquerading
sudo iptables -t nat -A POSTROUTING -s 192.168.96.0/24 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -s 192.168.98.0/24 -j MASQUERADE

# Save rules
sudo service iptables save
```

### Verify SELinux Policy Installation

```bash
# Check SELinux mode
getenforce
# Expected: Enforcing

# Verify Cuttlefish SELinux modules are installed
sudo semodule -l | grep cuttlefish

# Expected output:
# cuttlefish_host_resources
# cuttlefish_operator
# cuttlefish_orchestration

# Verify SELinux booleans
sudo getsebool -a | grep cuttlefish

# Expected output (all should be 'on'):
# cuttlefish_kvm --> on
# cuttlefish_networking --> on
# cuttlefish_tls --> on
```

## Service Management

### Start Core Services

```bash
# Start host resources service (creates network bridges and tap interfaces)
sudo systemctl start cuttlefish-host-resources.service

# Enable to start on boot
sudo systemctl enable cuttlefish-host-resources.service

# Check status
sudo systemctl status cuttlefish-host-resources.service
```

### Start Optional Services

```bash
# Start WebRTC operator service (for remote access)
sudo systemctl start cuttlefish-operator.service
sudo systemctl enable cuttlefish-operator.service

# Start orchestration service (for multi-device management)
sudo systemctl start cuttlefish-host_orchestrator.service
sudo systemctl enable cuttlefish-host_orchestrator.service
```

### View Service Logs

```bash
# View host resources logs
sudo journalctl -u cuttlefish-host-resources.service -f

# View operator logs
sudo journalctl -u cuttlefish-operator.service -f

# View orchestrator logs
sudo journalctl -u cuttlefish-host_orchestrator.service -f

# View all Cuttlefish logs
sudo journalctl -u 'cuttlefish-*' -f
```

## Multi-Device Configuration

Cuttlefish supports running multiple Android Virtual Devices simultaneously.

### Configure Number of CVD Accounts

Edit the configuration file:

```bash
sudo vi /etc/sysconfig/cuttlefish-host-resources
```

Set the number of CVD accounts (default is 10):

```bash
# Number of CVD accounts to configure
# Each account gets 4 tap interfaces:
# - cvd-etap-XX (ethernet, bridged)
# - cvd-mtap-XX (mobile data, NAT)
# - cvd-wtap-XX (wifi, bridged)
# - cvd-wifiap-XX (wifi AP, NAT)
num_cvd_accounts=10

# Optionally configure bridge interface
# Leave empty to use default bridges (cvd-ebr, cvd-wbr)
bridge_interface=

# IPv6 support (optional)
ipv6=0
```

### Restart Service to Apply Changes

```bash
sudo systemctl restart cuttlefish-host-resources.service
```

### Verify Network Configuration

```bash
# Check network bridges
ip link show | grep cvd

# Expected output includes:
# cvd-ebr (192.168.96.1/24)
# cvd-wbr (192.168.98.1/24)

# Check tap interfaces (for 10 accounts = 40 tap interfaces)
ip link show | grep cvd-.*tap | wc -l

# Expected output: 40
```

### Running Multiple Devices

```bash
# Each user in the cvdnetwork group can run devices
# User vsoc-01 can run devices on account 01
# User vsoc-02 can run devices on account 02
# etc.

# Create CVD users (optional, for multi-user setup)
for i in $(seq -f "%02g" 1 10); do
    sudo useradd -G cvdnetwork vsoc-$i
done
```

## Verification

### Verify Installation

```bash
# Check cvd binary is accessible
which cvd
# Expected: /usr/bin/cvd

# Check cvd version
cvd version

# Verify all required binaries are present
ls -la /usr/lib/cuttlefish-common/bin/

# Expected files include:
# - cvd
# - assemble_cvd
# - run_cvd
# - stop_cvd
# - operator
# - host_orchestrator
```

### Verify Network Setup

```bash
# Check bridges exist
ip addr show cvd-ebr
ip addr show cvd-wbr

# Check dnsmasq processes for bridges
ps aux | grep dnsmasq | grep cuttlefish

# Check NAT rules
if systemctl is-active --quiet firewalld; then
    sudo firewall-cmd --query-masquerade
else
    sudo iptables -t nat -L POSTROUTING | grep MASQUERADE
fi
```

### Verify Device Permissions

```bash
# Check KVM device permissions
ls -l /dev/kvm

# Expected: should be accessible by kvm group
# crw-rw----. 1 root kvm ... /dev/kvm

# Check vhost devices
ls -l /dev/vhost-*

# Verify user group membership
groups $USER | grep -E "(cvdnetwork|kvm)"
```

### Verify SELinux Context

```bash
# Check file contexts
ls -lZ /usr/lib/cuttlefish-common/bin/setup-host-resources.sh
ls -lZ /usr/lib/cuttlefish-common/bin/operator
ls -lZ /usr/lib/cuttlefish-common/bin/host_orchestrator

# Check for recent SELinux denials
sudo ausearch -m avc -ts recent | grep cuttlefish

# If no output, SELinux is working correctly
```

## Running Your First Virtual Device

### Prerequisites

You'll need Android device images. Download from:
- Android CI: https://ci.android.com/
- Or build from AOSP source

### Launch Device

```bash
# Download and extract Android images (example)
# wget https://ci.android.com/builds/.../aosp_cf_x86_64_phone-img-*.zip
# unzip aosp_cf_x86_64_phone-img-*.zip -d ~/android-images

# Launch device
cvd start \
    --system_image_dir ~/android-images \
    --daemon

# Check device status
cvd status

# Connect via ADB
adb connect 127.0.0.1:6520

# View device screen (requires VNC client)
# Connect to localhost:6444
```

### Access WebRTC Interface

If the operator service is running:

```bash
# Access via web browser
# HTTPS: https://localhost:1443
# HTTP: http://localhost:1080

# Default port: 1443 (HTTPS) or 1080 (HTTP)
```

## Troubleshooting

For detailed troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

### Common Issues

**Issue**: Services fail to start

```bash
# Check journal logs
sudo journalctl -xe

# Check SELinux denials
sudo ausearch -m avc -ts recent
```

**Issue**: Network bridges not created

```bash
# Restart host resources service
sudo systemctl restart cuttlefish-host-resources.service

# Check for errors
sudo journalctl -u cuttlefish-host-resources.service -n 50
```

**Issue**: Permission denied accessing /dev/kvm

```bash
# Add user to kvm group
sudo usermod -aG kvm $USER

# Log out and log back in

# Verify
groups | grep kvm
```

**Issue**: Firewall blocking connections

```bash
# For firewalld
sudo firewall-cmd --list-all

# Add required ports (see Post-Installation Configuration)
```

## Next Steps

- Read [DEVELOPMENT.md](DEVELOPMENT.md) for building from source
- Read [REPOSITORIES.md](REPOSITORIES.md) for repository details
- Check [SELinux Integration Guide](SELINUX_INTEGRATION.md) for SELinux details
- Review [Dependency Mapping](DEPENDENCIES.md) for package dependencies

## Getting Help

- GitHub Issues: https://github.com/google/android-cuttlefish/issues
- Documentation: https://source.android.com/docs/setup/create/cuttlefish

## License

Cuttlefish is licensed under the Apache License 2.0.
See the repository LICENSE file for details.
