# Implementation Plan

- [x] 0. Establish version management strategy
  - [x] 0.1 Create portable version extraction function
    - Create tools/buildutils/get_version.sh
    - Use portable sed/awk to extract version from debian/changelog
    - Test on both Debian and RHEL systems
    - _Requirements: 9.4_

  - [x] 0.2 Verify version extraction works
    - Test extraction from base/debian/changelog
    - Test extraction from frontend/debian/changelog
    - Verify format matches expected pattern (X.Y.Z)
    - _Requirements: 9.4_

- [x] 1. Create RHEL directory structure and initial spec files
  - [x] 1.1 Create base/rhel/ directory structure
    - Create `base/rhel/` directory
    - Create `base/rhel/selinux/` subdirectory for SELinux policies
    - _Requirements: 9.2_

  - [x] 1.2 Create frontend/rhel/ directory structure
    - Create `frontend/rhel/` directory
    - Create `frontend/rhel/selinux/` subdirectory for SELinux policies
    - _Requirements: 9.2_

  - [x] 1.3 Create skeleton cuttlefish-base.spec
    - Add Name, Version, Release, Summary, License, URL metadata
    - Use portable version extraction: `VERSION=$(head -n1 base/debian/changelog | sed 's/.*(\([^)]*\)).*/\1/' | cut -d- -f1)`
    - Add empty %description, %prep, %build, %install, %files sections
    - _Requirements: 4.1_

  - [x] 1.4 Create skeleton cuttlefish-integration.spec
    - Add basic metadata sections
    - _Requirements: 4.1_

  - [x] 1.5 Create skeleton cuttlefish-defaults.spec
    - Add basic metadata sections
    - _Requirements: 4.1_

  - [x] 1.6 Create skeleton cuttlefish-common.spec (meta-package)
    - Add basic metadata sections
    - _Requirements: 4.1_

  - [x] 1.7 Create skeleton cuttlefish-user.spec
    - Add basic metadata sections
    - Extract version from frontend/debian/changelog
    - _Requirements: 4.1_

  - [x] 1.8 Create skeleton cuttlefish-orchestration.spec
    - Add basic metadata sections
    - _Requirements: 4.1_

- [x] 2. Implement dependency mapping for all packages
  - [x] 2.1 Map cuttlefish-base dependencies
    - Analyze base/debian/control for BuildRequires and Requires
    - Map Debian package names to RHEL equivalents (adduser→shadow-utils, iproute2→iproute, etc.)
    - Apply systematic -dev → -devel suffix mapping (libfmt-dev→fmt-devel, libgflags-dev→gflags-devel, etc.)
    - Handle architecture-specific dependencies (grub-efi-arm64-bin→grub2-efi-aa64, grub-efi-ia32-bin→grub2-efi-ia32)
    - Add ebtables-legacy for broute operations
    - Add BuildRequires and Requires sections to cuttlefish-base.spec
    - _Requirements: 4.2, 6.3_

  - [x] 2.2 Map cuttlefish-integration dependencies
    - Map qemu packages and other dependencies
    - Add to cuttlefish-integration.spec
    - _Requirements: 4.2_

  - [x] 2.3 Map cuttlefish-user dependencies
    - Analyze frontend/debian/control for cuttlefish-user
    - Map dependencies to RHEL equivalents
    - Add to cuttlefish-user.spec
    - _Requirements: 4.2_

  - [x] 2.4 Map cuttlefish-orchestration dependencies
    - Map nginx, systemd-journal-remote, and other dependencies
    - Add to cuttlefish-orchestration.spec
    - _Requirements: 4.2_

  - [x] 2.5 Create dependency mapping documentation
    - Create docs/rhel/DEPENDENCIES.md
    - Document all Debian → RHEL package mappings in table format
    - Include architecture-specific mappings
    - Note optional vs required dependencies
    - Document systematic -dev → -devel suffix pattern
    - _Requirements: 6.3_

  - [x] 2.6 Verify dependency mapping completeness
    - [x] 2.6.1 Create script to extract all Debian dependencies
      - Parse base/debian/control and frontend/debian/control
      - Extract all BuildRequires and Requires
      - Output list of Debian packages
    - [x] 2.6.2 Cross-reference with RHEL dependency mappings
      - Compare extracted Debian packages with DEPENDENCIES.md
      - Identify any unmapped dependencies
    - [x] 2.6.3 Verify all packages exist in RHEL/EPEL/CRB repos
      - Test `dnf info` for each RHEL package
      - Report packages not found in repositories
    - [x] 2.6.4 Report any unmapped dependencies
      - Generate report of missing mappings
      - Exit with error if unmapped dependencies found
      - _Requirements: 4.2, 6.3_

