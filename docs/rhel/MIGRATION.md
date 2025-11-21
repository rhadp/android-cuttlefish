# Migrating from Debian to RHEL-based Systems

This guide helps users migrate Cuttlefish deployments from Debian/Ubuntu systems to RHEL-based systems (RHEL 10, CentOS Stream 10, or Fedora 43).

## Table of Contents

- [Overview](#overview)
- [Key Differences](#key-differences)
- [Pre-Migration Checklist](#pre-migration-checklist)
- [Migration Strategies](#migration-strategies)
- [Step-by-Step Migration](#step-by-step-migration)
- [Post-Migration Verification](#post-migration-verification)
- [Troubleshooting](#troubleshooting)

## Overview

Cuttlefish is available for both Debian/Ubuntu (.deb packages) and RHEL-based systems (.rpm packages). While the core functionality is identical, there are differences in:
- Package management (apt vs dnf)
- Configuration file locations
- Service management conventions
- Repository setup

This guide covers migrating existing Cuttlefish deployments from Debian/Ubuntu to RHEL-based systems.

## Key Differences

### Package Management

| Aspect | Debian/Ubuntu | RHEL-based |
|--------|---------------|------------|
| **Package Manager** | apt, dpkg | dnf, rpm |
| **Package Format** | .deb | .rpm |
| **Install Command** | `apt install cuttlefish-common` | `dnf install cuttlefish-common` |
| **Remove Command** | `apt remove cuttlefish-common` | `dnf remove cuttlefish-common` |
| **Package Query** | `dpkg -l \| grep cuttlefish` | `rpm -qa \| grep cuttlefish` |
| **Package Info** | `dpkg -s cuttlefish-base` | `rpm -qi cuttlefish-base` |
| **List Files** | `dpkg -L cuttlefish-base` | `rpm -ql cuttlefish-base` |

### Configuration Files

| File Purpose | Debian/Ubuntu | RHEL-based |
|--------------|---------------|------------|
| **Host Resources Config** | /etc/default/cuttlefish-host-resources | /etc/sysconfig/cuttlefish-host-resources |
| **Operator Config** | /etc/default/cuttlefish-operator | /etc/sysconfig/cuttlefish-operator |
| **Orchestrator Config** | /etc/default/cuttlefish-host_orchestrator | /etc/sysconfig/cuttlefish-host_orchestrator |
| **Systemd Units** | /lib/systemd/system/ | /usr/lib/systemd/system/ |
| **Udev Rules** | /lib/udev/rules.d/ | /usr/lib/udev/rules.d/ |
| **Nginx Config (Debian)** | /etc/nginx/sites-available/ | N/A (not used) |
| **Nginx Config (RHEL)** | N/A | /etc/nginx/conf.d/ |

### Service Management

| Operation | Debian/Ubuntu | RHEL-based |
|-----------|---------------|------------|
| **Start Service** | `systemctl start cuttlefish-host-resources` | `systemctl start cuttlefish-host-resources` |
| **Enable Service** | `systemctl enable cuttlefish-host-resources` | `systemctl enable cuttlefish-host-resources` |
| **Service Logs** | `journalctl -u cuttlefish-host-resources` | `journalctl -u cuttlefish-host-resources` |

*Note: systemd commands are identical*

### Repository Setup

| Aspect | Debian/Ubuntu | RHEL-based |
|--------|---------------|------------|
| **Additional Repos** | Universe (usually enabled) | EPEL + CRB (RHEL/CentOS Stream)<br>None for Fedora |
| **Repository File** | /etc/apt/sources.list.d/ | /etc/yum.repos.d/ |
| **Update Metadata** | `apt update` | `dnf makecache` |

### Security

| Feature | Debian/Ubuntu | RHEL-based |
|---------|---------------|------------|
| **SELinux** | Not typically enforced | Enforcing mode by default |
| **AppArmor** | May be active | Not typically used |
| **Firewall** | ufw or iptables | firewalld (preferred) or iptables |

## Pre-Migration Checklist

Before migrating, gather information from your Debian/Ubuntu system:

### 1. Document Current Configuration

```bash
# On Debian/Ubuntu system:

# Save config files
sudo cp /etc/default/cuttlefish-host-resources ~/migration/
sudo cp /etc/default/cuttlefish-operator ~/migration/
sudo cp /etc/default/cuttlefish-host_orchestrator ~/migration/

# Record current settings
cat /etc/default/cuttlefish-host-resources | grep -v "^#" | grep -v "^$" > ~/migration/settings.txt

# List installed packages
dpkg -l | grep cuttlefish > ~/migration/installed-packages.txt

# Check service status
systemctl status cuttlefish-* > ~/migration/service-status.txt

# Export network configuration
ip link show | grep cvd > ~/migration/network-config.txt
```

### 2. Backup Important Data

```bash
# Backup any custom modifications
sudo tar czf ~/migration/cuttlefish-backup.tar.gz \
    /etc/default/cuttlefish-* \
    /etc/cuttlefish-common/ \
    /var/lib/cuttlefish-common/ \
    2>/dev/null || true
```

### 3. Record Custom Values

Document any custom configuration values:
- `num_cvd_accounts` setting
- Custom network bridges
- Custom firewall rules
- TLS certificates (if custom)
- Any other modified settings

## Migration Strategies

### Strategy 1: Fresh Installation (Recommended)

**Best for:** New deployments, test environments, clean slate scenarios

**Pros:**
- Clean, predictable state
- No compatibility issues
- Easier troubleshooting

**Cons:**
- Requires system rebuild or new hardware
- All configuration must be re-applied

**Steps:**
1. Install RHEL-based OS (RHEL 10, CentOS Stream 10, or Fedora 43)
2. Install Cuttlefish RPM packages
3. Apply saved configuration from Debian system
4. Test and verify

### Strategy 2: Side-by-Side Migration

**Best for:** Production environments, critical services, testing before switching

**Pros:**
- Zero downtime
- Test RHEL environment before switching
- Easy rollback

**Cons:**
- Requires additional hardware
- More complex setup
- Higher cost

**Steps:**
1. Set up new RHEL-based system alongside existing Debian system
2. Install Cuttlefish on RHEL system
3. Replicate configuration from Debian system
4. Test thoroughly on RHEL system
5. Switch traffic/users to RHEL system
6. Decommission Debian system after verification

### Strategy 3: In-Place Upgrade (Not Recommended)

**Warning:** In-place OS upgrades from Debian to RHEL are **not supported** and will likely fail. Do not attempt to upgrade the operating system in-place.

**Alternative:** Use Strategy 1 or 2 instead.

## Step-by-Step Migration

This guide follows **Strategy 1: Fresh Installation**.

### Step 1: Prepare RHEL System

Install a supported RHEL-based distribution:

**For RHEL 10:**
```bash
# Register with subscription manager
sudo subscription-manager register
sudo subscription-manager attach --auto

# Enable required repositories
sudo subscription-manager repos --enable codeready-builder-for-rhel-10-$(arch)-rpms
sudo dnf install -y epel-release

# Update system
sudo dnf update -y
```

**For CentOS Stream 10:**
```bash
# Enable CRB repository
sudo dnf config-manager --set-enabled crb

# Install EPEL
sudo dnf install -y epel-release

# Update system
sudo dnf update -y
```

**For Fedora 43:**
```bash
# Update system (no additional repos needed)
sudo dnf update -y
```

### Step 2: Install Cuttlefish Packages

```bash
# Install meta-package (installs all components)
sudo dnf install -y cuttlefish-common

# Or install individual packages
sudo dnf install -y \
    cuttlefish-base \
    cuttlefish-user \
    cuttlefish-integration \
    cuttlefish-defaults
```

See [INSTALL.md](INSTALL.md) for detailed installation instructions.

### Step 3: Migrate Configuration

Convert configuration from Debian format to RHEL format:

**Debian config:** `/etc/default/cuttlefish-host-resources`
**RHEL config:** `/etc/sysconfig/cuttlefish-host-resources`

```bash
# Example migration of settings

# On Debian system, you had:
# num_cvd_accounts=10
# bridge_interface=
# ipv6=0

# On RHEL system, edit /etc/sysconfig/cuttlefish-host-resources:
sudo vi /etc/sysconfig/cuttlefish-host-resources
```

Add the same values:
```bash
num_cvd_accounts=10
bridge_interface=
ipv6=0
```

**Configuration mapping:**

All configuration options have the same names on both systems. Simply copy the values from `/etc/default/` files on Debian to `/etc/sysconfig/` files on RHEL.

| Debian Location | RHEL Location |
|----------------|---------------|
| /etc/default/cuttlefish-host-resources | /etc/sysconfig/cuttlefish-host-resources |
| /etc/default/cuttlefish-operator | /etc/sysconfig/cuttlefish-operator |
| /etc/default/cuttlefish-host_orchestrator | /etc/sysconfig/cuttlefish-host_orchestrator |

### Step 4: Configure Users and Groups

```bash
# Add your user to required groups
sudo usermod -aG cvdnetwork,kvm $USER

# Log out and log back in for group changes to take effect
# Or run: newgrp cvdnetwork
```

### Step 5: Configure Firewall

**If using firewalld (RHEL/CentOS Stream default):**

```bash
# Check if firewalld is active
sudo systemctl is-active firewalld

# If active, open required ports
sudo firewall-cmd --permanent --add-port=1080/tcp  # Operator HTTP
sudo firewall-cmd --permanent --add-port=1443/tcp  # Operator HTTPS
sudo firewall-cmd --permanent --add-masquerade
sudo firewall-cmd --reload
```

**If using iptables:**

```bash
# Open ports
sudo iptables -I INPUT -p tcp --dport 1080 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 1443 -j ACCEPT

# Enable masquerading
sudo iptables -t nat -A POSTROUTING -s 192.168.96.0/24 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -s 192.168.98.0/24 -j MASQUERADE

# Save rules (RHEL/CentOS)
sudo service iptables save
```

See [INSTALL.md](INSTALL.md#configure-firewall) for detailed firewall configuration.

### Step 6: Configure SELinux

RHEL systems run SELinux in enforcing mode by default. Cuttlefish includes SELinux policies, but you may need to configure booleans:

```bash
# Check SELinux mode
getenforce
# Should show: Enforcing

# Enable required SELinux booleans
sudo setsebool -P cuttlefish_networking on
sudo setsebool -P cuttlefish_tls on
sudo setsebool -P cuttlefish_kvm on

# Verify Cuttlefish SELinux modules installed
sudo semodule -l | grep cuttlefish
```

See [SELINUX_INTEGRATION.md](SELINUX_INTEGRATION.md) for detailed SELinux configuration.

### Step 7: Start Services

```bash
# Start and enable host resources
sudo systemctl start cuttlefish-host-resources
sudo systemctl enable cuttlefish-host-resources

# Start and enable operator (optional)
sudo systemctl start cuttlefish-operator
sudo systemctl enable cuttlefish-operator

# Check status
sudo systemctl status cuttlefish-*
```

### Step 8: Verify Installation

```bash
# Check binaries
which cvd
cvd version

# Check network bridges
ip addr show cvd-ebr
ip addr show cvd-wbr

# Check tap interfaces
ip link show | grep cvd-.*tap

# Verify expected count
# For num_cvd_accounts=10, expect 40 tap interfaces (4 per account)
ip link show | grep cvd-.*tap | wc -l
```

### Step 9: Test Device Boot

```bash
# Download Android images (if not already available)
# wget https://ci.android.com/builds/.../aosp_cf_x86_64_phone-img-*.zip
# unzip aosp_cf_x86_64_phone-img-*.zip -d ~/android-images

# Launch device
cvd start --system_image_dir ~/android-images --daemon

# Check device status
cvd status

# Connect via ADB
adb connect 127.0.0.1:6520

# Access WebRTC interface (if operator running)
# Open browser to https://localhost:1443
```

## Post-Migration Verification

### Checklist

- [ ] All Cuttlefish packages installed (`rpm -qa | grep cuttlefish`)
- [ ] Configuration files migrated to /etc/sysconfig/
- [ ] User in cvdnetwork and kvm groups (`groups $USER`)
- [ ] Network bridges created (cvd-ebr, cvd-wbr)
- [ ] Tap interfaces created (4 per num_cvd_accounts)
- [ ] Firewall configured (ports open, masquerading enabled)
- [ ] SELinux in enforcing mode with Cuttlefish policies loaded
- [ ] Services running (`systemctl status cuttlefish-*`)
- [ ] cvd binary accessible (`which cvd`)
- [ ] Device boots successfully (`cvd start`)
- [ ] ADB connection works (`adb connect`)
- [ ] WebRTC interface accessible (if using operator)

### Comparison Test

Test the same workload on both systems to verify equivalent functionality:

```bash
# On both Debian and RHEL systems:

# 1. Launch device
cvd start --system_image_dir ~/android-images --daemon

# 2. Check boot time
journalctl -u cuttlefish-host-resources | grep "Started"

# 3. Test ADB connectivity
adb connect 127.0.0.1:6520
adb shell getprop ro.product.model

# 4. Check resource usage
free -h
df -h
```

## Troubleshooting

### Common Migration Issues

#### Issue 1: Config File Not Found

**Symptom:**
```
systemd[1]: cuttlefish-host-resources.service: Failed to load environment files: No such file or directory
```

**Cause:** Configuration file not created at /etc/sysconfig/cuttlefish-host-resources

**Solution:**
```bash
# Verify config file exists
ls -la /etc/sysconfig/cuttlefish-host-resources

# If missing, it should have been created by package install
# Reinstall package
sudo dnf reinstall cuttlefish-base
```

#### Issue 2: SELinux Denials

**Symptom:**
```
systemd[1]: cuttlefish-host-resources.service: Failed with result 'timeout'.
```

**Cause:** SELinux blocking service operations

**Solution:**
```bash
# Check for AVC denials
sudo ausearch -m avc -ts recent | grep cuttlefish

# Temporarily set permissive for testing
sudo semanage permissive -a cuttlefish_host_resources_t

# Or set entire system to permissive (testing only)
sudo setenforce 0

# After identifying issues, generate policy
sudo ausearch -m avc -ts recent | audit2allow -M mycuttlefish
sudo semodule -i mycuttlefish.pp

# Re-enable enforcing
sudo setenforce 1
```

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#selinux-issues) for detailed SELinux troubleshooting.

#### Issue 3: Network Bridges Not Created

**Symptom:**
```bash
ip addr show cvd-ebr
# Device "cvd-ebr" does not exist
```

**Cause:** Host resources service failed or not started

**Solution:**
```bash
# Check service status
sudo systemctl status cuttlefish-host-resources

# View logs
sudo journalctl -u cuttlefish-host-resources -n 50

# Restart service
sudo systemctl restart cuttlefish-host-resources

# Check for firewall issues
sudo systemctl is-active firewalld
```

#### Issue 4: Firewall Blocking Connections

**Symptom:** Cannot access WebRTC interface at https://localhost:1443

**Cause:** Firewall not configured or blocking ports

**Solution:**
```bash
# For firewalld
sudo firewall-cmd --list-all
sudo firewall-cmd --add-port=1443/tcp --permanent
sudo firewall-cmd --reload

# For iptables
sudo iptables -L INPUT -n | grep 1443
sudo iptables -I INPUT -p tcp --dport 1443 -j ACCEPT
```

#### Issue 5: Different Package Versions

**Symptom:** Feature present on Debian system but not working on RHEL system

**Cause:** Different package versions between Debian and RHEL

**Solution:**
```bash
# Check versions
# Debian:
dpkg -s cuttlefish-base | grep Version

# RHEL:
rpm -q --queryformat '%{VERSION}-%{RELEASE}\n' cuttlefish-base

# If versions differ, ensure you're using the same release
# Check debian/changelog for version used on Debian
# Compare with RHEL spec file version
```

## Differences Summary

### What Stays the Same

- **Binaries**: Identical binaries built from same source
- **Features**: All Cuttlefish features work identically
- **Systemd commands**: Service management commands unchanged
- **Configuration values**: Option names and values same
- **Network layout**: Bridge and tap interface naming identical
- **Device images**: Same Android images work on both systems

### What Changes

- **Package manager**: apt → dnf
- **Config location**: /etc/default/ → /etc/sysconfig/
- **Repository setup**: Add EPEL+CRB (RHEL/CentOS) or none (Fedora)
- **SELinux**: Not enforced → Enforcing by default
- **Firewall**: Often iptables → Usually firewalld
- **Nginx config**: sites-available/ → conf.d/

## See Also

- [INSTALL.md](INSTALL.md) - Complete RHEL installation guide
- [REPOSITORIES.md](REPOSITORIES.md) - Repository setup details
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Troubleshooting guide
- [SELINUX_INTEGRATION.md](SELINUX_INTEGRATION.md) - SELinux configuration
- [DEVELOPMENT.md](DEVELOPMENT.md) - Building from source

## Getting Help

If you encounter issues during migration:

1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Review logs: `sudo journalctl -u cuttlefish-*`
3. Check SELinux: `sudo ausearch -m avc -ts recent | grep cuttlefish`
4. File an issue: https://github.com/google/android-cuttlefish/issues

Include:
- Source system info (Debian/Ubuntu version)
- Target system info (RHEL/CentOS/Fedora version)
- Configuration from both systems
- Service logs and error messages
