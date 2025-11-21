# Cuttlefish Repository Guide for RHEL-based Systems

This document explains the repository requirements and setup for installing Cuttlefish on RHEL 10, CentOS Stream 10, and Fedora 43.

## Table of Contents

- [Overview](#overview)
- [Required Repositories](#required-repositories)
- [Repository Setup by Distribution](#repository-setup-by-distribution)
- [Repository Priorities](#repository-priorities)
- [Troubleshooting Repository Issues](#troubleshooting-repository-issues)
- [Build Dependencies](#build-dependencies)

## Overview

Cuttlefish requires packages from multiple repositories:

| Repository | Purpose | RHEL 10 | CentOS Stream 10 | Fedora 43 |
|-----------|---------|---------|------------------|-----------|
| **Base** | Core system packages | ✅ Included | ✅ Included | ✅ Included |
| **AppStream** | Application packages | ✅ Included | ✅ Included | ✅ Included |
| **EPEL** | Extra packages | ✅ Required | ✅ Required | ❌ Not needed |
| **CRB** | Developer packages | ✅ Required | ✅ Required | ❌ Not needed |
| **Bazel Copr** | Bazel build tool | ⚠️ Optional | ⚠️ Optional | ⚠️ Optional |

## Required Repositories

### EPEL (Extra Packages for Enterprise Linux)

EPEL provides additional packages not included in RHEL/CentOS Stream base repositories.

**Required for**: RHEL 10, CentOS Stream 10
**Not needed for**: Fedora 43 (has these packages in default repos)

**Packages from EPEL**:
- Development libraries
- Additional build tools
- Some SELinux utilities

### CRB (CodeReady Builder)

CRB provides development packages and libraries needed for building software.

**Required for**: RHEL 10, CentOS Stream 10
**Not needed for**: Fedora 43

**Packages from CRB**:
- Development headers (`-devel` packages)
- Build utilities
- Additional compilers and tools

**Repository Names**:
- RHEL 10: `codeready-builder-for-rhel-10-$(arch)-rpms`
- CentOS Stream 10: `crb`

### Bazel Copr Repository

Optional repository for Bazel build tool (fallback method).

**Provider**: vbatts/bazel Copr
**Primary installation method**: Bazelisk from GitHub releases
**Fallback method**: Copr repository

## Repository Setup by Distribution

### RHEL 10

#### Prerequisites

- Active Red Hat subscription
- System registered with subscription-manager

#### Verify Subscription

```bash
# Check subscription status
sudo subscription-manager status

# Expected output:
# Overall Status: Current
```

#### Enable Required Repositories

```bash
# 1. Enable CodeReady Builder (CRB)
sudo subscription-manager repos \
    --enable codeready-builder-for-rhel-10-$(arch)-rpms

# Verify CRB is enabled
sudo subscription-manager repos --list-enabled | grep codeready

# 2. Install EPEL
sudo dnf install -y epel-release

# Verify EPEL is installed
sudo dnf repolist | grep epel

# 3. Update repository metadata
sudo dnf makecache
```

#### Optional: Enable Bazel Copr

```bash
# Install dnf copr plugin
sudo dnf install -y 'dnf-command(copr)'

# Enable vbatts/bazel repository
sudo dnf copr enable -y vbatts/bazel

# Note: Bazelisk is the preferred method for installing Bazel
```

### CentOS Stream 10

#### Enable Required Repositories

```bash
# 1. Enable CRB repository
sudo dnf config-manager --set-enabled crb

# Verify CRB is enabled
sudo dnf repolist | grep crb

# 2. Install EPEL
sudo dnf install -y epel-release

# Verify EPEL is installed
sudo dnf repolist | grep epel

# 3. Update repository metadata
sudo dnf makecache
```

#### Optional: Enable Bazel Copr

```bash
# Install dnf copr plugin
sudo dnf install -y 'dnf-command(copr)'

# Enable vbatts/bazel repository
sudo dnf copr enable -y vbatts/bazel
```

### Fedora 43

Fedora 43 includes all required packages in default repositories.

```bash
# No additional repository setup required

# Update system (recommended)
sudo dnf update -y

# Update repository metadata
sudo dnf makecache
```

**Note**: Fedora does not use EPEL or CRB repositories. All development packages are in the main Fedora repositories.

## Repository Priorities

### Default Repository Priority

DNF uses the following priority order (highest to lowest):

1. **Local repositories** (if configured)
2. **Subscription repositories** (RHEL only)
3. **EPEL** (priority: 100)
4. **CRB** (priority: 100)
5. **Copr repositories** (priority: 100)

### Setting Custom Priorities

If you experience package conflicts, you can set custom priorities:

```bash
# Install dnf-plugins-core
sudo dnf install -y dnf-plugins-core

# Set repository priority
# Lower number = higher priority

# Example: Set EPEL to priority 90 (higher than default)
sudo dnf config-manager --save \
    --setopt="epel.priority=90" \
    epel
```

### Checking Repository Priority

```bash
# View all enabled repositories with priorities
sudo dnf repolist -v | grep -E "(Repo-id|Priority)"
```

## Troubleshooting Repository Issues

### Issue: CRB Repository Not Found (RHEL)

**Symptom**:
```
Error: Unknown repo: 'codeready-builder-for-rhel-10-x86_64-rpms'
```

**Solution**:
```bash
# Check available repositories
sudo subscription-manager repos --list | grep codeready

# Enable using the correct name for your architecture
# For x86_64:
sudo subscription-manager repos \
    --enable codeready-builder-for-rhel-10-x86_64-rpms

# For aarch64:
sudo subscription-manager repos \
    --enable codeready-builder-for-rhel-10-aarch64-rpms
```

### Issue: CRB Repository Not Found (CentOS Stream)

**Symptom**:
```
Error: Unknown repo: 'crb'
```

**Solution**:
```bash
# Try alternative enable method
sudo dnf config-manager --enable crb

# Or manually create repo file
sudo cat > /etc/yum.repos.d/crb.repo <<'EOF'
[crb]
name=CentOS Stream $releasever - CRB
baseurl=http://mirror.stream.centos.org/$releasever-stream/CRB/$basearch/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

# Update metadata
sudo dnf makecache
```

### Issue: EPEL Installation Fails

**Symptom**:
```
Error: Unable to find a match: epel-release
```

**Solution**:
```bash
# Download and install EPEL manually
# For RHEL 10 / CentOS Stream 10:
sudo dnf install -y \
    https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm

# Verify installation
sudo dnf repolist | grep epel
```

### Issue: Package Conflicts Between Repositories

**Symptom**:
```
Error: Transaction test error:
  file /usr/bin/foo from install of package-1.0 conflicts with file from package package-2.0
```

**Solution**:
```bash
# Check which repository provides the package
dnf repoquery --whatprovides package-name

# Install from specific repository
sudo dnf install --repo=epel package-name

# Or disable conflicting repository temporarily
sudo dnf install package-name --disablerepo=repository-name
```

### Issue: GPG Key Import Failures

**Symptom**:
```
warning: /var/cache/dnf/epel-xxx/packages/package.rpm: Header V4 RSA/SHA256 Signature, key ID xxx: NOKEY
```

**Solution**:
```bash
# Import EPEL GPG key manually
sudo rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-10

# For CentOS Stream
sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

# For Fedora
sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-43-primary
```

### Issue: Repository Metadata Corruption

**Symptom**:
```
Error: Failed to download metadata for repo 'xxx'
```

**Solution**:
```bash
# Clean all cached repository metadata
sudo dnf clean all

# Rebuild cache
sudo dnf makecache

# If problem persists, clean specific repo
sudo rm -rf /var/cache/dnf/repo-name-*
sudo dnf makecache
```

## Build Dependencies

### Packages from Base Repositories

Most packages come from base/appstream:
- `gcc`, `gcc-c++`, `make`
- `cmake`, `ninja-build`
- `git`, `wget`, `curl`
- `rpm-build`, `rpmdevtools`

### Packages from EPEL (RHEL/CentOS Stream only)

EPEL provides:
- Additional development libraries
- Some Python packages
- Build utilities

### Packages from CRB (RHEL/CentOS Stream only)

CRB provides development headers:
- `gflags-devel`
- `glog-devel`
- `protobuf-devel`
- `jsoncpp-devel`
- Various `-devel` packages

### Bazel Installation

Cuttlefish requires Bazel for building. Two installation methods:

#### Method 1: Bazelisk (Recommended)

```bash
# Download Bazelisk
wget -O /tmp/bazelisk \
    https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-$(uname -m)

# Install
sudo install -m 0755 /tmp/bazelisk /usr/local/bin/bazelisk
sudo ln -sf /usr/local/bin/bazelisk /usr/local/bin/bazel

# Verify
bazel version
```

#### Method 2: Copr Repository (Fallback)

```bash
# Enable Copr repository
sudo dnf copr enable -y vbatts/bazel

# Install Bazel
sudo dnf install -y bazel

# Verify
bazel version
```

## Repository Maintenance

### Update Repository Metadata

```bash
# Update all repository metadata
sudo dnf makecache

# Update and refresh expired metadata
sudo dnf makecache --refresh
```

### Check Repository Health

```bash
# List all enabled repositories
sudo dnf repolist

# List all repositories (including disabled)
sudo dnf repolist --all

# Show repository details
sudo dnf repoinfo repository-name
```

### Disable/Enable Repositories Temporarily

```bash
# Install package with specific repo disabled
sudo dnf install package-name --disablerepo=epel

# Install package with only specific repo enabled
sudo dnf install package-name --enablerepo=epel --disablerepo=\*
```

## References

- **RHEL Documentation**: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/10
- **EPEL Project**: https://docs.fedoraproject.org/en-US/epel/
- **CentOS Stream**: https://www.centos.org/stream/
- **Fedora Documentation**: https://docs.fedoraproject.org/
- **Copr Repositories**: https://copr.fedorainfracloud.org/

## See Also

- [INSTALL.md](INSTALL.md) - Installation guide
- [DEPENDENCIES.md](DEPENDENCIES.md) - Package dependency mapping
- [DEVELOPMENT.md](DEVELOPMENT.md) - Building from source
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions
