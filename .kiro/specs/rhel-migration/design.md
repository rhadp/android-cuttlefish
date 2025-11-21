# Design Document

## Overview

This design document specifies the architecture and implementation approach for adding RHEL/RPM support to the Android Cuttlefish project. The design follows an additive approach, maintaining full backward compatibility with existing Debian/Ubuntu support while introducing parallel RHEL infrastructure.

The migration involves creating RPM spec files, converting LSB init scripts to systemd units, mapping package dependencies, and establishing build and test infrastructure for RHEL 10 (including derivatives like Rocky Linux and AlmaLinux).

## Architecture

### High-Level Architecture

```
android-cuttlefish/
├── base/
│   ├── debian/          # Existing Debian packaging (unchanged)
│   └── rhel/            # New RHEL packaging
│       ├── *.spec       # RPM spec files
│       ├── *.service    # Systemd unit files
│       └── *.sh         # Service wrapper scripts
├── frontend/
│   ├── debian/          # Existing Debian packaging (unchanged)
│   └── rhel/            # New RHEL packaging
├── tools/
│   └── buildutils/
│       ├── build_packages.sh          # Existing Debian build
│       ├── build_rpm_packages.sh      # New RHEL build
│       └── install_rhel10_deps.sh     # New dependency installer
└── docs/
    └── rhel/            # New RHEL documentation
```

### Package Structure

The RHEL implementation will produce 6 RPM packages mirroring the Debian structure:

1. **cuttlefish-base** - Core tools and binaries
2. **cuttlefish-common** - Meta-package (depends on base + user)
3. **cuttlefish-integration** - GCE utilities and QEMU integration
4. **cuttlefish-defaults** - Experimental features
5. **cuttlefish-user** - WebRTC signaling server (operator)
6. **cuttlefish-orchestration** - Host orchestrator + nginx

### Build System Architecture

```
Build Process Flow:
┌─────────────────┐
│ Detect OS Type  │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
┌───▼───┐ ┌──▼────┐
│Debian │ │ RHEL  │
│Build  │ │ Build │
└───┬───┘ └──┬────┘
    │         │
┌───▼───┐ ┌──▼────┐
│.deb   │ │ .rpm  │
│files  │ │ files │
└───────┘ └───────┘
```

### Backward Compatibility Architecture

The RHEL migration maintains strict backward compatibility through isolation and verification:

**Isolation Strategy:**
- Separate directory structure (`debian/` vs `rhel/`)
- No modifications to existing Debian packaging files
- Independent build scripts with OS detection
- Parallel CI/CD pipelines

**Verification Strategy:**
- Automated comparison of Debian packages before/after RHEL changes
- Continuous testing of Debian functionality
- Regression detection in CI pipeline
- Version synchronization checks

**Compatibility Guarantees:**
- Debian package contents remain unchanged
- Debian build process unmodified
- Debian test pass rates maintained
- Debian runtime behavior preserved

## Design Decisions and Rationale

### Additive Approach vs. Replacement
**Decision:** Implement RHEL support as parallel infrastructure rather than replacing Debian support.

**Rationale:** 
- Maintains backward compatibility for existing Debian/Ubuntu users
- Reduces risk of breaking existing deployments
- Allows gradual migration and testing
- Enables side-by-side comparison during development

### Systemd-Only Approach
**Decision:** Use native systemd units instead of maintaining LSB init script compatibility.

**Rationale:**
- RHEL 10 has fully deprecated LSB init scripts
- Systemd provides better service management (dependencies, restart policies, logging)
- Simplifies maintenance by avoiding dual init system support
- Aligns with modern Linux distribution standards

### Repository Structure
**Decision:** Create parallel `rhel/` directories alongside existing `debian/` directories.

**Rationale:**
- Clear separation of packaging concerns
- Easy to identify RHEL-specific files
- Prevents accidental modification of Debian packaging
- Follows common multi-distribution packaging patterns

### Build Script Detection
**Decision:** Implement OS detection in build scripts rather than separate build systems.

**Rationale:**
- Single entry point for developers regardless of OS
- Reduces documentation complexity
- Ensures consistent build process across distributions
- Simplifies CI/CD pipeline configuration

### Configuration File Locations
**Decision:** Use `/etc/sysconfig/` for RHEL instead of `/etc/default/`.

**Rationale:**
- Follows RHEL/Fedora conventions and packaging guidelines
- Ensures compatibility with system management tools
- Meets requirements for official repository distribution
- Familiar location for RHEL administrators

## Components and Interfaces

### 0. SELinux Integration

**Purpose:** Ensure Cuttlefish services operate correctly with SELinux in enforcing mode (default on RHEL).

**Complexity Assessment:** SELinux policy development for Cuttlefish is a HIGH COMPLEXITY task. Similar network virtualization software (libvirt, docker) requires 1000+ lines of policy code. Cuttlefish performs privileged operations including network bridge creation, KVM device access, and dynamic network configuration, all of which require extensive SELinux permissions.

**Phased Implementation Approach:**

**Phase 1: Permissive Mode with Audit Collection (Weeks 1-2)**
- Ship initial packages with SELinux in permissive mode
- Document requirement for `setenforce 0` or per-domain permissive mode
- Collect AVC denials using `audit2allow` during testing
- Generate baseline policy requirements from real-world usage

**Phase 2: Basic Policy Development (Weeks 3-6)**
- Create type enforcement (.te) files for each service domain
- Define file contexts (.fc) for all Cuttlefish paths
- Implement device access rules for KVM and vhost devices
- Test with SELinux enforcing on development systems

**Phase 3: Production Hardening (Weeks 7-10)**
- Add interface files (.if) for domain interactions
- Implement boolean policies for administrator flexibility
- Add port labeling for network services
- Comprehensive testing on RHEL 10 with enforcing mode

**Policy Modules Required:**

1. **cuttlefish_host_resources.te** - Network infrastructure policy (~400 lines estimated)
   
   **Type Enforcement Rules:**
   ```
   type cuttlefish_host_resources_t;
   type cuttlefish_host_resources_exec_t;
   init_daemon_domain(cuttlefish_host_resources_t, cuttlefish_host_resources_exec_t)
   
   # Network bridge and tap interface creation
   allow cuttlefish_host_resources_t self:capability { net_admin net_raw sys_module };
   allow cuttlefish_host_resources_t self:netlink_route_socket create_netlink_socket_perms;
   kernel_request_load_module(cuttlefish_host_resources_t)
   
   # Kernel module loading (bridge, vhost-net, vhost-vsock, kvm)
   modutils_exec_kmod(cuttlefish_host_resources_t)
   
   # iptables/firewalld rule modification
   iptables_exec(cuttlefish_host_resources_t)
   allow cuttlefish_host_resources_t firewalld_t:dbus send_msg;
   
   # dnsmasq execution
   dnsmasq_domtrans(cuttlefish_host_resources_t)
   allow cuttlefish_host_resources_t dnsmasq_t:process signal;
   
   # ebtables for broute operations
   allow cuttlefish_host_resources_t self:rawip_socket create_socket_perms;
   ```

