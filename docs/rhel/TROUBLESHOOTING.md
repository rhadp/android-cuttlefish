# Cuttlefish RHEL Troubleshooting Guide

This document provides solutions to common problems when running Cuttlefish on RHEL 10 and Fedora (latest).

## Table of Contents

- [SELinux Issues](#selinux-issues)
- [Service Startup Failures](#service-startup-failures)
- [Network Configuration Problems](#network-configuration-problems)
- [Firewall Issues](#firewall-issues)
- [Build Failures](#build-failures)
- [Package Installation Issues](#package-installation-issues)

---

## SELinux Issues

RHEL systems run SELinux in enforcing mode by default. Cuttlefish includes SELinux policies, but you may encounter Access Vector Cache (AVC) denials.

### Check SELinux Mode

```bash
getenforce
```

Expected output: `Enforcing`

### Check for AVC Denials

View recent SELinux denials:

```bash
ausearch -m avc -ts recent
```

View all Cuttlefish-related denials:

```bash
ausearch -m avc -ts recent | grep cuttlefish
```

### Temporary: Set Permissive Mode for Testing

**WARNING**: Only use for troubleshooting. Never use in production.

```bash
# Set entire system to permissive mode
sudo setenforce 0

# Check mode changed
getenforce  # Should show: Permissive
```

To set back to enforcing:

```bash
sudo setenforce 1
```

### Set Specific Domain to Permissive

Instead of disabling SELinux entirely, set only Cuttlefish domains to permissive:

```bash
# Make cuttlefish_host_resources permissive
sudo semanage permissive -a cuttlefish_host_resources_t

# Make cuttlefish_operator permissive
sudo semanage permissive -a cuttlefish_operator_t

# Make cuttlefish_orchestration permissive
sudo semanage permissive -a cuttlefish_orchestration_t
```

List permissive domains:

```bash
sudo semanage permissive -l
```

Remove permissive status:

```bash
sudo semanage permissive -d cuttlefish_host_resources_t
```

### Generate Policy from Denials

If you encounter AVC denials, generate a policy module to allow the operations:

```bash
# Collect denials and generate policy
sudo ausearch -m avc -ts recent | audit2allow -M mycuttlefish

# Review the generated policy
cat mycuttlefish.te

# Install the policy module
sudo semodule -i mycuttlefish.pp
```

### Check Installed SELinux Modules

```bash
# List all Cuttlefish SELinux modules
sudo semodule -l | grep cuttlefish
```

Expected output:
```
cuttlefish_host_resources
cuttlefish_operator
cuttlefish_orchestration
```

### SELinux Boolean Policies

Cuttlefish provides SELinux booleans to control specific behaviors:

```bash
# List all Cuttlefish booleans
sudo getsebool -a | grep cuttlefish

# Enable networking for host resources
sudo setsebool -P cuttlefish_networking on

# Enable TLS for operator
sudo setsebool -P cuttlefish_tls on

# Enable KVM operations
sudo setsebool -P cuttlefish_kvm on

# Allow operator to connect to any port (development only)
sudo setsebool -P cuttlefish_connect_any on

# Allow orchestrator to download artifacts
sudo setsebool -P cuttlefish_download_artifacts on
```

### Port Labeling

If services fail to bind to ports, check port labels:

```bash
# Check current port labels
sudo semanage port -l | grep -E "1080|1443|2080|2081"

# Add port labels if missing
sudo semanage port -a -t http_port_t -p tcp 1080
sudo semanage port -a -t http_port_t -p tcp 1443
sudo semanage port -a -t http_port_t -p tcp 2080
sudo semanage port -a -t http_port_t -p tcp 2081
```

### Restore File Contexts

If file contexts are incorrect:

```bash
# Restore contexts for all Cuttlefish files
sudo restorecon -Rv /usr/lib/cuttlefish-common
sudo restorecon -Rv /etc/cuttlefish-common
sudo restorecon -Rv /var/lib/cuttlefish-common
sudo restorecon -Rv /run/cuttlefish
sudo restorecon -Rv /usr/share/cuttlefish-common
```

### Common AVC Denials

#### Network Bridge Creation Denied

```
type=AVC msg=audit(...): avc: denied { net_admin } for comm="setup-host-resources.sh"
```

**Solution**:
```bash
sudo setsebool -P cuttlefish_networking on
```

#### TLS Certificate Access Denied

```
type=AVC msg=audit(...): avc: denied { read } for comm="operator" path="/etc/cuttlefish-common/operator/cert/cert.pem"
```

**Solution**:
```bash
sudo setsebool -P cuttlefish_tls on
sudo restorecon -Rv /etc/cuttlefish-common/operator/cert
```

---

## Service Startup Failures

### Check Service Status

```bash
# Check all Cuttlefish services
sudo systemctl status cuttlefish-host-resources
sudo systemctl status cuttlefish-operator
sudo systemctl status cuttlefish-host_orchestrator
```

### View Service Logs

```bash
# Follow logs in real-time
sudo journalctl -u cuttlefish-host-resources -f

# View last 100 lines
sudo journalctl -u cuttlefish-operator -n 100

# View logs since last boot
sudo journalctl -u cuttlefish-host_orchestrator -b
```

### Common Service Errors

#### User/Group Not Found

```
Error: user _cutf-operator not found
```

**Solution**: Reinstall package (creates users in %pre scripts):
```bash
sudo dnf reinstall cuttlefish-user
```

#### Permission Denied on /dev/kvm

```
Error: Could not access KVM kernel module: Permission denied
```

**Solution**:
```bash
# Check KVM permissions
ls -l /dev/kvm

# Add user to kvm group
sudo usermod -a -G kvm $USER

# Reboot or reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

---

## Network Configuration Problems

### Bridge Interfaces Not Created

Check if bridges exist:

```bash
ip link show | grep cvd
```

Expected output: `cvd-ebr`, `cvd-wbr`

**Solution**: Restart host-resources service:
```bash
sudo systemctl restart cuttlefish-host-resources
sudo ip link show | grep cvd
```

### Tap Interfaces Missing

For 10 CVD accounts, you should see 40 tap interfaces (4 per account):

```bash
ip link show | grep cvd-.*tap | wc -l
```

Expected output: `40` (for default num_cvd_accounts=10)

**Solution**: Check configuration:
```bash
sudo vi /etc/sysconfig/cuttlefish-host-resources
# Ensure num_cvd_accounts is set correctly
sudo systemctl restart cuttlefish-host-resources
```

### DHCP Not Working

Check dnsmasq processes:

```bash
ps aux | grep dnsmasq | grep cuttlefish
```

Check dnsmasq logs:

```bash
sudo journalctl | grep dnsmasq
```

**Solution**: Restart service and check firewall:
```bash
sudo systemctl restart cuttlefish-host-resources
sudo firewall-cmd --list-all
```

---

## Firewall Issues

Cuttlefish auto-detects firewalld or iptables. Check which is active:

```bash
sudo systemctl is-active firewalld
```

### Firewalld Configuration

View current configuration:

```bash
sudo firewall-cmd --list-all
```

Check masquerading:

```bash
sudo firewall-cmd --query-masquerade
```

**Solution**: Reload firewall configuration:
```bash
sudo systemctl restart cuttlefish-host-resources
sudo firewall-cmd --reload
```

### Iptables Configuration

If firewalld is inactive, check iptables:

```bash
sudo iptables -t nat -L -n -v
```

Look for MASQUERADE rules for 192.168.96.0/24 and 192.168.98.0/24.

### Port Access Issues

Check if operator/orchestrator ports are accessible:

```bash
sudo ss -tlnp | grep -E '1080|1443|2080|2081'
```

**Solution**: Open ports in firewall:
```bash
# Firewalld
sudo firewall-cmd --add-port=1080/tcp --permanent
sudo firewall-cmd --add-port=1443/tcp --permanent
sudo firewall-cmd --add-port=2080/tcp --permanent
sudo firewall-cmd --add-port=2081/tcp --permanent
sudo firewall-cmd --reload

# iptables
sudo iptables -I INPUT -p tcp --dport 1080 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 1443 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 2080 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 2081 -j ACCEPT
sudo service iptables save
```

---

## Build Failures

### Bazel Not Found

```
Error: bazel: command not found
```

**Solution**:
```bash
# Install via Copr
sudo dnf copr enable vbatts/bazel
sudo dnf install bazel

# Or install Bazelisk
sudo wget -O /usr/local/bin/bazelisk \
    https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64
sudo chmod +x /usr/local/bin/bazelisk
sudo ln -s /usr/local/bin/bazelisk /usr/local/bin/bazel
```

### Missing Build Dependencies

```
Error: Package 'gflags-devel' not found
```

**Solution**: Enable required repositories:
```bash
# Enable EPEL
sudo dnf install epel-release

# Enable CRB (CodeReady Builder)
sudo dnf config-manager --set-enabled crb

# Install all dependencies
sudo dnf install $(cat base/rhel/*.spec frontend/rhel/*.spec | grep BuildRequires | awk '{print $2}')
```

### Out of Memory During Build

**Solution**: Limit Bazel memory usage:
```bash
# Set in ~/.bazelrc
build --local_ram_resources=4096
build --jobs=2
```

---

## Package Installation Issues

### Dependency Conflicts

```
Error: package conflicts with...
```

**Solution**: Remove conflicting packages:
```bash
sudo dnf remove <conflicting-package>
sudo dnf install cuttlefish-common
```

### GPG Signature Verification Failed

**Solution**: Import GPG key:
```bash
sudo rpm --import /path/to/cuttlefish-gpg-key.pub
```

Or skip signature verification (not recommended):
```bash
sudo dnf install --nogpgcheck cuttlefish-common
```

### Repository Not Found

**Solution**: Add Cuttlefish repository:
```bash
sudo dnf config-manager --add-repo https://example.com/cuttlefish/cuttlefish.repo
```

---

## Debugging Commands

### System Information

```bash
# OS version
cat /etc/os-release

# SELinux mode
getenforce

# Firewall status
sudo systemctl status firewalld
sudo systemctl status iptables

# Kernel version
uname -r

# Available memory
free -h

# Disk space
df -h
```

### Cuttlefish Status

```bash
# All services
sudo systemctl status cuttlefish-*

# Network interfaces
ip link show | grep cvd

# Loaded kernel modules
lsmod | grep -E "kvm|vhost|bridge"

# Device permissions
ls -l /dev/kvm /dev/vhost-*

# Users and groups
getent group cvdnetwork
getent passwd _cutf-operator
getent passwd httpcvd
```

---

## Getting Help

If you continue to experience issues:

1. **Check logs**: `journalctl -xe`
2. **Check SELinux**: `ausearch -m avc -ts recent`
3. **File a bug**: https://github.com/google/android-cuttlefish/issues
4. **Include**:
   - Output of `cat /etc/os-release`
   - Output of `getenforce`
   - Relevant logs from `journalctl`
   - Any AVC denials from `ausearch`