- [x] 3. Convert LSB init scripts to systemd units
  - [x] 3.1 Create cuttlefish-host-resources systemd unit
    - Create base/rhel/cuttlefish-host-resources.service
    - Set Type=oneshot
    - Set EnvironmentFile=/etc/sysconfig/cuttlefish-host-resources
    - Set ExecStart=/usr/lib/cuttlefish-common/bin/setup-host-resources.sh
    - Add After=network.target
    - Add RemainAfterExit=yes
    - Add security hardening:
      - PrivateTmp=yes
      - ProtectSystem=false (needs to modify network config)
      - ProtectHome=yes
      - ProtectKernelModules=no (needs to load modules)
      - CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_SYS_MODULE CAP_SYS_ADMIN
      - RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK AF_PACKET
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 5.2_
  
  - [x] 3.2 Create setup-host-resources.sh wrapper script (complex - 371 lines in original)
    - [x] 3.2.1 Extract and adapt network bridge creation functions
      - Create base/rhel/setup-host-resources.sh
      - Source /etc/sysconfig/cuttlefish-host-resources for configuration
      - Extract create_bridge() function from init script
      - Create cvd-ebr bridge (192.168.96.1/24)
      - Create cvd-wbr bridge (192.168.98.1/24)
      - Handle IPv6 configuration if enabled
      - _Requirements: 3.1_
    
    - [x] 3.2.2 Extract and adapt tap interface creation functions
      - Extract create_tap_interface() function
      - Create exactly 4 tap interfaces per CVD account:
        - cvd-etap-XX (bridged to cvd-ebr)
        - cvd-mtap-XX (standalone with NAT, subnet varies by account range)
        - cvd-wtap-XX (bridged to cvd-wbr)
        - cvd-wifiap-XX (standalone with NAT, subnet varies by account range)
      - Handle subnet allocation for accounts 1-64 vs 65-128
      - _Requirements: 3.2, 3.4_

    - [x] 3.2.3 Implement firewalld vs iptables detection
      - Add firewalld detection: `systemctl is-active --quiet firewalld`
      - Get default zone: `firewall-cmd --get-default-zone`
      - Set use_firewalld flag based on detection
      - _Requirements: 3.5, 3.6, 3.7_

    - [x] 3.2.4 Implement NAT configuration for both firewall types
      - If firewalld active:
        - Use `firewall-cmd --add-masquerade --zone=${default_zone} --permanent`
        - Open operator ports (HTTP/HTTPS)
        - Open orchestrator port
        - Reload firewalld
      - If firewalld inactive:
        - Use `iptables -t nat -A POSTROUTING -s 192.168.96.0/24 -j MASQUERADE`
        - Use `iptables -t nat -A POSTROUTING -s 192.168.98.0/24 -j MASQUERADE`
        - Save iptables rules
      - _Requirements: 3.5, 3.6, 3.7_

    - [x] 3.2.5 Add dnsmasq startup logic
      - Start dnsmasq for cvd-ebr bridge
      - Start dnsmasq for cvd-wbr bridge
      - Configure DHCP ranges for each bridge
      - _Requirements: 3.3_

    - [x] 3.2.6 Add kernel module loading
      - Load bridge module
      - Load vhost-net module
      - Load vhost-vsock module
      - Check if modules loaded successfully
      - _Requirements: 3.4_

    - [x] 3.2.7 Add Docker environment handling
      - Detect if running in Docker container
      - Adjust device permissions if in Docker
      - Handle Nvidia module loading if present
      - _Requirements: 3.1, 3.2_

    - [x] 3.2.8 Add ebtables configuration for non-bridged mode
      - Check if bridge_interface is configured
      - If configured, use ebtables-legacy for broute operations
      - Configure ebtables rules for traffic routing
      - _Requirements: 3.8_

    - [x] 3.2.9 Test script with multiple num_cvd_accounts values
      - Test with num_cvd_accounts=1
      - Test with num_cvd_accounts=10
      - Test with num_cvd_accounts=64
      - Test with num_cvd_accounts=128
      - Verify correct number of tap interfaces created
      - _Requirements: 3.2_
  
  - [x] 3.3 Create cuttlefish-host-resources configuration file
    - Create base/rhel/cuttlefish-host-resources.default
    - Copy configuration variables from base/debian/cuttlefish-base.cuttlefish-host-resources.default
    - Set num_cvd_accounts=10 as default
    - Document all configuration options
    - _Requirements: 5.1_

  - [x] 3.4 Create cuttlefish-operator systemd unit
    - Create frontend/rhel/cuttlefish-operator.service
    - Set Type=simple
    - Set User=_cutf-operator, Group=cvdnetwork
    - Set ExecStartPre=/usr/lib/cuttlefish-common/bin/generate-operator-certs.sh
    - Set ExecStart=/usr/lib/cuttlefish-common/bin/operator with arguments
    - Add Restart=on-failure, RestartSec=5
    - Add After=network.target
    - Add security hardening:
      - PrivateTmp=yes
      - ProtectSystem=strict
      - ProtectHome=yes
      - ReadWritePaths=/run/cuttlefish /etc/cuttlefish-common/operator/cert
      - ProtectKernelModules=yes
      - CapabilityBoundingSet=CAP_NET_BIND_SERVICE
      - RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
    - _Requirements: 3.9, 3.10, 5.2_
  
  - [x] 3.5 Create generate-operator-certs.sh script
    - Create frontend/rhel/generate-operator-certs.sh
    - Check if certificates exist in /etc/cuttlefish-common/operator/cert/
    - Generate self-signed certificates using openssl if missing
    - Set proper permissions (600 for private key)
    - Set ownership to _cutf-operator:cvdnetwork
    - _Requirements: 3.5_

  - [x] 3.6 Create cuttlefish-operator configuration file
    - Create frontend/rhel/cuttlefish-operator.default
    - Copy configuration variables from frontend/debian/cuttlefish-user.cuttlefish-operator.default
    - Document all configuration options (http_port, https_port, tls_cert_dir, etc.)
    - _Requirements: 5.1_

  - [x] 3.7 Create cuttlefish-host_orchestrator systemd unit
    - Create frontend/rhel/cuttlefish-host_orchestrator.service
    - Set Type=simple
    - Set User=httpcvd, Group=cvdnetwork
    - Set ExecStart=/usr/lib/cuttlefish-common/bin/host_orchestrator with arguments
    - Add Restart=on-failure, RestartSec=5
    - Add After=network.target nginx.service
    - Add Wants=systemd-journal-gatewayd.service
    - Add security hardening:
      - PrivateTmp=yes
      - ProtectSystem=strict
      - ProtectHome=yes
      - ReadWritePaths=/var/lib/cuttlefish-common /run/cuttlefish
      - ProtectKernelModules=yes
      - CapabilityBoundingSet=CAP_NET_BIND_SERVICE
      - RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
    - _Requirements: 3.10, 5.2_
  
  - [x] 3.8 Create cuttlefish-host_orchestrator configuration file
    - Create frontend/rhel/cuttlefish-host_orchestrator.default
    - Copy configuration variables from frontend/debian/cuttlefish-orchestration.cuttlefish-host_orchestrator.default
    - Document all configuration options
    - _Requirements: 5.1_