2. **cuttlefish_operator.te** - Operator service policy (~300 lines estimated)
   
   **Type Enforcement Rules:**
   ```
   type cuttlefish_operator_t;
   type cuttlefish_operator_exec_t;
   init_daemon_domain(cuttlefish_operator_t, cuttlefish_operator_exec_t)
   
   # TLS certificate generation
   allow cuttlefish_operator_t self:capability { dac_override chown fowner };
   allow cuttlefish_operator_t cuttlefish_cert_t:dir create_dir_perms;
   allow cuttlefish_operator_t cuttlefish_cert_t:file create_file_perms;
   miscfiles_read_generic_certs(cuttlefish_operator_t)
   
   # WebRTC signaling server operations
   allow cuttlefish_operator_t self:tcp_socket create_stream_socket_perms;
   allow cuttlefish_operator_t self:udp_socket create_socket_perms;
   corenet_tcp_bind_generic_node(cuttlefish_operator_t)
   corenet_udp_bind_generic_node(cuttlefish_operator_t)
   
   # Port binding (configurable ports - requires port labeling)
   # Default: 1080 (HTTP), 1443 (HTTPS)
   corenet_tcp_bind_http_cache_port(cuttlefish_operator_t)
   
   # Socket creation in /run/cuttlefish/
   allow cuttlefish_operator_t cuttlefish_var_run_t:dir create_dir_perms;
   allow cuttlefish_operator_t cuttlefish_var_run_t:sock_file create_file_perms;
   ```

3. **cuttlefish_orchestration.te** - Orchestration service policy (~300 lines estimated)
   
   **Type Enforcement Rules:**
   ```
   type cuttlefish_orchestrator_t;
   type cuttlefish_orchestrator_exec_t;
   init_daemon_domain(cuttlefish_orchestrator_t, cuttlefish_orchestrator_exec_t)
   
   # nginx integration
   allow cuttlefish_orchestrator_t httpd_t:unix_stream_socket connectto;
   allow httpd_t cuttlefish_orchestrator_t:unix_stream_socket connectto;
   
   # systemd-journal-gatewayd communication
   allow cuttlefish_orchestrator_t systemd_journal_gatewayd_t:unix_stream_socket connectto;
   
   # Artifact directory access
   allow cuttlefish_orchestrator_t cuttlefish_var_lib_t:dir create_dir_perms;
   allow cuttlefish_orchestrator_t cuttlefish_var_lib_t:file create_file_perms;
   
   # Network operations
   allow cuttlefish_orchestrator_t self:tcp_socket create_stream_socket_perms;
   corenet_tcp_bind_generic_node(cuttlefish_orchestrator_t)
   ```

**File Contexts (.fc files):**
```
# Binaries
/usr/lib/cuttlefish-common/bin/.*          -- system_u:object_r:cuttlefish_exec_t:s0
/usr/lib/cuttlefish-common/bin/setup-host-resources\.sh -- system_u:object_r:cuttlefish_host_resources_exec_t:s0
/usr/lib/cuttlefish-common/bin/operator    -- system_u:object_r:cuttlefish_operator_exec_t:s0
/usr/lib/cuttlefish-common/bin/host_orchestrator -- system_u:object_r:cuttlefish_orchestrator_exec_t:s0

# Configuration files
/etc/sysconfig/cuttlefish-.*               -- system_u:object_r:cuttlefish_conf_t:s0

# Runtime directories
/var/run/cuttlefish(/.*)?                  -- system_u:object_r:cuttlefish_var_run_t:s0
/run/cuttlefish(/.*)?                      -- system_u:object_r:cuttlefish_var_run_t:s0

# Data directories
/var/lib/cuttlefish-common(/.*)?           -- system_u:object_r:cuttlefish_var_lib_t:s0

# Certificates
/etc/cuttlefish-common/operator/cert(/.*)?  -- system_u:object_r:cuttlefish_cert_t:s0
```

**Device Access Rules:**
```
# KVM device access
dev_rw_kvm(cuttlefish_host_resources_t)
allow cuttlefish_host_resources_t device_t:chr_file { getattr open read write ioctl };

# vhost device access
allow cuttlefish_host_resources_t vhost_device_t:chr_file { getattr open read write ioctl };
# If vhost_device_t doesn't exist, use:
allow cuttlefish_host_resources_t device_t:chr_file { getattr open read write ioctl };
```

**Port Labeling:**

Cuttlefish uses configurable ports that need SELinux port labels:

```bash
# Operator HTTP port (default: 1080)
semanage port -a -t cuttlefish_operator_port_t -p tcp 1080

# Operator HTTPS port (default: 1443)
semanage port -a -t cuttlefish_operator_port_t -p tcp 1443

# Orchestrator port (default: 2080)
semanage port -a -t cuttlefish_orchestrator_port_t -p tcp 2080
```

**Boolean Policies:**

Administrators need flexibility to relax restrictions:

```
# Allow network bridge and tap interface creation
bool cuttlefish_networking true;

# Allow TLS certificate generation
bool cuttlefish_tls true;

# Allow KVM device access
bool cuttlefish_kvm true;

# Allow connection to all network ports (for development)
bool cuttlefish_connect_any false;
```

**Domain Transitions:**

Services must transition from init domain to Cuttlefish domains:

```
# systemd → cuttlefish_host_resources_t
init_daemon_domain(cuttlefish_host_resources_t, cuttlefish_host_resources_exec_t)

# systemd → cuttlefish_operator_t
init_daemon_domain(cuttlefish_operator_t, cuttlefish_operator_exec_t)

# systemd → cuttlefish_orchestrator_t
init_daemon_domain(cuttlefish_orchestrator_t, cuttlefish_orchestrator_exec_t)
```

**Interface Files (.if files):**

Allow other domains to interact with Cuttlefish:

