# Cuttlefish RHEL Dependencies Mapping

This document provides a comprehensive mapping of Debian/Ubuntu package dependencies to their RHEL 10 equivalents for the Cuttlefish Android Virtual Device project.

## Table of Contents

- [Overview](#overview)
- [Systematic Mapping Patterns](#systematic-mapping-patterns)
- [Build Dependencies](#build-dependencies)
- [Runtime Dependencies](#runtime-dependencies)
- [Architecture-Specific Dependencies](#architecture-specific-dependencies)
- [Repository Requirements](#repository-requirements)

## Overview

Cuttlefish packages have dependencies that need to be mapped from Debian package names to RHEL package names. This mapping is necessary because:

1. Different naming conventions between distributions
2. Different package splits (e.g., libraries vs development packages)
3. Architecture-specific package names

## Systematic Mapping Patterns

### Development Package Suffix Pattern

All Debian development packages follow the pattern: **`-dev` → `-devel`**

| Pattern | Debian | RHEL |
|---------|--------|------|
| Libraries | `libXXX-dev` | `XXX-devel` |
| Example 1 | `libfmt-dev` | `fmt-devel` |
| Example 2 | `libgflags-dev` | `gflags-devel` |
| Example 3 | `libjsoncpp-dev` | `jsoncpp-devel` |

### Runtime Library Pattern

Runtime libraries often drop the `lib` prefix or use different versioning:

| Debian | RHEL | Notes |
|--------|------|-------|
| `liblzma5` | `xz-libs` | Different package name |
| `libsrtp2-1` | `libsrtp` | Version suffix removed |
| `libz3-4` | `z3-libs` | Uses `-libs` suffix |

## Build Dependencies

Complete mapping of BuildRequires for cuttlefish-base package:

| Debian Package | RHEL Package | Repository | Notes |
|----------------|--------------|------------|-------|
| `bazel [amd64]` | *(via Bazelisk)* | External | Installed via Bazelisk or vbatts/bazel Copr |
| `cmake` | `cmake` | AppStream | Direct mapping |
| `config-package-dev` | *N/A* | - | Debian-specific, not needed for RPM |
| `debhelper-compat` | *N/A* | - | Debian-specific |
| `dh-exec` | *N/A* | - | Debian-specific |
| `git` | `git` | AppStream | Direct mapping |
| `libaom-dev` | `libaom-devel` | EPEL | AV1 codec library |
| `libclang-dev` | `clang-devel` | AppStream | LLVM C/C++ compiler |
| `libcurl4-openssl-dev` | `libcurl-devel` | BaseOS | HTTP client library |
| `libfmt-dev` | `fmt-devel` | CRB/EPEL | C++ formatting library |
| `libgflags-dev` | `gflags-devel` | EPEL | Command-line flags library |
| `libgoogle-glog-dev` | `glog-devel` | EPEL | Google logging library |
| `libgtest-dev` | `gtest-devel` | EPEL | Google Test framework |
| `libjsoncpp-dev` | `jsoncpp-devel` | AppStream | JSON C++ library |
| `liblzma-dev` | `xz-devel` | BaseOS | LZMA compression library |
| `libopus-dev` | `opus-devel` | AppStream | Opus audio codec |
| `libprotobuf-c-dev` | `protobuf-c-devel` | AppStream | Protocol Buffers C library |
| `libprotobuf-dev` | `protobuf-devel` | AppStream | Protocol Buffers C++ library |
| `libsrtp2-dev` | `libsrtp-devel` | AppStream | Secure RTP library |
| `libssl-dev` | `openssl-devel` | AppStream | SSL/TLS library |
| `libxml2-dev` | `libxml2-devel` | BaseOS | XML parsing library |
| `libz3-dev` | `z3-devel` | CRB/EPEL | Z3 theorem prover |
| `pkgconf` | `pkgconf` | BaseOS | Package config tool |
| `protobuf-compiler` | `protobuf-compiler` | AppStream | Protocol Buffers compiler |
| `uuid-dev` | `libuuid-devel` | BaseOS | UUID library |
| `xxd` | `vim-common` | BaseOS | Hex dump utility |

**Frontend Build Dependencies:**

| Debian Package | RHEL Package | Repository | Notes |
|----------------|--------------|------------|-------|
| `golang (>= 2:1.13~)` | `golang >= 1.13` | AppStream | Go programming language |
| `curl` | `curl` | BaseOS | HTTP client |

## Runtime Dependencies

Complete mapping of Requires for cuttlefish-base package:

| Debian Package | RHEL Package | Repository | Type | Notes |
|----------------|--------------|------------|------|-------|
| `adduser` | `shadow-utils` | BaseOS | Required | User management utilities |
| `binfmt-support [arm64]` | `systemd` | BaseOS | Arch-specific | Binary format support built into systemd |
| `bridge-utils` | `iproute` | BaseOS | Required | Bridge management via `ip` command |
| `curl` | `curl` | BaseOS | Required | HTTP client |
| `dnsmasq-base` | `dnsmasq` | AppStream | Required | DNS/DHCP server |
| `ebtables-legacy \| ebtables` | `ebtables-legacy` | AppStream | Required | Ethernet bridge filtering |
| `iproute2` | `iproute` | BaseOS | Required | Network configuration tools |
| `iptables` | `iptables` | BaseOS | Required | Packet filtering |
| `libarchive-tools \| bsdtar` | `bsdtar` | BaseOS | Required | Archive extraction |
| `libcap2-bin` | `libcap` | BaseOS | Required | Capability tools |
| `libcurl4` | `libcurl` | BaseOS | Required | HTTP client library |
| `libdrm2` | `libdrm` | AppStream | Required | Direct Rendering Manager |
| `libfdt1` | `libfdt` | BaseOS | Required | Flattened Device Tree library |
| `libfmt-dev` | `fmt-devel` | CRB/EPEL | Required | C++ formatting (runtime) |
| `libgflags-dev` | `gflags-devel` | EPEL | Required | Command-line flags (runtime) |
| `libgl1` | `mesa-libGL` | AppStream | Required | OpenGL library |
| `libjsoncpp-dev` | `jsoncpp-devel` | AppStream | Required | JSON library (runtime) |
| `liblzma5` | `xz-libs` | BaseOS | Required | LZMA compression runtime |
| `libprotobuf-dev` | `protobuf-devel` | AppStream | Required | Protocol Buffers (runtime) |
| `libsrtp2-1` | `libsrtp` | AppStream | Required | Secure RTP runtime |
| `libssl-dev` | `openssl-devel` | AppStream | Required | SSL/TLS (runtime) |
| `libwayland-client0` | `wayland` | AppStream | Required | Wayland client library |
| `libwayland-server0` | `wayland` | AppStream | Required | Wayland server library |
| `libx11-6` | `libX11` | AppStream | Required | X11 client library |
| `libxext6` | `libXext` | AppStream | Required | X11 extensions |
| `libxml2-dev` | `libxml2-devel` | BaseOS | Required | XML parsing (runtime) |
| `libz3-4` | `z3-libs` | CRB/EPEL | Required | Z3 runtime libraries |
| `net-tools` | `net-tools` | BaseOS | Required | Network utilities (ifconfig, etc.) |
| `openssl` | `openssl` | BaseOS | Required | SSL/TLS tools |
| `opus-tools` | `opus-tools` | AppStream | Required | Opus codec tools |
| `python3` | `python3` | BaseOS | Required | Python 3 interpreter |
| `xdg-utils` | `xdg-utils` | AppStream | Required | XDG utilities |

**Integration Package Dependencies:**

| Debian Package | RHEL Package | Repository | Notes |
|----------------|--------------|------------|-------|
| `qemu-system-arm (>= 2.8.0)` | `qemu-system-arm >= 2.8.0` | AppStream | ARM emulation |
| `qemu-system-x86 (>= 2.8.0)` | `qemu-system-x86 >= 2.8.0` | AppStream | x86 emulation |
| `qemu-system-misc (>= 2.8.0)` | `qemu-system-misc >= 2.8.0` | AppStream | Other architectures |

**User/Orchestration Package Dependencies:**

| Debian Package | RHEL Package | Repository | Notes |
|----------------|--------------|------------|-------|
| `nginx` | `nginx` | AppStream | Web server |
| `systemd-journal-remote` | `systemd-journal-remote` | BaseOS | Journal forwarding |

## Architecture-Specific Dependencies

### aarch64 (ARM64)

| Debian Package | RHEL Package | Repository | Notes |
|----------------|--------------|------------|-------|
| `grub-efi-arm64-bin` | `grub2-efi-aa64` | BaseOS | GRUB EFI for ARM64 |
| `qemu-user-static` | `qemu-user-static` | AppStream | User-mode QEMU emulation |
| `binfmt-support` | `systemd` | BaseOS | Built into systemd |

### x86_64

| Debian Package | RHEL Package | Repository | Notes |
|----------------|--------------|------------|-------|
| `grub-efi-ia32-bin [!arm64]` | `grub2-efi-ia32` | BaseOS | GRUB EFI for x86 |

## Repository Requirements

To install all dependencies, the following repositories must be enabled:

### 1. BaseOS (enabled by default)
Standard RHEL base operating system packages.

### 2. AppStream (enabled by default)
Application streams and additional software.

### 3. EPEL (Extra Packages for Enterprise Linux)
```bash
dnf install epel-release
```

Provides packages:
- `gflags-devel`
- `glog-devel`
- `gtest-devel`
- `fmt-devel` (may also be in CRB)
- `libaom-devel`
- `z3-devel`

### 4. CRB (CodeReady Builder)
```bash
dnf config-manager --set-enabled crb
```

Provides packages:
- `fmt-devel` (if not in EPEL)
- `z3-devel` (if not in EPEL)
- Additional development libraries

**Note:** On RHEL 8 and compatible distributions, this repository is called `powertools` instead of `crb`.

### 5. vbatts/bazel Copr (for Bazel)
```bash
dnf copr enable vbatts/bazel
dnf install bazel
```

**Alternative:** Use Bazelisk (recommended) which auto-downloads the correct Bazel version.

## Package Availability Notes

### Potentially Problematic Packages

The following packages may require verification on actual RHEL 10 systems:

1. **libaom-devel** - May be in EPEL or require RPM Fusion
2. **glog-devel** - Typically in EPEL
3. **fmt-devel** - May be in CRB or EPEL depending on RHEL version
4. **z3-devel** - Typically in CRB or EPEL

**Action Required:** Execute the dependency verification script (Task 2.6) to confirm all packages are available before beginning RPM builds.

## Verification

To verify all dependencies are available on your RHEL system, run:

```bash
./tools/buildutils/verify_rhel_deps.sh
```

This script (created in Task 2.6) will:
1. Parse all spec files for dependencies
2. Check each package with `dnf info`
3. Report any missing packages
4. Identify which repositories need to be enabled

## References

- RHEL Package Documentation: https://access.redhat.com/documentation/
- EPEL: https://docs.fedoraproject.org/en-US/epel/
- Fedora Package Database: https://packages.fedoraproject.org/
- RPM Packaging Guide: https://rpm-packaging-guide.github.io/