- [x] 4. Complete cuttlefish-base RPM spec file
  - [x] 4.1 Add %description section
    - Copy description from base/debian/control
    - _Requirements: 4.1_

  - [x] 4.2 Add %prep section
    - Add %setup -q -n cuttlefish-base-%{version} for source extraction
    - Verify WORKSPACE file exists for Bazel builds
    - _Requirements: 4.1_

  - [x] 4.3 Add %build section
    - Set up Bazel build with RPM optflags
    - Build all C++ components using Bazel
    - Reference base/debian/rules for build commands
    - Export RPM_OPT_FLAGS and RPM_LD_FLAGS
    - _Requirements: 2.3, 4.1_

  - [x] 4.4 Add %install section
    - [x] 4.4.1 Detect build architecture using %{_arch}
      - Set bazel_output_path based on architecture
      - For x86_64: bazel-out/k8-opt/bin/
      - For aarch64: bazel-out/aarch64-opt/bin/
    - [x] 4.4.2 Create directory structure
      - Create %{buildroot}/usr/lib/cuttlefish-common/bin/
      - Create %{buildroot}%{_unitdir}/
      - Create %{buildroot}/etc/sysconfig/
      - Create %{buildroot}/usr/lib/udev/rules.d/
    - [x] 4.4.3 Copy binaries from architecture-specific Bazel output directory
      - Install binaries from ${bazel_output_path}
      - Reference base/debian/cuttlefish-base.install for file list
    - [x] 4.4.4 Install systemd unit file to %{buildroot}%{_unitdir}/
    - [x] 4.4.5 Install config file to %{buildroot}/etc/sysconfig/
    - [x] 4.4.6 Install udev rules to %{buildroot}/usr/lib/udev/rules.d/
      - Install base/debian/cuttlefish-base.udev as 99-cuttlefish-base.rules
    - [x] 4.4.7 Install wrapper script to %{buildroot}/usr/lib/cuttlefish-common/bin/
    - [x] 4.4.8 Create symlink from /usr/bin/cvd to /usr/lib/cuttlefish-common/bin/cvd
    - _Requirements: 4.1, 4.3, 5.2, 5.3_

  - [x] 4.5 Add %files section
    - List all installed files with appropriate macros
    - Use %{_unitdir} for systemd units
    - Use %config(noreplace) for /etc/sysconfig/ files
    - Use %attr for file permissions
    - Mark binaries as executable
    - _Requirements: 4.1, 4.3, 4.4, 5.5_

  - [x] 4.6 Add %pre section for group creation
    - Check if cvdnetwork group exists using getent
    - Create cvdnetwork group with groupadd -r (system group)
    - _Requirements: 1.2, 8.1_

  - [x] 4.7 Add %post section
    - Use %systemd_post cuttlefish-host-resources.service
    - Reload udev rules: `udevadm control --reload-rules || true`
    - Trigger udev: `udevadm trigger || true`
    - Set device permissions for KVM and vhost devices
    - Set capabilities on binaries using setcap (if needed)
    - Reference base/debian/cuttlefish-base.postinst
    - _Requirements: 1.5, 4.5, 5.3_

  - [x] 4.8 Add %preun section
    - Use %systemd_preun cuttlefish-host-resources.service
    - _Requirements: 4.5_

  - [x] 4.9 Add %postun section
    - Use %systemd_postun cuttlefish-host-resources.service
    - _Requirements: 4.5, 10.2_

  - [x] 4.10 Add %changelog section
    - Add initial entry with current date and version
    - _Requirements: 4.1_

- [x] 5. Complete cuttlefish-user RPM spec file
  - [x] 5.1 Add %description section
    - Copy description from frontend/debian/control
    - _Requirements: 4.1_

  - [x] 5.2 Add %prep and %build sections
    - Add %setup -q -n cuttlefish-frontend-%{version}
    - Build Go binaries with RHEL-compliant flags:
      - -buildmode=pie
      - -trimpath
      - -ldflags with hardening flags (-linkmode=external -extldflags=-Wl,-z,relro,-z,now)
    - Set CGO_ENABLED=1
    - Reference frontend/debian/rules for build commands
    - _Requirements: 2.7, 4.1_

  - [x] 5.3 Add %install section
    - Install operator binary to %{buildroot}/usr/lib/cuttlefish-common/bin/
    - Install systemd unit file to %{buildroot}%{_unitdir}/
    - Install config file to %{buildroot}/etc/sysconfig/
    - Install generate-operator-certs.sh to %{buildroot}/usr/lib/cuttlefish-common/bin/
    - Create /usr/share/cuttlefish-common/operator directory for assets
    - Reference frontend/debian/cuttlefish-user.install
    - _Requirements: 4.1, 4.3_

  - [x] 5.4 Add %files section
    - List all installed files with appropriate macros
    - Use %config(noreplace) for config files
    - _Requirements: 4.1, 4.3_

  - [x] 5.5 Add %pre section for user creation
    - Check if _cutf-operator user exists using getent
    - Create _cutf-operator user with useradd -r -s /sbin/nologin
    - Add user to cvdnetwork group
    - _Requirements: 8.2, 8.4_

  - [x] 5.6 Add %post, %preun, %postun sections
    - Use systemd macros for cuttlefish-operator.service
    - _Requirements: 4.5_

  - [x] 5.7 Add %changelog section
    - Add initial entry
    - _Requirements: 4.1_