```
## <summary>Cuttlefish Android Virtual Device system</summary>

interface(`cuttlefish_read_config',`
    gen_require(`
        type cuttlefish_conf_t;
    ')
    allow $1 cuttlefish_conf_t:file read_file_perms;
')

interface(`cuttlefish_manage_lib_files',`
    gen_require(`
        type cuttlefish_var_lib_t;
    ')
    allow $1 cuttlefish_var_lib_t:dir manage_dir_perms;
    allow $1 cuttlefish_var_lib_t:file manage_file_perms;
')
```

**Testing Strategy:**

1. **Development Testing:**
   - Run services with `audit2allow -a` to collect denials
   - Iteratively add permissions to policy
   - Test with `setenforce 1` on development systems

2. **Automated Testing:**
   - CI pipeline runs with SELinux enforcing
   - Check for AVC denials in audit log
   - Fail build if denials detected

3. **Manual Testing:**
   - Test all service operations (start, stop, restart)
   - Test network configuration with multiple CVD accounts
   - Test certificate generation
   - Test device boot and connectivity

**Implementation in RPM Spec:**

```spec
%post
# Install SELinux policy modules
if [ $1 -eq 1 ]; then
    # First installation
    semodule -i %{_datadir}/selinux/packages/cuttlefish_host_resources.pp
    semodule -i %{_datadir}/selinux/packages/cuttlefish_operator.pp
    semodule -i %{_datadir}/selinux/packages/cuttlefish_orchestration.pp
    
    # Restore file contexts
    restorecon -R /usr/lib/cuttlefish-common/
    restorecon -R /etc/sysconfig/cuttlefish-*
    restorecon -R /var/lib/cuttlefish-common/ || true
    restorecon -R /run/cuttlefish/ || true
fi

%postun
# Remove SELinux policy modules
if [ $1 -eq 0 ]; then
    # Final removal
    semodule -r cuttlefish_host_resources || true
    semodule -r cuttlefish_operator || true
    semodule -r cuttlefish_orchestration || true
fi
```

**Documentation Requirements:**

The TROUBLESHOOTING.md must include:
- How to check for SELinux denials: `ausearch -m avc -ts recent`
- How to generate policy from denials: `audit2allow -a`
- How to temporarily disable SELinux: `setenforce 0`
- How to set per-domain permissive: `semanage permissive -a cuttlefish_host_resources_t`
- How to check boolean status: `getsebool -a | grep cuttlefish`
- How to set booleans: `setsebool -P cuttlefish_networking on`

**Design Rationale:** SELinux is mandatory for RHEL production deployments. Without proper policies, services will fail with permission denied errors even when running as root. Custom policies are required because Cuttlefish performs privileged network operations not covered by standard policies. The phased approach allows initial deployment while policy development continues, reducing time-to-market while maintaining a path to full security compliance.

### 1. RPM Spec Files

**Location:** `base/rhel/*.spec`, `frontend/rhel/*.spec`

**Purpose:** Define package metadata, dependencies, build instructions, and installation procedures for RPM packages.

**Key Sections:**
- **Header**: Name, Version, Release, Summary, License, URL
- **Dependencies**: BuildRequires, Requires (with architecture conditionals)
- **%prep**: Source extraction and preparation using `%setup -q -n package-name-%{version}`
- **%build**: Compilation using Bazel (C++) and Go
- **%install**: File installation to buildroot
- **%pre/%post/%preun/%postun**: Installation scripts
- **%files**: List of files included in package
- **%changelog**: Version history

**%prep Section Example:**
```spec
%prep
%setup -q -n cuttlefish-base-%{version}
# Verify WORKSPACE exists for Bazel builds
test -f WORKSPACE || exit 1
```

**%install Section - Udev Rules Handling:**

Udev rules must be installed to the correct RHEL location and triggered:

```spec
%install
# ... other installation commands ...

# Install udev rules to RHEL location
install -D -m 0644 debian/cuttlefish-base.udev \
    %{buildroot}/usr/lib/udev/rules.d/99-cuttlefish-base.rules
install -D -m 0644 debian/cuttlefish-integration.udev \
    %{buildroot}/usr/lib/udev/rules.d/99-cuttlefish-integration.rules
```

**%post Section - Udev Reload:**
```spec
%post
# Reload udev rules
udevadm control --reload-rules || true
udevadm trigger || true

# Set device permissions for KVM and vhost
if [ -e /dev/kvm ]; then
    chgrp cvdnetwork /dev/kvm
    chmod 0660 /dev/kvm
fi

if [ -e /dev/vhost-net ]; then
    chgrp cvdnetwork /dev/vhost-net
    chmod 0660 /dev/vhost-net
fi

if [ -e /dev/vhost-vsock ]; then
    chgrp cvdnetwork /dev/vhost-vsock
    chmod 0660 /dev/vhost-vsock
fi
```

**Udev Rules Content:**

The udev rules set permissions for device access:

```
# /usr/lib/udev/rules.d/99-cuttlefish-base.rules
# KVM device access for cvdnetwork group
KERNEL=="kvm", GROUP="cvdnetwork", MODE="0660"

# vhost device access for cvdnetwork group
KERNEL=="vhost-net", GROUP="cvdnetwork", MODE="0660"
KERNEL=="vhost-vsock", GROUP="cvdnetwork", MODE="0660"

# TUN/TAP device access
KERNEL=="tun", GROUP="cvdnetwork", MODE="0660"
```

**Interface with Build System:**
- Reads source tarballs from `~/rpmbuild/SOURCES/`
- Outputs RPM files to `~/rpmbuild/RPMS/`
- Uses RPM macros for systemd integration
- Handles udev rules installation and triggering

### 2. Systemd Service Units

**Location:** `base/rhel/*.service`, `frontend/rhel/*.service`

**Purpose:** Replace LSB init scripts with native systemd units for service management.

**Services:**
- `cuttlefish-host-resources.service` - Network infrastructure setup
- `cuttlefish-operator.service` - WebRTC signaling server
- `cuttlefish-host_orchestrator.service` - Device orchestration

**Key Features:**
- Type=oneshot for host-resources (setup task)
- Type=simple for operator and orchestrator (long-running services)
- EnvironmentFile for configuration
- Automatic restart on failure
- Proper dependency ordering (After/Requires)
- Security hardening options

**Security Hardening:**

Systemd units should include security hardening options appropriate for RHEL deployments:

```ini
[Service]
# Basic hardening
PrivateTmp=yes
NoNewPrivileges=yes

# Filesystem protection (adjust based on service needs)
# Note: cuttlefish-host-resources needs ProtectSystem=false for network config
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/cuttlefish-common /run/cuttlefish

# Kernel protection
ProtectKernelTunables=yes
ProtectKernelModules=no  # host-resources needs to load modules
ProtectKernelLogs=yes
ProtectControlGroups=yes

# Network restrictions (adjust per service)
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK

# Capability restrictions (adjust per service)
# host-resources needs CAP_NET_ADMIN, CAP_NET_RAW, CAP_SYS_MODULE
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_SYS_MODULE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_SYS_MODULE

# System call filtering (optional, may need adjustment)
SystemCallFilter=@system-service
SystemCallErrorNumber=EPERM
```

**Service-Specific Hardening:**

**cuttlefish-host-resources.service:**
```ini
[Service]
Type=oneshot
PrivateTmp=yes
ProtectSystem=false  # Needs to modify network configuration
ProtectHome=yes
ProtectKernelModules=no  # Needs to load kernel modules
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_SYS_MODULE CAP_SYS_ADMIN
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK AF_PACKET
```

**cuttlefish-operator.service:**
```ini
[Service]
Type=simple
User=_cutf-operator
Group=cvdnetwork
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/run/cuttlefish /etc/cuttlefish-common/operator/cert
ProtectKernelModules=yes
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
```

**cuttlefish-host_orchestrator.service:**
```ini
[Service]
Type=simple
User=httpcvd
Group=cvdnetwork
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/cuttlefish-common /run/cuttlefish
ProtectKernelModules=yes
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
```

**Design Rationale:** Security hardening is a best practice for RHEL services and may be required for security compliance. The restrictions are balanced to provide security without breaking Cuttlefish functionality. Services that need privileged operations (like host-resources) have more permissive settings, while user-facing services (operator, orchestrator) are more restricted.

### 3. Service Wrapper Scripts

**Location:** `base/rhel/*.sh`, `frontend/rhel/*.sh`

**Purpose:** Extract complex shell logic from init scripts into standalone scripts called by systemd.

**Scripts:**
- `setup-host-resources.sh` - Network bridge and tap interface creation
- `generate-operator-certs.sh` - TLS certificate generation

**Interface:**
- Called by systemd ExecStart/ExecStartPre
- Source configuration from /etc/sysconfig/
- Exit with appropriate status codes
- Log to systemd journal

**Firewall Integration:**

RHEL 10 uses firewalld by default instead of direct iptables manipulation. The setup-host-resources.sh script must detect and handle both:

**Firewalld Detection:**
```bash
if systemctl is-active --quiet firewalld; then
    use_firewalld=1
    default_zone=$(firewall-cmd --get-default-zone)
else
    use_firewalld=0
fi
```

**NAT Configuration:**
- **With firewalld:** 
  ```bash
  # Get the default zone (may be 'public', 'FedoraServer', etc.)
  default_zone=$(firewall-cmd --get-default-zone)
  
  # Add masquerading to default zone
  firewall-cmd --add-masquerade --zone=${default_zone} --permanent
  
  # Open required ports for operator and orchestrator
  firewall-cmd --add-port=${operator_http_port}/tcp --zone=${default_zone} --permanent
  firewall-cmd --add-port=${operator_https_port}/tcp --zone=${default_zone} --permanent
  firewall-cmd --add-port=${orchestrator_port}/tcp --zone=${default_zone} --permanent
  
  # Reload to apply changes
  firewall-cmd --reload
  ```

- **Without firewalld:** 
  ```bash
  # Configure NAT for Cuttlefish networks
  iptables -t nat -A POSTROUTING -s 192.168.96.0/24 -j MASQUERADE
  iptables -t nat -A POSTROUTING -s 192.168.98.0/24 -j MASQUERADE
  
  # Save rules (method varies by distribution)
  if command -v iptables-save > /dev/null; then
      iptables-save > /etc/sysconfig/iptables
  fi
  ```

**Design Rationale:** Firewalld is the standard firewall management tool on RHEL. Direct iptables manipulation can conflict with firewalld rules. The script must detect which system is active and use the appropriate commands. Using `--get-default-zone` ensures compatibility across different RHEL configurations where the default zone may not be "public" (e.g., "FedoraServer" on some systems). Port opening is required for external access to operator and orchestrator services.

### 4. Build Scripts

**Location:** `tools/buildutils/build_rpm_packages.sh`

**Purpose:** Automate the complete RPM build process including dependency installation, source preparation, and package creation.

**Workflow:**
1. Detect RHEL version (verify RHEL 10)
2. Install build dependencies
3. Install or verify Bazel availability
4. Setup rpmbuild directory structure
5. Create source tarballs
6. Build RPM packages using rpmbuild
7. Copy packages to output directory

**Dependencies:**
- `install_rhel10_deps.sh` - RHEL 10 dependency installation

**Go Build Flags for RHEL Compliance:**

RHEL packaging requires specific Go build flags for security and reproducibility:

```bash
# RHEL-compliant Go build command
go build \
    -buildmode=pie \
    -compiler=gc \
    -trimpath \
    -ldflags "${LDFLAGS:-} -B 0x$(head -c20 /dev/urandom|od -An -tx1|tr -d ' \n') -linkmode=external -extldflags=-Wl,-z,relro,-z,now" \
    -a -v -x \
    -o ${output_binary} \
    ${source_package}
```

**Flag Explanations:**
- `-buildmode=pie`: Position Independent Executable (required for ASLR)
- `-compiler=gc`: Use Go compiler (standard)
- `-trimpath`: Remove absolute paths for reproducible builds
- `-ldflags`: Linker flags for hardening
  - `-B 0x...`: Build ID for reproducibility
  - `-linkmode=external`: Use external linker for hardening flags
  - `-extldflags=-Wl,-z,relro,-z,now`: Enable RELRO and immediate binding
- `-a`: Force rebuild of all packages
- `-v`: Verbose output
- `-x`: Print commands

**RPM Spec Integration:**
```spec
%build
# Set Go build flags for RHEL compliance
export CGO_ENABLED=1
export GOFLAGS="-buildmode=pie -trimpath"
export LDFLAGS="-linkmode=external -extldflags=-Wl,-z,relro,-z,now"

# Build Go binaries
cd frontend/src
go build ${GOFLAGS} -ldflags "${LDFLAGS}" -o operator ./cmd/operator
go build ${GOFLAGS} -ldflags "${LDFLAGS}" -o host_orchestrator ./cmd/orchestrator
```

**Bazel Installation Strategy:**

Bazel is not available in standard RHEL repositories. The build system will use one of these approaches:

1. **Primary: Bazelisk** (Recommended)
   - Install Bazelisk binary from GitHub releases
   - Bazelisk automatically downloads correct Bazel version
   - Version specified in .bazelversion file
   - Portable across RHEL versions

2. **Alternative: vbatts/bazel Copr Repository**
   - Enable Copr repository: `dnf copr enable vbatts/bazel`
   - Install Bazel: `dnf install bazel`
   - Verify version compatibility with project

3. **Fallback: Manual Installation**
   - Download Bazel binary from GitHub releases
   - Install to /usr/local/bin/
   - Document version requirements

**Version Management:**

The build system needs a portable way to extract version numbers that works on both Debian and RHEL systems:

**Option 1: Portable Changelog Parsing (Recommended)**
```bash
# Extract version from debian/changelog using portable sed/awk
VERSION=$(head -n1 base/debian/changelog | sed 's/.*(\([^)]*\)).*/\1/' | cut -d- -f1)
```

**Option 2: Dedicated VERSION File**
```bash
# Create VERSION file in repository root
echo "1.0.0" > VERSION

# Read version from file
VERSION=$(cat VERSION)
```

**Source Tarball Creation:**

Bazel projects require special handling for source tarballs:

```bash
# Extract version using portable method
VERSION=$(head -n1 base/debian/changelog | sed 's/.*(\([^)]*\)).*/\1/' | cut -d- -f1)

# Create clean source tarball including Bazel workspace
tar czf ~/rpmbuild/SOURCES/cuttlefish-base-${VERSION}.tar.gz \
  --transform "s,^base/,cuttlefish-base-${VERSION}/," \
  --exclude='.git' \
  --exclude='bazel-*' \
  --exclude='.*.swp' \
  --dereference \
  base/

# Frontend tarball
VERSION=$(head -n1 frontend/debian/changelog | sed 's/.*(\([^)]*\)).*/\1/' | cut -d- -f1)
tar czf ~/rpmbuild/SOURCES/cuttlefish-frontend-${VERSION}.tar.gz \
  --transform "s,^frontend/,cuttlefish-frontend-${VERSION}/," \
  --exclude='.git' \
  --exclude='bazel-*' \
  --exclude='.*.swp' \
  --dereference \
  frontend/
```

**Design Rationale:** The `dpkg-parsechangelog` command is Debian-specific and not available on RHEL systems. Using portable sed/awk commands ensures the build system works on both platforms. The `--dereference` flag handles Bazel symlinks correctly. Bazel availability is critical for building C++ components. Bazelisk provides the most reliable cross-version solution. Source tarballs must preserve Bazel workspace structure (WORKSPACE, BUILD files) for rpmbuild to execute Bazel commands.

### 5. Documentation System

**Location:** `docs/rhel/`

**Purpose:** Provide comprehensive documentation for RHEL deployment, development, and troubleshooting.

**Documentation Structure:**
- `INSTALL.md` - Installation instructions for RHEL 10
- `REPOSITORIES.md` - Repository configuration guide (EPEL, CRB, Copr)
- `DEPENDENCIES.md` - Package dependency mappings from Debian to RHEL
- `TROUBLESHOOTING.md` - Common issues and solutions
- `DEVELOPMENT.md` - Building RPM packages from source
- `MIGRATION.md` - Migration guide for Debian users

**Key Content:**

**Installation Guide:**
- Prerequisites and system requirements
- Repository setup commands
- Package installation steps
- Post-installation verification
- Multi-device configuration

**Repository Configuration:**
- EPEL repository setup and purpose
- CRB (CodeReady Builder) repository activation
- vbatts/bazel Copr repository for Bazel installation
- Repository priority and conflict resolution

**Dependency Mappings:**
- Complete table of Debian → RHEL package mappings
- Architecture-specific dependencies
- Optional vs. required dependencies
- Version compatibility notes

**Troubleshooting Guide:**
- Common installation errors and solutions
- Service startup failures
- Network configuration issues
- Permission and SELinux problems
- Build failures and resolution steps

**Development Guide:**
- Setting up build environment
- Building individual packages
- Testing changes locally
- Contributing RHEL-specific patches
- Debugging RPM build issues

**Dependency Mapping Appendix:**

The DEPENDENCIES.md file must include a complete mapping table. This should be generated from the actual debian/control files:

| Debian Package | RHEL Package | Repository | Notes |
|----------------|--------------|------------|-------|
| adduser | shadow-utils | BaseOS | User management |
| iproute2 | iproute | BaseOS | Network tools |
| libcap2-bin | libcap | BaseOS | Capability tools |
| dnsmasq-base | dnsmasq | AppStream | DHCP/DNS server |
| ebtables | ebtables-legacy | AppStream | Bridge filtering |
| libfmt-dev | fmt-devel | CRB | C++ formatting library |
| libgflags-dev | gflags-devel | EPEL | Command-line flags |
| libjsoncpp-dev | jsoncpp-devel | AppStream | JSON library |
| libprotobuf-dev | protobuf-devel | AppStream | Protocol buffers |
| libssl-dev | openssl-devel | AppStream | SSL/TLS library |
| grub-efi-arm64-bin | grub2-efi-aa64 | BaseOS | GRUB for aarch64 |
| grub-efi-ia32-bin | grub2-efi-ia32 | BaseOS | GRUB for x86_64 |

**Verification Script:**

A script should be provided to verify all dependencies are available:

```bash
#!/bin/bash
# verify_rhel_deps.sh

missing_packages=()

while IFS='|' read -r debian rhel repo notes; do
    # Skip header and empty lines
    [[ "$debian" =~ ^[[:space:]]*Debian ]] && continue
    [[ -z "$rhel" ]] && continue
    
    rhel=$(echo "$rhel" | xargs)  # trim whitespace
    
    if ! dnf info "$rhel" &>/dev/null; then
        missing_packages+=("$rhel (from $repo)")
    fi
done < dependency_mapping.txt

if [ ${#missing_packages[@]} -gt 0 ]; then
    echo "Missing packages:"
    printf '%s\n' "${missing_packages[@]}"
    exit 1
else
    echo "All dependencies available"
fi
```

**Design Rationale:** Comprehensive documentation reduces support burden and enables self-service troubleshooting. Separate files for different concerns improve maintainability and allow targeted updates. The complete dependency mapping table is critical for reproducible builds and must be verified before implementation begins.

### 6. Dependency Mapping Layer

**Purpose:** Translate Debian package names to RHEL equivalents.

**Key Mappings:**
- `adduser` → `shadow-utils`
- `iproute2` → `iproute`
- `libcap2-bin` → `libcap`
- `dnsmasq-base` → `dnsmasq`
- `ebtables` → `ebtables-legacy` (for broute operations)
- Development packages: `-dev` → `-devel` (systematic pattern)

**Systematic Suffix Mapping:**
All Debian development packages follow the pattern `-dev` → `-devel`:
- `libfmt-dev` → `fmt-devel`
- `libgflags-dev` → `gflags-devel`
- `libjsoncpp-dev` → `jsoncpp-devel`
- `libprotobuf-dev` → `protobuf-devel`
- `libssl-dev` → `openssl-devel`

**Architecture-Specific:**
- `grub-efi-arm64-bin` → `grub2-efi-aa64` (aarch64)
- `grub-efi-ia32-bin` → `grub2-efi-ia32` (x86_64)
- `qemu-user-static` → `qemu-user-static` (aarch64 cross-compilation)

**Nginx Configuration:**

RHEL uses different nginx configuration paths than Debian:
- **Debian:** `/etc/nginx/sites-available/`, `/etc/nginx/sites-enabled/` (symlink pattern)
- **RHEL:** `/etc/nginx/conf.d/` (direct inclusion, no sites-available/enabled)

**Nginx Configuration Installation:**
```spec
# Install nginx configuration for orchestration
install -D -m 0644 nginx-orchestration.conf \
    %{buildroot}/etc/nginx/conf.d/cuttlefish-orchestration.conf
```

**Design Rationale:** RHEL's nginx packaging doesn't use the sites-available/sites-enabled pattern. All configuration files in `/etc/nginx/conf.d/` are automatically included. The systematic `-dev` → `-devel` suffix mapping simplifies dependency translation.

### 7. RPM Package Naming and Versioning Conventions

**Purpose:** Establish consistent naming and versioning for RPM packages across architectures and releases.

**Package Naming Format:**
```
{name}-{version}-{release}.{dist}.{arch}.rpm
```

**Example:**
```
cuttlefish-base-1.0.0-1.el10.x86_64.rpm
cuttlefish-common-1.0.0-1.el10.noarch.rpm
```

**Spec File Header:**
```spec
Name:           cuttlefish-base
Version:        %{version}
Release:        1%{?dist}
Summary:        Android Cuttlefish Virtual Device - Base Package
License:        Apache-2.0
URL:            https://github.com/google/android-cuttlefish
Source0:        %{name}-%{version}.tar.gz
```

**Version Components:**
- **Version**: Semantic versioning (e.g., 1.0.0) extracted from debian/changelog
- **Release**: Package release number, starts at 1, increments for packaging changes
- **%{?dist}**: Distribution tag (e.g., .el10 for RHEL 10, .el9 for RHEL 9)
- **Architecture**: x86_64, aarch64, or noarch

**Architecture Handling:**
```spec
# Architecture-specific packages
BuildArch: x86_64
# or
BuildArch: aarch64

# Architecture-independent packages
BuildArch: noarch
```

**Epoch Handling:**

Epochs are used when version numbering schemes change:
```spec
# Only add if version numbering changes incompatibly
Epoch: 1
```

**Pre-release Versions:**

For development builds:
```spec
Version:        1.0.0
Release:        0.1.alpha1%{?dist}
```

For release candidates:
```spec
Version:        1.0.0
Release:        0.1.rc1%{?dist}
```

**Design Rationale:** Consistent naming enables proper dependency resolution and upgrade paths. The %{?dist} macro ensures packages are tagged for specific RHEL versions. Release numbering allows packaging fixes without version changes.

### 8. Mock Build Environment

**Purpose:** Provide clean-room build environment for reproducible RPM builds and testing.

**Mock Overview:**

Mock creates isolated chroot environments for building RPMs, ensuring:
- Clean build environment (no host contamination)
- Reproducible builds across systems
- Testing on different RHEL versions
- Dependency verification

**Mock Configuration:**

Create `/etc/mock/rhel-10-x86_64.cfg`:
```python
config_opts['root'] = 'rhel-10-x86_64'
config_opts['target_arch'] = 'x86_64'
config_opts['legal_host_arches'] = ('x86_64',)
config_opts['chroot_setup_cmd'] = 'install bash coreutils'
config_opts['dist'] = 'el10'

config_opts['yum.conf'] = """
[main]
keepcache=1
debuglevel=2
reposdir=/dev/null
logfile=/var/log/yum.log
retries=20
obsoletes=1
gpgcheck=0
assumeyes=1

[rhel-10-baseos]
name=RHEL 10 BaseOS
baseurl=http://mirror.example.com/rhel/10/BaseOS/x86_64/os/
enabled=1

[rhel-10-appstream]
name=RHEL 10 AppStream
baseurl=http://mirror.example.com/rhel/10/AppStream/x86_64/os/
enabled=1

[epel-10]
name=EPEL 10
baseurl=http://download.fedoraproject.org/pub/epel/10/Everything/x86_64/
enabled=1

[crb]
name=CodeReady Builder
baseurl=http://mirror.example.com/rhel/10/CRB/x86_64/os/
enabled=1
"""
```

**Building with Mock:**

```bash
# Initialize mock environment
mock -r rhel-10-x86_64 --init

# Install build dependencies
mock -r rhel-10-x86_64 --installdeps cuttlefish-base.spec

# Build source RPM
mock -r rhel-10-x86_64 --buildsrpm --spec cuttlefish-base.spec --sources ~/rpmbuild/SOURCES/

# Build binary RPM from SRPM
mock -r rhel-10-x86_64 --rebuild cuttlefish-base-1.0.0-1.el10.src.rpm

# Results in /var/lib/mock/rhel-10-x86_64/result/
```

**Mock for Testing:**

```bash
# Install built package in mock environment
mock -r rhel-10-x86_64 --install /var/lib/mock/rhel-10-x86_64/result/cuttlefish-base-*.rpm

# Run commands in mock environment
mock -r rhel-10-x86_64 --shell "systemctl status cuttlefish-host-resources"

# Clean mock environment
mock -r rhel-10-x86_64 --clean
```

**CI Integration:**

```yaml
# .github/workflows/rhel-build.yml
- name: Build with Mock
  run: |
    sudo dnf install -y mock
    sudo usermod -a -G mock $USER
    mock -r rhel-10-x86_64 --rebuild *.src.rpm
```

**Design Rationale:** Mock is the standard tool for RHEL package development. It ensures builds are reproducible and don't depend on the host system state. Mock is required for submitting packages to official RHEL repositories and is best practice for community packages.

## Data Models

### Package Metadata Model

```
Package:
  - name: string
  - version: string (semantic versioning)
  - release: integer
  - architecture: enum(any, amd64, arm64, noarch)
  - dependencies:
      - build: list<PackageDependency>
      - runtime: list<PackageDependency>
  - files: list<FileInstallation>
  - services: list<SystemdService>
  - users: list<SystemUser>
  - groups: list<SystemGroup>
```

### Service Configuration Model

```
ServiceConfig:
  - name: string
  - type: enum(oneshot, simple, forking)
  - user: string
  - group: string
  - environment_file: path
  - exec_start: command
  - exec_stop: command (optional)
  - restart: enum(no, on-failure, always)
  - restart_sec: integer (seconds)
  - dependencies:
      - after: list<string>
      - requires: list<string>
      - wants: list<string>
```

### Build Configuration Model

```
BuildConfig:
  - os_type: enum(debian, rhel10)
  - bazel_flags: list<string>
  - go_flags: list<string>
  - compiler_flags: list<string>
  - linker_flags: list<string>
  - output_format: enum(deb, rpm)
  - repositories:
      - enabled: list<string>
      - required: list<string>
```

### Documentation Model

```
DocumentationSet:
  - install_guide:
      - prerequisites: list<Requirement>
      - repository_setup: list<Command>
      - installation_steps: list<Step>
      - verification: list<Check>
  - repository_guide:
      - epel: RepositoryConfig
      - crb: RepositoryConfig
      - copr: RepositoryConfig
  - dependency_mappings:
      - mappings: map<DebianPackage, RHELPackage>
      - architecture_specific: map<Architecture, map<DebianPackage, RHELPackage>>
  - troubleshooting:
      - issues: list<Issue>
      - solutions: list<Solution>
  - development_guide:
      - setup: list<Step>
      - build_instructions: list<Command>
      - testing: list<Procedure>

RepositoryConfig:
  - name: string
  - purpose: string
  - setup_commands: list<Command>
  - verification: Command

DependencyMapping:
  - debian_package: string
  - rhel_package: string
  - notes: string (optional)
  - architecture: enum(any, x86_64, aarch64)
```

### CI/CD Configuration Model

```
CIConfig:
  - build_jobs:
      - debian_build: BuildJob
      - rhel_build: BuildJob
  - test_jobs:
      - rhel_tests: list<TestJob>
      - compatibility_tests: list<TestJob>
  - matrix:
      - distributions: list<string>
      - architectures: list<string>
  - reporting:
      - pass_rate_threshold: float
      - regression_detection: boolean

BuildJob:
  - name: string
  - os: string
  - steps: list<Step>
  - artifacts: list<Artifact>

TestJob:
  - name: string
  - depends_on: list<string>
  - test_type: enum(unit, integration, property, system)
  - steps: list<Step>
  - pass_criteria: Criteria
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Package installation creates required system group
*For any* installation of cuttlefish-base package, the cvdnetwork system group should exist after installation completes
**Validates: Requirements 1.2**

### Property 2: Package installation places binaries in correct location
*For any* installation of cuttlefish-base package, all required binaries should exist in /usr/lib/cuttlefish-common/bin/
**Validates: Requirements 1.3**

### Property 3: Package installation creates cvd symlink
*For any* installation of cuttlefish-base package, a symlink should exist from /usr/bin/cvd to /usr/lib/cuttlefish-common/bin/cvd
**Validates: Requirements 1.4**

### Property 4: Package installation enables systemd service
*For any* installation of cuttlefish-base package, the cuttlefish-host-resources.service should be enabled in systemd
**Validates: Requirements 1.5**

### Property 5: Build process uses RPM-compliant compiler flags
*For any* build execution, the Bazel build should include RPM optflags and ldflags from the environment
**Validates: Requirements 2.3**

### Property 6: Build process produces RHEL-compliant Go executables
*For any* build execution, Go binaries should be built with RHEL-required flags: -buildmode=pie, -trimpath, and appropriate LDFLAGS for hardening
**Validates: Requirements 2.7**

### Property 7: Build process produces exactly six packages
*For any* successful build, the output should contain exactly 6 RPM packages: cuttlefish-base, cuttlefish-common, cuttlefish-integration, cuttlefish-defaults, cuttlefish-user, and cuttlefish-orchestration
**Validates: Requirements 2.5**

### Property 8: Service startup creates network bridges
*For any* start of cuttlefish-host-resources service, network bridges cvd-ebr and cvd-wbr should exist after startup
**Validates: Requirements 3.1**

### Property 9: Service startup creates correct number of tap interfaces
*For any* start of cuttlefish-host-resources service with num_cvd_accounts=N, exactly 4*N tap interfaces should be created (etap, wtap, mtap, wifiap for each account)
**Validates: Requirements 3.2**

### Property 10: Service startup launches dnsmasq processes
*For any* start of cuttlefish-host-resources service, two dnsmasq processes should be running (one for cvd-ebr, one for cvd-wbr)
**Validates: Requirements 3.3**

### Property 11: Service startup configures NAT rules
*For any* start of cuttlefish-host-resources service, masquerading should be enabled for Cuttlefish networks (192.168.96.0/24 and 192.168.98.0/24) either via firewalld or iptables depending on which is active
**Validates: Requirements 3.5, 3.6, 3.7**

### Property 12: Operator service generates certificates when missing
*For any* start of cuttlefish-operator service, if TLS certificates do not exist, they should be generated before the service starts
**Validates: Requirements 3.5**

### Property 13: Failed services restart automatically
*For any* Cuttlefish service that fails, systemd should restart the service within 5 seconds
**Validates: Requirements 3.6**

### Property 14: Spec files contain all required sections
*For any* RPM spec file created, it should contain all required sections: Name, Version, Release, Summary, License, URL, Source, BuildRequires, Requires, %description, %prep, %build, %install, %files, and %changelog
**Validates: Requirements 4.1**

### Property 15: Dependencies map correctly to RHEL equivalents
*For any* Debian dependency in the original control file, the RPM spec file should contain the correct RHEL equivalent package name
**Validates: Requirements 4.2**

### Property 16: Spec files use appropriate RPM macros
*For any* systemd unit file installation, the spec file should use %{_unitdir} macro; for any config file, should use %config macro
**Validates: Requirements 4.3**

### Property 17: Built packages have correct file permissions
*For any* file in a built RPM package, the file should have appropriate permissions (executables: 755, configs: 644, secrets: 600)
**Validates: Requirements 4.4**

### Property 18: Packages with services use systemd macros
*For any* RPM package containing systemd services, the spec file should use %systemd_post, %systemd_preun, and %systemd_postun macros
**Validates: Requirements 4.5**

### Property 19: Service configs install to /etc/sysconfig
*For any* service configuration file, it should be installed to /etc/sysconfig/ not /etc/default/
**Validates: Requirements 5.1**

### Property 20: Systemd units install to correct location
*For any* systemd unit file, it should be installed to /usr/lib/systemd/system/
**Validates: Requirements 5.2**

### Property 21: Udev rules install to correct location
*For any* udev rule file, it should be installed to /usr/lib/udev/rules.d/
**Validates: Requirements 5.3**

### Property 22: Kernel module configs install to correct locations
*For any* kernel module configuration, modules-load.d files should be in /etc/modules-load.d/ and modprobe.d files should be in /etc/modprobe.d/
**Validates: Requirements 5.4**

### Property 23: Config files preserve user modifications
*For any* configuration file marked with %config(noreplace), after package upgrade with user modifications, the original modified file should be preserved and new version saved as .rpmnew
**Validates: Requirements 5.5**

### Property 24: CI builds produce all packages
*For any* CI build execution, the build should produce all 6 RPM packages
**Validates: Requirements 7.2**

### Property 25: System group created with correct flags
*For any* installation of cuttlefish-base, the cvdnetwork group should be a system group (GID < 1000)
**Validates: Requirements 8.1**

### Property 26: Operator user created with nologin shell
*For any* installation of cuttlefish-user, the _cutf-operator user should have /sbin/nologin as their shell
**Validates: Requirements 8.2**

### Property 27: Orchestration user exists after installation
*For any* installation of cuttlefish-orchestration, the httpcvd user should exist
**Validates: Requirements 8.3**

### Property 28: Service users added to cvdnetwork group
*For any* service user creation (_cutf-operator, httpcvd), the user should be a member of the cvdnetwork group
**Validates: Requirements 8.4**

### Property 29: Package removal preserves users and groups
*For any* package removal, system users and groups created during installation should still exist after removal
**Validates: Requirements 8.5**

### Property 30: Debian directories remain unchanged
*For any* modification to add RHEL support, the debian/ directories should have identical content before and after
**Validates: Requirements 9.1**

### Property 31: RHEL directories exist for all packages
*For any* package with Debian support, a corresponding rhel/ directory should exist containing RPM spec files
**Validates: Requirements 9.2**

### Property 32: Build scripts detect OS correctly
*For any* execution of build scripts on Debian or RHEL systems, the script should detect the OS type and use the appropriate packaging format
**Validates: Requirements 9.3**

### Property 33: Version numbers stay synchronized
*For any* version update, both Debian and RHEL packages should have the same version number
**Validates: Requirements 9.4**

### Property 34: File installation paths are consistent
*For any* file installation (except /etc/default vs /etc/sysconfig), both Debian and RHEL packages should install files to the same absolute path
**Validates: Requirements 9.5**

### Property 35: Systemd daemon reloads after service file update
*For any* package upgrade that updates systemd unit files, systemd daemon-reload should be executed
**Validates: Requirements 10.2**

### Property 36: Running services restart during upgrade
*For any* package upgrade while the service is running, the service should be restarted with the new binary
**Validates: Requirements 10.3**

### Property 37: Group memberships preserved during upgrade
*For any* package upgrade, user group memberships should remain unchanged
**Validates: Requirements 10.4**

### Property 38: Network configuration preserved during upgrade
*For any* package upgrade while network bridges and tap interfaces are configured, the network configuration should remain functional after upgrade
**Validates: Requirements 10.5**

### Property 39: Documentation includes all required sections
*For any* documentation file created, it should contain all sections specified in the requirements (installation, repositories, dependencies, troubleshooting, or development as appropriate)
**Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5**

### Property 40: Documentation dependency mappings are complete
*For any* Debian package dependency in the control files, the documentation should include the corresponding RHEL package mapping
**Validates: Requirements 6.3**

### Property 41: CI builds both package formats
*For any* CI build execution, both Debian and RHEL packages should be built successfully
**Validates: Requirements 7.1, 7.2**

### Property 42: CI verifies package installation
*For any* CI test execution on RHEL, all 6 packages should install successfully on a clean system
**Validates: Requirements 7.3**

### Property 43: CI verifies service functionality
*For any* CI test execution, all Cuttlefish services should start successfully and network configuration should be correct
**Validates: Requirements 7.4**

### Property 44: CI verifies device boot
*For any* CI test execution, at least one Cuttlefish device should boot successfully and be accessible
**Validates: Requirements 7.5**

### Property 45: Existing tests maintain pass rate
*For any* test suite execution after RHEL changes, the pass rate on Debian systems should be equal to or greater than the baseline pass rate before RHEL changes
**Validates: Requirements 11.2**

### Property 46: Debian packages remain unchanged
*For any* Debian package built after RHEL implementation, the package contents should be identical to packages built before RHEL implementation (same version)
**Validates: Requirements 11.4**

### Property 47: Debian functionality preserved
*For any* Cuttlefish operation on Debian systems after RHEL implementation, the operation should succeed with the same behavior as before RHEL implementation
**Validates: Requirements 11.5**

## Error Handling

### Build Errors

**Missing Dependencies:**
- Detection: Check for required packages before build
- Handling: Install dependencies automatically via install_rhel*_deps.sh
- Recovery: Provide clear error messages with repository setup instructions

**Bazel Build Failures:**
- Detection: Monitor bazel exit codes
- Handling: Capture and display bazel error output
- Recovery: Provide troubleshooting guide for common bazel issues

**RPM Build Failures:**
- Detection: Monitor rpmbuild exit codes
- Handling: Preserve build logs in ~/rpmbuild/BUILD/
- Recovery: Validate spec file syntax, check file permissions

### Installation Errors

**Dependency Resolution Failures:**
- Detection: dnf/yum reports unresolved dependencies
- Handling: Check for enabled repositories (EPEL, CRB/PowerTools, Copr)
- Recovery: Provide repository setup commands in error message

**User/Group Creation Failures:**
- Detection: Check exit codes from useradd/groupadd
- Handling: Check if user/group already exists
- Recovery: Continue installation if user/group exists with correct attributes

**Service Startup Failures:**
- Detection: systemctl status shows failed state
- Handling: Check journalctl for error messages
- Recovery: Validate network configuration, check for port conflicts

### Runtime Errors

**Network Bridge Creation Failures:**
- Detection: ip link show returns error for bridge
- Handling: Check for kernel module availability (bridge)
- Recovery: Load bridge module, check for conflicting network configuration

**Permission Errors:**
- Detection: Access denied errors in service logs
- Handling: Verify user group memberships
- Recovery: Add users to required groups, restart services

**Certificate Generation Failures:**
- Detection: openssl command fails
- Handling: Check for openssl availability and /etc/cuttlefish-operator/ssl/ directory
- Recovery: Create directory with correct permissions, retry generation

### Documentation Errors

**Missing Documentation Sections:**
- Detection: Automated documentation validation script
- Handling: Report missing sections in CI
- Recovery: Add missing sections before merge

**Outdated Dependency Mappings:**
- Detection: Compare control files with documentation
- Handling: Generate diff of missing mappings
- Recovery: Update documentation with current mappings

**Broken Documentation Links:**
- Detection: Link checker in CI pipeline
- Handling: Report broken links with line numbers
- Recovery: Fix or remove broken links

### CI/CD Errors

**Build Failures in CI:**
- Detection: Non-zero exit code from build script
- Handling: Capture full build logs
- Recovery: Provide logs to developer, suggest common fixes

**Test Failures in CI:**
- Detection: Test suite reports failures
- Handling: Categorize failures (RHEL-specific, Debian regression, flaky)
- Recovery: Provide failure details, suggest investigation steps

**Backward Compatibility Violations:**
- Detection: Package comparison shows differences
- Handling: Block merge, report specific differences
- Recovery: Revert changes affecting Debian packages

**Version Synchronization Failures:**
- Detection: Version mismatch between Debian and RHEL
- Handling: Block release, alert maintainers
- Recovery: Update version in both packaging systems

## Testing Strategy

### Unit Testing

**Spec File Validation:**
- Test: Parse spec files with rpmlint
- Verify: No errors or warnings
- Coverage: All 6 spec files

**Dependency Mapping:**
- Test: Compare Debian control files with RPM spec files
- Verify: All dependencies have RHEL equivalents
- Coverage: All packages in all control files

**Script Syntax:**
- Test: Run shellcheck on all .sh scripts
- Verify: No syntax errors or warnings
- Coverage: All wrapper scripts

### Property-Based Testing

**Property Testing Framework:** We will use `bats` (Bash Automated Testing System) for shell script testing and `pytest` with `hypothesis` for Python-based property tests.

**Test Configuration:** Each property-based test will run a minimum of 100 iterations to ensure comprehensive coverage of the input space.

**Property Test Implementation:**

Each correctness property will be implemented as a property-based test tagged with the format:
`**Feature: rhel-migration, Property N: [property description]**`

**Key Property Tests:**

1. **Package Installation Properties (1-4):**
   - Generate: Random installation scenarios (clean system, upgrade, reinstall)
   - Test: Verify group creation, file installation, symlinks, service enablement
   - Validate: System state matches expected configuration

2. **Build Properties (5-7):**
   - Generate: Random build configurations (different flag combinations)
   - Test: Verify compiler flags, PIE executables, package count
   - Validate: Build artifacts meet requirements

3. **Service Properties (8-13):**
   - Generate: Random service configurations (different num_cvd_accounts values)
   - Test: Verify network setup, process creation, restart behavior
   - Validate: System state after service operations

4. **Packaging Properties (14-23):**
   - Generate: Random spec file variations
   - Test: Verify spec file structure, macro usage, file permissions
   - Validate: Built packages meet RPM standards

5. **Upgrade Properties (35-38):**
   - Generate: Random upgrade scenarios (different starting states)
   - Test: Verify configuration preservation, service continuity
   - Validate: System remains functional after upgrade

6. **Documentation Properties (39-40):**
   - Generate: Random documentation file selections
   - Test: Verify required sections present, dependency mappings complete
   - Validate: Documentation meets completeness requirements

7. **CI/CD Properties (41-44):**
   - Generate: Random CI configurations and test scenarios
   - Test: Verify both package formats build, installation succeeds, services work
   - Validate: CI pipeline catches issues before release

8. **Backward Compatibility Properties (45-47):**
   - Generate: Random Debian operations and package comparisons
   - Test: Verify Debian packages unchanged, tests pass, functionality preserved
   - Validate: RHEL changes don't affect Debian systems

### Integration Testing

**End-to-End Installation Test:**
1. Start with clean RHEL 10 system
2. Install all packages
3. Verify all services start
4. Boot a Cuttlefish device
5. Verify device connectivity

**Upgrade Test:**
1. Install version N
2. Configure and start services
3. Upgrade to version N+1
4. Verify services still running
5. Verify configuration preserved

**Multi-Device Test:**
1. Install packages
2. Configure for 10 CVD accounts
3. Start services
4. Verify 40 tap interfaces created
5. Boot multiple devices simultaneously

### System Testing

**RHEL 10 Testing:**
- Test on RHEL 10
- Test on Rocky Linux 10
- Test on AlmaLinux 10

**Architecture Testing:**
- Test on x86_64
- Test on aarch64

### Backward Compatibility Testing

**Debian Package Comparison:**
1. Build Debian packages from pre-RHEL commit
2. Build Debian packages from post-RHEL commit
3. Extract and compare package contents
4. Verify file lists are identical
5. Verify file checksums match
6. Report any differences

**Debian Functionality Testing:**
1. Install Debian packages on Ubuntu 22.04
2. Run existing test suite
3. Compare pass rate with baseline
4. Identify any new failures
5. Verify failures are not RHEL-related

**Regression Detection:**
1. Monitor test pass rates over time
2. Alert on any decrease in Debian pass rate
3. Bisect to identify problematic commits
4. Verify RHEL changes don't affect Debian code paths

**Version Synchronization Testing:**
1. Extract version from debian/changelog
2. Extract version from rhel/*.spec
3. Verify versions match
4. Alert on version drift

### Continuous Integration

**CI/CD Architecture:**

The CI/CD system will support parallel Debian and RHEL builds with comprehensive testing to ensure both packaging formats remain functional.

**Build Pipeline:**
1. **Trigger:** Pull request or commit to main branch
2. **Parallel Builds:**
   - Debian build job (existing)
   - RHEL 10 build job (new)
3. **Package Validation:**
   - Run `lintian` on .deb packages
   - Run `rpmlint` on .rpm packages
4. **Artifact Storage:**
   - Archive all packages
   - Generate build metadata
   - Create checksums

**Test Pipeline:**

**RHEL Test Jobs:**
1. **Clean Installation Test:**
   - Deploy fresh RHEL 10 VM
   - Install all 6 packages
   - Verify services start
   - Check network configuration
   - Boot single Cuttlefish device
   - Verify device connectivity

2. **Multi-Device Test:**
   - Configure for 10 CVD accounts
   - Verify 40 tap interfaces created
   - Boot multiple devices
   - Test device isolation

3. **Upgrade Test:**
   - Install previous version
   - Configure and start services
   - Upgrade to new version
   - Verify services continue running
   - Verify configuration preserved

4. **Property-Based Tests:**
   - Run all property tests (100 iterations each)
   - Verify package installation properties
   - Verify build properties
   - Verify service properties

**Backward Compatibility Test Jobs:**
1. **Debian Regression Test:**
   - Build Debian packages
   - Compare with pre-RHEL baseline
   - Verify identical package contents
   - Run existing Debian test suite
   - Verify same pass rate

2. **Cross-Platform Consistency:**
   - Compare file installations (Debian vs RHEL)
   - Verify version synchronization
   - Check for unintended Debian changes

**Matrix Testing:**
- **Distributions:** RHEL 10, Rocky Linux 10, AlmaLinux 10
- **Architectures:** x86_64, aarch64
- **Scenarios:** Clean install, upgrade, multi-device

**Test Reporting:**
- Generate test reports for each job
- Track pass/fail rates over time
- Identify RHEL-specific vs. general failures
- Create regression alerts

**Release Pipeline:**
1. Tag release version
2. Build signed packages (both .deb and .rpm)
3. Upload to repositories
4. Update documentation
5. Run smoke tests on published packages
6. Announce release

**CI Configuration Files:**
- `.github/workflows/rhel-build.yml` - RHEL build workflow
- `.github/workflows/rhel-test.yml` - RHEL test workflow
- `.github/workflows/compatibility.yml` - Backward compatibility checks
- `.kokoro/rhel-presubmit.cfg` - Kokoro RHEL presubmit configuration

**Design Rationale:** Comprehensive CI/CD ensures quality for both packaging formats. Parallel builds catch integration issues early. Backward compatibility testing prevents regressions in existing Debian deployments. Matrix testing across distributions and architectures ensures broad compatibility.