- [x] 6. Complete cuttlefish-orchestration RPM spec file
  - [x] 6.1 Add %description section
    - Copy description from frontend/debian/control
    - _Requirements: 4.1_

  - [x] 6.2 Add %prep and %build sections
    - Add %setup -q -n cuttlefish-frontend-%{version}
    - Build host_orchestrator binary with RHEL-compliant flags:
      - -buildmode=pie
      - -trimpath
      - -ldflags with hardening flags
    - Set CGO_ENABLED=1
    - Reference frontend/debian/rules
    - _Requirements: 2.7, 4.1_

  - [x] 6.3 Add %install section
    - Install host_orchestrator binary
    - Install systemd unit file
    - Install config file to /etc/sysconfig/
    - Create /var/lib/cuttlefish-common directory
    - Install nginx configuration to /etc/nginx/conf.d/cuttlefish-orchestration.conf (RHEL path, not sites-available)
    - Reference frontend/debian/cuttlefish-orchestration.install
    - _Requirements: 4.1, 4.3_

  - [x] 6.4 Add %files section
    - List all installed files
    - Use %config(noreplace) for config files
    - _Requirements: 4.1, 4.3_

  - [x] 6.5 Add %pre section for user creation
    - Create httpcvd user with useradd -r
    - Add user to cvdnetwork group
    - _Requirements: 8.3, 8.4_

  - [x] 6.6 Add %post, %preun, %postun sections
    - Use systemd macros for cuttlefish-host_orchestrator.service
    - _Requirements: 4.5_

  - [x] 6.7 Add %changelog section
    - Add initial entry
    - _Requirements: 4.1_

- [x] 7. Complete remaining RPM spec files
  - [x] 7.1 Complete cuttlefish-integration.spec
    - Add %description, %prep, %build sections
    - Add %install section for udev rules and kernel module configs
    - Install udev rules to /usr/lib/udev/rules.d/
    - Install kernel module configs to /etc/modules-load.d/ and /etc/modprobe.d/
    - Add %files section
    - Reference base/debian/cuttlefish-integration.install
    - _Requirements: 4.1, 4.2, 5.3, 5.4_

  - [x] 7.2 Complete cuttlefish-common.spec (meta-package)
    - Add %description
    - Add Requires: cuttlefish-base, cuttlefish-user
    - No %build, %install, or %files sections (meta-package)
    - Add %changelog
    - _Requirements: 4.1, 4.2_

  - [x] 7.3 Complete cuttlefish-defaults.spec
    - Add %description, %prep, %build sections
    - Add %install section for configuration files
    - Use %config(noreplace) in %files section
    - Reference base/debian/cuttlefish-defaults.install
    - _Requirements: 4.1, 4.2, 5.5_

- [ ] 8. Implement SELinux policies (CRITICAL - must be done before build system)
  - [ ] 8.1 Create .rpmlintrc configuration early
    - Create .rpmlintrc in repository root
    - Configure acceptable warnings for Cuttlefish-specific patterns
    - Add filters for known false positives
    - _Requirements: 4.1_
  
  - [ ] 8.2 Create cuttlefish_host_resources SELinux policy (Phase 1: Basic policy)
    - Create base/rhel/selinux/cuttlefish_host_resources.te policy module (~400 lines)
    - Add type enforcement rules for network bridge creation
    - Add rules for tap interface creation
    - Add rules for dnsmasq execution
    - Add rules for iptables/firewalld rule modification
    - Add rules for kernel module loading (bridge, vhost-net, vhost-vsock, kvm)
    - Add device access rules for /dev/kvm, /dev/vhost-net, /dev/vhost-vsock
    - Create base/rhel/selinux/cuttlefish_host_resources.fc file context definitions
    - Define file contexts for /usr/lib/cuttlefish-common/bin/setup-host-resources.sh
    - _Requirements: 12.1, 12.2, 12.3, 12.5, 12.7, 12.11_
  
  - [ ] 8.3 Create cuttlefish_operator SELinux policy (Phase 1: Basic policy)
    - Create frontend/rhel/selinux/cuttlefish_operator.te policy module (~300 lines)
    - Add type enforcement rules for TLS certificate generation
    - Add rules for WebRTC signaling server operations
    - Add rules for socket creation in /run/cuttlefish/
    - Add rules for network binding on configured ports
    - Add port labeling for operator HTTP/HTTPS ports
    - Create frontend/rhel/selinux/cuttlefish_operator.fc file context definitions
    - Define file contexts for operator binary and certificate directory
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_
  
  - [ ] 8.4 Create cuttlefish_orchestration SELinux policy (Phase 1: Basic policy)
    - Create frontend/rhel/selinux/cuttlefish_orchestration.te policy module (~300 lines)
    - Add type enforcement rules for nginx integration
    - Add rules for systemd-journal-gatewayd communication
    - Add rules for artifact directory access (/var/lib/cuttlefish-common)
    - Add rules for network operations
    - Add port labeling for orchestrator port
    - Create frontend/rhel/selinux/cuttlefish_orchestration.fc file context definitions
    - Define file contexts for host_orchestrator binary
    - _Requirements: 12.1, 12.2, 12.3, 12.5_
  
  - [ ] 8.5 Create SELinux interface files
    - Create base/rhel/selinux/cuttlefish.if interface file
    - Add cuttlefish_read_config() interface
    - Add cuttlefish_manage_lib_files() interface
    - Allow other domains to interact with Cuttlefish
    - _Requirements: 12.6_
  
  - [ ] 8.6 Create SELinux boolean policies
    - Add cuttlefish_networking boolean (default: on)
    - Add cuttlefish_tls boolean (default: on)
    - Add cuttlefish_kvm boolean (default: on)
    - Add cuttlefish_connect_any boolean (default: off)
    - _Requirements: 12.6_
  
  - [ ] 8.7 Compile SELinux policy modules
    - Create Makefile for compiling .te files to .pp files
    - Use checkmodule to compile .te to .mod
    - Use semodule_package to create .pp from .mod and .fc
    - Verify policy modules compile without errors
    - Test policy modules on RHEL 10 with SELinux enforcing
    - _Requirements: 12.9_
  
  - [ ] 8.8 Integrate SELinux policies into spec files
    - Add compiled .pp files to %files section of cuttlefish-base.spec
    - Add compiled .pp files to %files section of cuttlefish-user.spec
    - Add compiled .pp files to %files section of cuttlefish-orchestration.spec
    - Add %post section commands to install policies (semodule -i)
    - Add restorecon commands to apply file contexts
    - Add %postun section commands to remove policies (semodule -r)
    - _Requirements: 12.9_
  
  - [ ] 8.9 Create SELinux troubleshooting documentation
    - Add SELinux section to docs/rhel/TROUBLESHOOTING.md
    - Document how to check for AVC denials (ausearch -m avc -ts recent)
    - Document how to generate policy from denials (audit2allow -a)
    - Document how to temporarily disable SELinux for testing (setenforce 0)
    - Document how to set per-domain permissive (semanage permissive -a)
    - Document SELinux boolean policies (getsebool, setsebool)
    - Document port labeling commands (semanage port)
    - _Requirements: 12.10_

- [ ] 9. Create build system infrastructure
  - [ ] 9.1 Create tools/buildutils/install_rhel10_deps.sh
    - [ ] 9.1.1 Detect RHEL version and derivative
      - Parse /etc/os-release for ID and VERSION_ID
      - Verify RHEL 10 or compatible (Rocky Linux 10, AlmaLinux 10)
    - [ ] 9.1.2 Set repository names based on OS version
      - For RHEL 10/Rocky 10/AlmaLinux 10: use "crb"
      - For RHEL 8/Rocky 8/AlmaLinux 8: use "powertools"
      - Handle version-specific repository naming
    - [ ] 9.1.3 Enable required repositories
      - Enable EPEL repository (dnf install epel-release)
      - Enable CRB/PowerTools repository (dnf config-manager --set-enabled ${repo_name})
      - Enable vbatts/bazel Copr repository (dnf copr enable vbatts/bazel)
    - [ ] 9.1.4 Install Bazel
      - Check for .bazelversion file
      - Try installing Bazelisk from GitHub releases (primary method)
      - If Bazelisk fails, try vbatts/bazel Copr (dnf install bazel)
      - If all methods fail, exit with clear error message and manual installation instructions
      - Verify Bazel version compatibility with .bazelversion
    - [ ] 9.1.5 Install build tools
      - Install rpmbuild tools (dnf install rpm-build rpmdevtools)
      - Install SELinux policy development tools (dnf install selinux-policy-devel)
      - Install mock for clean-room builds (dnf install mock)
    - [ ] 9.1.6 Install all build dependencies from spec files
      - Parse BuildRequires from all .spec files
      - Install dependencies using dnf
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_
  
  - [ ] 9.2 Create tools/buildutils/build_rpm_packages.sh
    - Detect OS type using /etc/os-release
    - Verify RHEL 10 or compatible (Rocky Linux 10, AlmaLinux 10)
    - Call install_rhel10_deps.sh
    - Setup ~/rpmbuild directory structure (rpmdev-setuptree)
    - Extract version using portable method: `VERSION=$(head -n1 base/debian/changelog | sed 's/.*(\([^)]*\)).*/\1/' | cut -d- -f1)`
    - Create source tarball for base/ directory with --dereference flag for Bazel symlinks
    - Create source tarball for frontend/ directory with --dereference flag
    - Copy source tarballs to ~/rpmbuild/SOURCES/
    - Copy all .spec files to ~/rpmbuild/SPECS/
    - Compile SELinux policy modules (.te → .pp)
    - Build all 6 RPM packages using rpmbuild -ba
    - Run rpmlint on all packages
    - Copy built packages to output directory
    - _Requirements: 2.6, 2.7, 2.8, 9.4_
  
  - [ ] 9.3 Update tools/buildutils/build_packages.sh for OS detection
    - Add OS detection at the beginning (check /etc/os-release)
    - If RHEL/Rocky/AlmaLinux detected, call build_rpm_packages.sh
    - If Debian/Ubuntu detected, call existing Debian build logic
    - Exit with error for unsupported OS
    - _Requirements: 9.3_
  - [ ] 9.1 Create cuttlefish_host_resources SELinux policy
    - Create base/rhel/selinux/cuttlefish_host_resources.te policy module
    - Allow network bridge creation (bridge_module, netif_create)
    - Allow tap interface creation (tun_tap_device_create)
    - Allow dnsmasq execution (dnsmasq_exec)
    - Allow iptables/firewalld rule modification (iptables_exec, firewalld_dbus)
    - Allow kernel module loading (kernel_module_load)
    - Create base/rhel/selinux/cuttlefish_host_resources.fc file context definitions
    - Define file contexts for /usr/lib/cuttlefish-common/bin/setup-host-resources.sh
    - _Requirements: 12.1, 12.2, 12.3, 12.5_
  
  - [ ] 9.2 Create cuttlefish_operator SELinux policy
    - Create frontend/rhel/selinux/cuttlefish_operator.te policy module
    - Allow TLS certificate generation (cert_t, openssl_exec)
    - Allow WebRTC signaling server operations (network_bind, tcp_socket_create)
    - Allow socket creation in /run/cuttlefish/ (cuttlefish_var_run_t)
    - Allow network binding on configured ports
    - Create frontend/rhel/selinux/cuttlefish_operator.fc file context definitions
    - Define file contexts for operator binary and certificate directory
    - _Requirements: 12.1, 12.2, 12.3_
  
  - [ ] 9.3 Create cuttlefish_orchestration SELinux policy
    - Create frontend/rhel/selinux/cuttlefish_orchestration.te policy module
    - Allow nginx integration (nginx_read_config, nginx_connect)
    - Allow systemd-journal-gatewayd communication (journald_read)
    - Allow artifact directory access (/var/lib/cuttlefish-common)
    - Allow network operations (network_bind, tcp_socket_create)
    - Create frontend/rhel/selinux/cuttlefish_orchestration.fc file context definitions
    - Define file contexts for host_orchestrator binary
    - _Requirements: 12.1, 12.2, 12.3_
  
  - [ ] 9.4 Compile SELinux policy modules
    - Create Makefile for compiling .te files to .pp files
    - Use checkmodule and semodule_package commands
    - Verify policy modules compile without errors
    - _Requirements: 12.3_
  
  - [ ] 9.5 Integrate SELinux policies into spec files
    - Add compiled .pp files to %files section of cuttlefish-base.spec
    - Add compiled .pp files to %files section of cuttlefish-user.spec
    - Add compiled .pp files to %files section of cuttlefish-orchestration.spec
    - Add %post section commands to install policies (semodule -i)
    - Add %postun section commands to remove policies (semodule -r)
    - _Requirements: 12.3_
  
  - [ ] 9.6 Create SELinux troubleshooting documentation
    - Add SELinux section to docs/rhel/TROUBLESHOOTING.md
    - Document how to check for AVC denials (ausearch -m avc)
    - Document how to generate policy from denials (audit2allow)
    - Document how to temporarily disable SELinux for testing (setenforce 0)
    - Document SELinux boolean policies
    - _Requirements: 12.4_

- [ ] 10. Checkpoint - Verify local build
  - Manually test build_rpm_packages.sh on RHEL 10 system
  - Verify all 6 RPM packages are created
  - Verify SELinux policy modules are included in packages
  - Run rpmlint on all packages to check for errors (should use .rpmlintrc created in Task 8.1)
  - Ask the user if questions arise

- [ ] 11. Create comprehensive documentation
  - [ ] 11.1 Create docs/rhel/ directory
    - Create docs/rhel/ directory structure
    - _Requirements: 6.1_
  
  - [ ] 11.2 Create docs/rhel/INSTALL.md
    - Document RHEL 10 system requirements
    - Provide EPEL and CRB repository setup commands
    - Detail package installation steps (dnf install cuttlefish-common)
    - Include post-installation verification commands
    - Add multi-device configuration instructions (num_cvd_accounts)
    - Include service startup commands (systemctl start cuttlefish-host-resources)
    - _Requirements: 6.1, 6.2_
  
  - [ ] 11.3 Create docs/rhel/REPOSITORIES.md
    - Document EPEL repository setup (dnf install epel-release)
    - Document CRB/PowerTools repository activation (dnf config-manager --set-enabled crb)
    - Document vbatts/bazel Copr repository (dnf copr enable vbatts/bazel)
    - Explain repository priorities and conflicts
    - _Requirements: 6.2_
  
  - [ ] 11.4 Create docs/rhel/TROUBLESHOOTING.md
    - Document common installation errors (missing repositories, dependency conflicts)
    - Document service startup failures (network bridge issues, permission errors)
    - Document SELinux problems and solutions (AVC denials, audit2allow)
    - Document firewalld vs iptables issues
    - Document build failures and resolution steps (Bazel cache issues, memory limits)
    - Document certificate generation failures
    - Document port conflicts with operator/orchestrator
    - Document KVM device permission issues
    - Document QEMU version incompatibilities
    - Document insufficient system resources (memory, disk space)
    - Include debugging commands (journalctl, systemctl status, ausearch, etc.)
    - _Requirements: 6.4, 12.10_
  
  - [ ] 11.5 Create docs/rhel/DEVELOPMENT.md
    - Document build environment setup (install_rhel10_deps.sh)
    - Provide instructions for building packages (build_rpm_packages.sh)
    - Explain testing changes locally (rpmbuild, mock)
    - Document contribution process for RHEL-specific patches
    - Include debugging guide for RPM build issues
    - _Requirements: 6.5_
  
  - [ ] 11.6 Update main README.md
    - Add RHEL support announcement
    - Link to docs/rhel/INSTALL.md
    - Update supported platforms list to include RHEL 10
    - _Requirements: 6.1_

- [ ] 12. Implement CI/CD infrastructure
  - [ ] 12.1 Create .github/workflows/rhel-build.yml
    - Add workflow trigger on pull_request and push to main
    - Configure matrix for distributions (rhel:10, rockylinux:10, almalinux:10)
    - Configure matrix for architectures (x86_64, aarch64)
    - Add checkout step
    - Add step to run build_rpm_packages.sh
    - Add step to run rpmlint on all packages
    - Add step to archive build artifacts
    - _Requirements: 7.1, 7.2_
  
  - [ ] 12.2 Create .github/workflows/rhel-test.yml
    - Add workflow trigger (depends on rhel-build)
    - Add clean installation test job (install all packages, verify services start)
    - Add multi-device test job (configure num_cvd_accounts=10, verify tap interfaces)
    - Add service functionality test (check network bridges, dnsmasq, iptables/firewalld)
    - _Requirements: 7.3, 7.4, 7.5_
  
  - [ ] 12.4 Prepare test artifacts
    - [ ] 12.4.1 Determine Android image version for CI testing
      - Select minimal Android image version for testing
      - Document image requirements
    - [ ] 12.4.2 Create minimal test image or mock device
      - Create or obtain minimal Android image for CI
      - Optimize image size for CI artifact storage
    - [ ] 12.4.3 Configure CI artifact storage for test images
      - Set up artifact caching in GitHub Actions
      - Configure artifact retention policy
    - [ ] 12.4.4 Document test image requirements
      - Document where to obtain test images
      - Document image size and storage requirements
      - _Requirements: 7.5_
  
  - [ ] 12.3 Create .github/workflows/compatibility.yml
    - Add Debian package comparison job (compare pre/post RHEL changes)
    - Add Debian regression test job (run existing test suite)
    - Add version synchronization check (compare debian/changelog with rhel/*.spec)
    - Configure to block merge on failures
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

- [ ] 13. Verify package upgrade handling
  - [ ] 13.1 Verify config file handling in spec files
    - Ensure all config files in /etc/sysconfig/ use %config(noreplace)
    - Verify %postun scripts include systemd daemon-reload
    - _Requirements: 10.1, 10.2_
  
  - [ ] 13.2 Test package upgrade scenario
    - Install version N of packages
    - Modify config files in /etc/sysconfig/
    - Upgrade to version N+1
    - Verify original config files preserved
    - Verify new config files created as .rpmnew
    - Verify services restarted
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [ ] 14. Implement spec file validation
  - [ ] 14.1 Create tools/buildutils/validate_specs.sh
    - Check all .spec files for required sections (Name, Version, %description, %files, etc.)
    - Verify systemd macro usage (%systemd_post, %systemd_preun, %systemd_postun)
    - Check for %config(noreplace) on config files
    - Verify %{_unitdir} macro usage for systemd units
    - Run rpmlint on all spec files
    - _Requirements: 4.1, 4.3, 4.4, 4.5_

- [ ] 15. Implement backward compatibility verification
  - [ ] 15.1 Create tools/buildutils/compare_debian_packages.sh
    - Build Debian packages from current commit
    - Extract package contents using dpkg-deb
    - Compare file lists between builds
    - Compare file checksums
    - Generate diff report
    - Exit with error if differences found
    - _Requirements: 11.4_
  
  - [ ] 15.2 Create tools/buildutils/check_version_sync.sh
    - Parse version from base/debian/changelog
    - Parse version from base/rhel/*.spec files
    - Parse version from frontend/debian/changelog
    - Parse version from frontend/rhel/*.spec files
    - Compare all versions
    - Report mismatches
    - Exit with error if versions don't match
    - _Requirements: 9.4_
  
  - [ ] 15.3 Verify Debian directories unchanged
    - Run git diff on base/debian/ and frontend/debian/
    - Ensure no modifications to existing Debian packaging files
    - _Requirements: 9.1, 11.1_

- [ ] 16. Implement file installation consistency checks
  - [ ] 16.1 Create tools/buildutils/compare_install_paths.sh
    - Parse file paths from base/debian/*.install files
    - Parse file paths from base/rhel/*.spec %files sections
    - Parse file paths from frontend/debian/*.install files
    - Parse file paths from frontend/rhel/*.spec %files sections
    - Compare paths (accounting for /etc/default → /etc/sysconfig)
    - Report inconsistencies
    - Exit with error if significant differences found
    - _Requirements: 9.5_

- [ ] 16.5 Create test environment infrastructure
  - [ ] 16.5.1 Create Containerfile/Dockerfile for RHEL 10 test environment
    - Create container image based on RHEL 10
    - Install systemd for service testing
    - Configure SELinux in enforcing mode
    - Pre-install test dependencies
  - [ ] 16.5.2 Document VM provisioning for bare-metal tests
    - Document how to provision RHEL 10 VMs
    - Document required VM resources (CPU, memory, disk)
    - Document network configuration requirements
  - [ ] 16.5.3 Create test system reset script
    - Create script to reset system state between tests
    - Remove installed packages
    - Clean up network configuration
    - Reset SELinux contexts
  - [ ] 16.5.4 Configure CI to provision test systems
    - Add test system provisioning to CI workflows
    - Configure container or VM creation
    - Set up test system cleanup
    - _Requirements: 7.3, 7.4_

- [ ] 17. Create integration test suite
  - [ ] 17.1 Create tools/testutils/test_rhel_install.sh
    - Verify script runs on RHEL 10 system (container, VM, or bare metal)
    - Verify SELinux is in enforcing mode (getenforce)
    - Install all 6 packages using dnf
    - Verify SELinux policy modules installed (semodule -l | grep cuttlefish)
    - Verify cuttlefish-host-resources.service starts successfully
    - Verify cuttlefish-operator.service starts successfully
    - Verify cuttlefish-host_orchestrator.service starts successfully
    - Check network bridges exist (cvd-ebr, cvd-wbr)
    - Check tap interfaces created (cvd-etap-01, cvd-wtap-01, etc.)
    - Verify dnsmasq processes running
    - Verify NAT rules configured (firewalld or iptables)
    - Check for SELinux AVC denials (ausearch -m avc -ts recent)
    - _Requirements: 7.3, 7.4, 7.5, 12.2_
  
  - [ ] 17.2 Create tools/testutils/test_rhel_multidevice.sh
    - Configure num_cvd_accounts=10 in /etc/sysconfig/cuttlefish-host-resources
    - Restart cuttlefish-host-resources.service
    - Verify 40 tap interfaces created (10 accounts × 4 interfaces each)
    - Verify network isolation between accounts
    - _Requirements: 7.4_
  
  - [ ] 17.3 Create tools/testutils/test_rhel_selinux.sh
    - Verify SELinux is in enforcing mode
    - Test all services start without AVC denials
    - Test network bridge creation with SELinux enforcing
    - Test tap interface creation with SELinux enforcing
    - Test certificate generation with SELinux enforcing
    - Report any AVC denials found
    - _Requirements: 12.2, 12.5_

- [ ] 18. Verify user and group management in spec files
  - [ ] 18.1 Review %pre sections for proper user/group creation
    - Verify cuttlefish-base.spec creates cvdnetwork group with groupadd -r
    - Verify cuttlefish-user.spec creates _cutf-operator user with useradd -r -s /sbin/nologin
    - Verify cuttlefish-orchestration.spec creates httpcvd user with useradd -r
    - Verify all service users are added to cvdnetwork group
    - Ensure getent checks exist before creation
    - _Requirements: 8.1, 8.2, 8.3, 8.4_
  
  - [ ] 18.2 Verify package removal doesn't delete users/groups
    - Ensure no %postun scripts delete users or groups
    - Test package removal and verify users/groups remain
    - _Requirements: 8.5_

- [ ] 19. Verify package removal handling
  - [ ] 19.1 Review %preun and %postun sections
    - Verify %systemd_preun macros stop services before removal
    - Verify %systemd_postun macros clean up after removal
    - Ensure no user/group deletion in %postun
    - Verify temporary files cleaned up (PID files, sockets)
    - _Requirements: 8.5_
  
  - [ ] 19.2 Create tools/testutils/test_rhel_removal.sh
    - Install all packages
    - Remove packages using dnf remove
    - Verify services stopped
    - Verify users and groups still exist
    - Verify temporary files removed
    - _Requirements: 8.5_

- [ ] 20. Verify architecture-specific handling
  - [ ] 20.1 Review architecture conditionals in spec files
    - Verify cuttlefish-base.spec uses %ifarch x86_64 for grub2-efi-ia32
    - Verify cuttlefish-base.spec uses %ifarch aarch64 for grub2-efi-aa64
    - Verify cuttlefish-base.spec uses %ifarch aarch64 for qemu-user-static equivalent
    - Test spec files parse correctly on both architectures
    - _Requirements: 4.2_

- [ ] 21. Final checkpoint - Run full validation
  - Run validate_specs.sh to check all spec files
  - Run check_version_sync.sh to verify version consistency
  - Run compare_install_paths.sh to verify file installation consistency
  - Run test_rhel_install.sh on RHEL 10 system
  - Run test_rhel_multidevice.sh
  - Run test_rhel_removal.sh
  - Verify all CI workflows pass
  - Ask the user if questions arise

- [ ] 22. Set up package signing
  - [ ] 22.1 Generate or import GPG signing key
    - Generate GPG key for package signing
    - Or import existing signing key
    - Document key management procedures
  - [ ] 22.2 Configure rpmbuild to sign packages
    - Configure ~/.rpmmacros with signing key
    - Test package signing with rpmsign
  - [ ] 22.3 Export public key for repository
    - Export GPG public key
    - Document how users import the key
  - [ ] 22.4 Document key management procedures
    - Document key backup procedures
    - Document key rotation procedures
    - _Requirements: 13.1_

- [ ] 23. Create package repository
  - [ ] 23.1 Set up repository directory structure
    - Create repository directory structure
    - Organize by distribution and architecture
  - [ ] 23.2 Create repository metadata with createrepo_c
    - Install createrepo_c
    - Generate repository metadata
    - Sign repository metadata
  - [ ] 23.3 Configure web server for repository access
    - Set up web server (nginx/apache)
    - Configure repository URL
    - Test repository access
  - [ ] 23.4 Document repository URL and configuration
    - Document repository URL for users
    - Provide .repo file for dnf configuration
    - Document GPG key import instructions
    - _Requirements: 13.1, 13.2, 13.3_

- [ ] 24. Prepare for release
  - [ ] 24.1 Create docs/rhel/MIGRATION.md
    - Document key differences from Debian (/etc/default vs /etc/sysconfig, LSB vs systemd)
    - Provide migration checklist for existing Debian users
    - Include troubleshooting for common migration issues
    - _Requirements: 6.4_
  
  - [ ] 24.2 Create RELEASE_NOTES.md for RHEL support
    - Document new RHEL 10 support
    - List supported RHEL derivatives (Rocky Linux 10, AlmaLinux 10)
    - List supported architectures (x86_64, aarch64)
    - Note any limitations or known issues
    - Provide installation instructions
    - _Requirements: 6.1_
  
  - [ ] 24.3 Final version synchronization
    - Verify version in base/debian/changelog matches base/rhel/*.spec
    - Verify version in frontend/debian/changelog matches frontend/rhel/*.spec
    - Update versions if needed
    - Run check_version_sync.sh to confirm
    - _Requirements: 9.4_
  
  - [ ] 24.4 Final validation checklist
    - Verify all spec files pass rpmlint
    - Verify all packages build successfully
    - Verify all integration tests pass
    - Verify backward compatibility tests pass
    - Verify CI workflows pass on all platforms
    - Verify documentation is complete
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 11.1, 11.2_
