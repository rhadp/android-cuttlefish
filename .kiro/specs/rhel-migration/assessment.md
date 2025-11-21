# RHEL Migration Specification Assessment

**Date:** 2025-11-21
**Assessor:** Claude Code
**Documents Assessed:**
- requirements.md
- design.md
- tasks.md

## Executive Summary

This assessment evaluates the correctness, completeness, and feasibility of the RHEL migration specifications for the Android Cuttlefish project. The documents demonstrate a thorough understanding of the migration requirements and provide a comprehensive plan. However, several issues were identified that require attention before implementation begins.

**Overall Assessment:**
- **Requirements:** ✅ GOOD - Well-structured with minor corrections needed
- **Design:** ⚠️ NEEDS REVISION - Comprehensive but contains technical inaccuracies
- **Tasks:** ⚠️ NEEDS REVISION - Detailed but has sequencing issues and missing tasks

---

## 1. Requirements Analysis

### 1.1 Strengths

1. **Well-structured format:** Each requirement follows a consistent user story + acceptance criteria pattern
2. **Comprehensive coverage:** Requirements cover installation, build, services, packaging, configuration, documentation, CI/CD, user management, compatibility, and upgrades
3. **Testable acceptance criteria:** Most acceptance criteria are specific and measurable
4. **Clear traceability:** Requirements are numbered and referenced throughout design and tasks

### 1.2 Issues Identified

#### ISSUE 1.1: Incorrect tap interface count (Requirement 3.2)
**Severity:** MEDIUM
**Location:** requirements.md:61-62

**Current Text:**
```
WHEN the cuttlefish-host-resources service starts THEN the Cuttlefish System SHALL create 4 tap interfaces (etap, mtap, wtap, wifiap) for each configured CVD account
```

**Issue:** The actual init script creates MORE than 4 interfaces per account:
- `cvd-etap-XX` - Ethernet tap (bridged to cvd-ebr)
- `cvd-mtap-XX` - Mobile network tap (standalone with NAT)
- `cvd-wtap-XX` - WiFi tap (bridged to cvd-wbr)
- `cvd-wifiap-XX` - WiFi AP tap (standalone with NAT)

However, the mobile network actually creates UP TO 2 mtap interfaces per account (using different subnets for accounts 1-64 vs 65-128), and similarly for wifiap interfaces.

**Evidence:** From base/debian/cuttlefish-base.cuttlefish-host-resources.init:
- Lines 256-272: Creates mtap interfaces with conditional subnet allocation
- Lines 275-291: Creates wifiap interfaces with conditional subnet allocation
- Lines 258-260: Creates etap interfaces via `create_bridged_interfaces`
- Lines 281-283: Creates wtap interfaces via `create_bridged_interfaces`

**Recommended Fix:** Clarify that the system creates exactly 4 tap interfaces per account (cvd-etap, cvd-mtap, cvd-wtap, cvd-wifiap), but note that the implementation supports up to 128 accounts with subnet segmentation for mobile and WiFi AP interfaces.

#### ISSUE 1.2: Missing SELinux context requirements (Requirement 12)
**Severity:** HIGH
**Location:** requirements.md:164-174

**Issue:** While Requirement 12 addresses SELinux broadly, it doesn't specify critical requirements:
1. File contexts for binaries, libraries, and configuration files
2. Port labeling for network services (operator http/https ports, orchestrator ports)
3. Boolean policies to allow users to disable specific SELinux protections
4. Transition rules for service startup
5. Requirements for confined vs unconfined domain execution

**Recommended Fix:** Add acceptance criteria:
- 12.6: WHEN binaries are installed THEN they SHALL have appropriate SELinux file contexts
- 12.7: WHEN network services bind to ports THEN SELinux SHALL permit the bindings via port labeling or policy
- 12.8: WHEN administrators need flexibility THEN SELinux boolean policies SHALL allow selective relaxation of restrictions

#### ISSUE 1.3: Missing firewalld vs iptables requirement
**Severity:** MEDIUM
**Location:** requirements.md:60-66 (Requirement 3)

**Issue:** Requirement 3.4 mentions configuring NAT rules using firewalld OR iptables, but doesn't specify how the system should detect which is active or handle conflicts.

**Evidence:** The design document (design.md:244-260) addresses this, but it should be elevated to a requirement.

**Recommended Fix:** Add acceptance criterion to Requirement 3:
```
3.4a. WHEN firewalld is active THEN the Cuttlefish System SHALL use firewall-cmd for NAT configuration
3.4b. WHEN firewalld is inactive THEN the Cuttlefish System SHALL use iptables for NAT configuration
3.4c. WHEN the service detects the firewall configuration THEN it SHALL verify the method used via systemctl is-active firewalld
```

#### ISSUE 1.4: Insufficient Bazel dependency requirement detail
**Severity:** MEDIUM
**Location:** requirements.md:46-53 (Requirement 2)

**Issue:** Requirement 2.1a mentions "Bazel availability from Bazelisk or the vbatts/bazel Copr repository" but doesn't specify:
- Minimum Bazel version required
- Bazelisk version requirements
- Fallback strategy if Copr is unavailable
- How to handle .bazelversion file

**Recommended Fix:** Add detailed acceptance criteria:
```
2.1a-1. WHEN the build script checks for Bazel THEN it SHALL verify compatibility with the version specified in .bazelversion
2.1a-2. WHEN Bazel is not installed THEN the build script SHALL attempt to install Bazelisk as the primary method
2.1a-3. WHEN Bazelisk is unavailable THEN the build script SHALL fall back to the vbatts/bazel Copr repository
2.1a-4. WHEN all Bazel installation methods fail THEN the build script SHALL exit with a clear error message and manual installation instructions
```

#### ISSUE 1.5: Missing kernel module loading requirement
**Severity:** HIGH
**Location:** Missing from Requirement 3

**Issue:** The init script loads kernel modules (bridge, vhost-net, vhost-vsock, kvm) but there's no requirement specifying this.

**Evidence:** From base/debian/cuttlefish-base.cuttlefish-host-resources.init:32
```bash
modprobe bridge
```

And from cuttlefish-integration.udev, kernel modules are required for KVM and vhost operations.

**Recommended Fix:** Add new acceptance criterion to Requirement 3:
```
3.7. WHEN the cuttlefish-host-resources service starts THEN the Cuttlefish System SHALL load required kernel modules (bridge, vhost-net, vhost-vsock)
```

#### ISSUE 1.6: Missing ebtables requirement
**Severity:** MEDIUM
**Location:** Missing from Requirements

**Issue:** The init script uses ebtables-legacy for broute operations when bridge_interface is configured, but there's no requirement for this.

**Evidence:** From base/debian/cuttlefish-base.cuttlefish-host-resources.init:54-60 and lines 184-191

**Recommended Fix:** Add to Requirement 3 or create a new requirement for network filtering dependencies.

### 1.3 Missing Requirements

#### MISSING 1.1: Package repository publication requirement
**Severity:** LOW

There's no requirement specifying how/where RPM packages will be published and distributed. The design mentions "official and community repositories" but there's no requirement for this.

**Recommended Addition:** New Requirement 13:
```
Requirement 13: Package Distribution
User Story: As a RHEL administrator, I want to install Cuttlefish from standard package repositories, so that I can use familiar package management workflows.

Acceptance Criteria:
13.1. WHEN packages are built THEN they SHALL be published to a public repository
13.2. WHEN documentation is created THEN it SHALL include repository configuration instructions
13.3. WHEN packages are updated THEN repository metadata SHALL be refreshed automatically
```

#### MISSING 1.2: Architecture detection requirement
**Severity:** MEDIUM

The design mentions architecture-specific dependencies (x86_64 vs aarch64) but there's no requirement for proper architecture detection and handling.

**Recommended Addition:** Add to Requirement 2:
```
2.6. WHEN the build process executes on aarch64 THEN the Build System SHALL use aarch64-specific dependencies (grub2-efi-aa64, qemu-user-static equivalent)
2.7. WHEN the build process executes on x86_64 THEN the Build System SHALL use x86_64-specific dependencies (grub2-efi-ia32)
```

### 1.4 Correctness Assessment

**Verdict:** ✅ REQUIREMENTS ARE MOSTLY CORRECT

The requirements demonstrate a solid understanding of the migration needs. The issues identified are correctable and don't invalidate the overall approach. Most critical is addressing the SELinux requirements more thoroughly, as this is often the most challenging aspect of RHEL packaging.

---

## 2. Design Analysis

### 2.1 Strengths

1. **Comprehensive architecture:** The design clearly separates concerns between Debian and RHEL packaging
2. **Backward compatibility focus:** Strong emphasis on maintaining Debian functionality
3. **Detailed component specifications:** Each component has clear purpose, interfaces, and rationale
4. **Property-based testing approach:** The 47 correctness properties provide excellent test coverage
5. **Error handling section:** Thorough consideration of failure modes

### 2.2 Issues Identified

#### ISSUE 2.1: SELinux policy complexity underestimated
**Severity:** HIGH
**Location:** design.md:136-186 (Section 0. SELinux Integration)

**Issue:** The design proposes creating custom SELinux policies but significantly underestimates the complexity:

1. **Missing policy types:** The design lists file contexts but doesn't specify policy types (targeted vs strict vs mls)
2. **Incomplete file contexts:** Missing contexts for:
   - `/var/lib/cuttlefish-common` artifacts
   - `/run/cuttlefish` runtime directory
   - Generated certificates in `/etc/cuttlefish-common/operator/cert/`
   - Bazel-generated binaries (which may have special requirements)

3. **Network context missing:** No mention of port contexts needed for:
   - Operator HTTP/HTTPS ports (configurable)
   - Host orchestrator ports
   - DHCP/DNS ports for dnsmasq

4. **KVM and vhost access:** The design doesn't address how to allow access to:
   - `/dev/kvm` device
   - `/dev/vhost-net` device
   - `/dev/vhost-vsock` device
   - These may need device context labels and access rules

5. **Domain transitions:** No specification of how services transition between domains (init → service → spawned processes)

**Evidence:** Real-world SELinux policies for similar network virtualization software (libvirt, docker) are 1000+ lines and require extensive testing.

**Recommended Fix:**
- Expand SELinux section with complete type enforcement (.te) file structure
- Add interface files (.if) for allowing other domains to interact with Cuttlefish
- Include policy for device access (`dev_rw_kvm`, `dev_rw_vhost`)
- Document testing strategy with audit2allow workflow
- Consider whether to require SELinux permissive mode initially with a roadmap to enforcing

#### ISSUE 2.2: Firewalld zone assumptions
**Severity:** MEDIUM
**Location:** design.md:244-260 (Service Wrapper Scripts - Firewall Integration)

**Issue:** The design assumes using the "public" zone:
```bash
firewall-cmd --add-masquerade --zone=public --permanent
```

**Problems:**
1. Default zone might not be "public" on RHEL systems
2. Should use `--get-default-zone` or allow configuration
3. Need to handle rich rules for specific interface masquerading
4. Missing port opening requirements for operator and orchestrator services

**Recommended Fix:**
```bash
default_zone=$(firewall-cmd --get-default-zone)
firewall-cmd --add-masquerade --zone=${default_zone} --permanent
# Also need to open ports:
firewall-cmd --add-port=${operator_http_port}/tcp --zone=${default_zone} --permanent
firewall-cmd --add-port=${operator_https_port}/tcp --zone=${default_zone} --permanent
```

#### ISSUE 2.3: Bazel output path assumptions
**Severity:** MEDIUM
**Location:** design.md:299-318 (Source Tarball Creation)

**Issue:** The source tarball creation shows Bazel output paths:
```bash
# Create clean source tarball including Bazel workspace
tar czf ~/rpmbuild/SOURCES/cuttlefish-base-${VERSION}.tar.gz \
  --transform "s,^base/,cuttlefish-base-${VERSION}/," \
  --exclude='.git' \
  --exclude='bazel-*' \
  base/
```

**Problems:**
1. Bazel output directories (bazel-bin, bazel-out) are symlinks that can cause issues with tar
2. The exclusion pattern may miss `.bazelversion`, `.bazelrc` files needed for build
3. Source tarball must include WORKSPACE file but the example doesn't verify it exists

**Recommended Fix:** Add explicit inclusion of required Bazel files and better symlink handling:
```bash
tar czf ~/rpmbuild/SOURCES/cuttlefish-base-${VERSION}.tar.gz \
  --transform "s,^base/,cuttlefish-base-${VERSION}/," \
  --exclude='.git' \
  --exclude='bazel-*' \
  --exclude='.*.swp' \
  --dereference \
  base/
```

#### ISSUE 2.4: Go build flags incomplete
**Severity:** MEDIUM
**Location:** design.md:535-536 (Property 6)

**Issue:** Property 6 states:
```
For any build execution, Go binaries should be built with -buildmode=pie flag
```

But RHEL packaging also requires:
- `-trimpath` for reproducible builds
- Proper LDFLAGS for hardening
- Version information embedding via ldflags

**Evidence:** From RHEL Go packaging guidelines, the standard build command is:
```bash
go build -buildmode=pie -compiler=gc -trimpath \
  -ldflags "${LDFLAGS:-} -B 0x$(head -c20 /dev/urandom|od -An -tx1|tr -d ' \n')" \
  -a -v -x
```

**Recommended Fix:** Update Property 6 and the design to include full Go build flags required for RHEL compliance.

#### ISSUE 2.5: Version extraction from debian/changelog
**Severity:** MEDIUM
**Location:** design.md:305-306

**Issue:** The design uses:
```bash
VERSION=$(dpkg-parsechangelog -S Version -l base/debian/changelog | cut -d- -f1)
```

**Problems:**
1. `dpkg-parsechangelog` is a Debian-specific tool not available on RHEL
2. The command won't work during RPM builds on RHEL systems
3. Cut command assumes specific version format that may not be consistent

**Recommended Fix:** Use portable version extraction:
```bash
VERSION=$(head -n1 base/debian/changelog | sed 's/.*(\([^)]*\)).*/\1/' | cut -d- -f1)
```
Or maintain version in a separate VERSION file.

#### ISSUE 2.6: RPM spec file %prep section unclear
**Severity:** MEDIUM
**Location:** design.md:195-206 (RPM Spec Files)

**Issue:** The design states "Reads source tarballs from ~/rpmbuild/SOURCES/" but doesn't specify:
- How the %prep section should handle the Bazel workspace
- Whether to use %autosetup or %setup
- How to handle patches if needed
- Directory structure after extraction

**Recommended Fix:** Add specific %prep section example:
```spec
%prep
%setup -q -n cuttlefish-base-%{version}
# Verify WORKSPACE exists
test -f WORKSPACE || exit 1
```

#### ISSUE 2.7: Missing systemd unit file hardening
**Severity:** MEDIUM
**Location:** design.md:209-225 (Systemd Service Units)

**Issue:** The systemd unit design doesn't mention hardening options that are standard for RHEL services:
- `PrivateTmp=yes`
- `ProtectSystem=strict`
- `NoNewPrivileges=yes`
- `ProtectKernelModules=yes`
- `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK`

**Recommended Fix:** Add security hardening section to systemd unit design with appropriate restrictions that don't break Cuttlefish functionality.

#### ISSUE 2.8: Property 11 incorrect
**Severity:** LOW
**Location:** design.md:554-556 (Property 11)

**Issue:** Property 11 states:
```
For any start of cuttlefish-host-resources service, iptables should contain MASQUERADE rules for the default interface
```

**Problems:**
1. "Default interface" is ambiguous - should specify which interface
2. On firewalld systems, the rule won't be in iptables directly but managed by firewalld
3. Should verify MASQUERADE rules for specific networks (192.168.96.0/24, 192.168.98.0/24)

**Recommended Fix:** Clarify the property to check for masquerading of Cuttlefish networks regardless of whether iptables or firewalld is used.

#### ISSUE 2.9: Missing udev rules handling
**Severity:** MEDIUM
**Location:** design.md (Missing section)

**Issue:** The design doesn't address udev rules handling, but they exist in base/debian/cuttlefish-base.udev and cuttlefish-integration.udev.

**Required Actions:**
1. Copy udev rules to /usr/lib/udev/rules.d/ (not /lib/udev/rules.d/)
2. Trigger udev reload in %post section
3. Handle KVM and vhost device permissions

**Recommended Fix:** Add udev rules handling to Component 1 (RPM Spec Files) %install section.

#### ISSUE 2.10: Nginx configuration location
**Severity:** LOW
**Location:** design.md mentions nginx for orchestration but doesn't specify configuration location

**Issue:** RHEL uses different nginx configuration paths than Debian:
- Debian: `/etc/nginx/sites-available/`, `/etc/nginx/sites-enabled/`
- RHEL: `/etc/nginx/conf.d/` (no sites-available/enabled pattern)

**Recommended Fix:** Specify RHEL nginx configuration should be installed to `/etc/nginx/conf.d/cuttlefish-orchestration.conf`.

### 2.3 Missing Design Elements

#### MISSING 2.1: Dependency installation script details
**Severity:** HIGH

The design mentions `install_rhel10_deps.sh` but doesn't provide the actual dependency list or script structure. This is critical for reproducible builds.

**Recommended Addition:** Add appendix with complete dependency list mapped from base/debian/control and frontend/debian/control.

#### MISSING 2.2: RPM package naming and versioning conventions
**Severity:** MEDIUM

The design doesn't specify:
- How to handle epoch in RPM versions
- Package naming for different architectures (x86_64 vs aarch64)
- Release numbering scheme (e.g., 1%{?dist})
- How to handle pre-release versions

**Recommended Addition:** Add section on RPM naming conventions:
```
Name: cuttlefish-base
Version: %{version}
Release: 1%{?dist}
```

#### MISSING 2.3: Mock build environment specification
**Severity:** MEDIUM

The design focuses on rpmbuild but doesn't mention using mock for clean-room builds, which is RHEL packaging best practice.

**Recommended Addition:** Add section on using mock for isolated builds and testing.

### 2.4 Correctness Assessment

**Verdict:** ⚠️ DESIGN NEEDS REVISION

The design is comprehensive and well-structured, but contains several technical inaccuracies and underestimates complexity in critical areas (especially SELinux). The design is implementable but will likely encounter issues if followed exactly as written. Recommended to:

1. Revise SELinux section with realistic complexity estimates
2. Fix firewalld zone handling
3. Correct version extraction method
4. Add missing udev and nginx configuration details
5. Expand Go build flags to meet RHEL requirements

---

## 3. Tasks Analysis

### 3.1 Strengths

1. **Highly detailed:** 22 major tasks broken into 200+ subtasks
2. **Clear traceability:** Each task references requirements it satisfies
3. **Logical grouping:** Tasks grouped by component (spec files, systemd, SELinux, docs, CI)
4. **Checkpoints included:** Tasks 10 and 21 are validation checkpoints

### 3.2 Issues Identified

#### ISSUE 3.1: Task ordering problem - SELinux policies too late
**Severity:** HIGH
**Location:** tasks.md:332-385 (Task 9 - Implement SELinux policies)

**Issue:** Task 9 (SELinux policies) comes AFTER Task 8 (build system infrastructure), but the build system in Task 8.2 is supposed to build packages that should include SELinux policies.

**Sequencing Problem:**
- Task 8.2: Create build_rpm_packages.sh (which builds packages)
- Task 9: Create SELinux policies
- Task 10: Checkpoint - verify local build

This ordering means the first build attempt won't have SELinux policies integrated.

**Recommended Fix:** Move SELinux policy creation (Task 9) before build system creation (Task 8), or split build system creation into "skeleton" and "full build" phases.

#### ISSUE 3.2: Version extraction task uses Debian tool
**Severity:** MEDIUM
**Location:** tasks.md:305-306

**Issue:** Task 8.2 (build_rpm_packages.sh) includes:
```bash
VERSION=$(dpkg-parsechangelog -S Version -l base/debian/changelog | cut -d- -f1)
```

But `dpkg-parsechangelog` won't be available on RHEL build systems.

**Recommended Fix:** Use portable version extraction (sed/awk) or require VERSION file.

#### ISSUE 3.3: Missing task - Create .rpmlintrc early
**Severity:** LOW
**Location:** tasks.md:478-490 (Task 14)

**Issue:** Task 14.1 creates .rpmlintrc, but rpmlint is used in Task 10 (checkpoint) and Task 21 (final validation). The .rpmlintrc should be created before first use.

**Recommended Fix:** Move Task 14.1 (Create .rpmlintrc) to before Task 4 (spec file completion).

#### ISSUE 3.4: Task 2.1 missing -devel suffix mapping
**Severity:** LOW
**Location:** tasks.md:40-45

**Issue:** Task 2.1 states "Map Debian package names to RHEL equivalents" and mentions specific mappings, but doesn't mention the systematic -dev → -devel suffix change needed for all development packages.

**Evidence:** From base/debian/control, many packages use -dev suffix:
- libfmt-dev → libfmt-devel
- libgflags-dev → gflags-devel
- libjsoncpp-dev → jsoncpp-devel
- libprotobuf-dev → protobuf-devel
- etc.

**Recommended Fix:** Add explicit note about -dev → -devel suffix mapping pattern.

#### ISSUE 3.5: Task 3.2 setup-host-resources.sh complexity underestimated
**Severity:** HIGH
**Location:** tasks.md:80-91

**Issue:** Task 3.2 lists creating setup-host-resources.sh with specific sub-tasks, but the actual init script is 371 lines with complex logic for:
- Multiple network types (ethernet, mobile, wifi, wifi AP)
- Different subnet allocations for accounts 1-64 vs 65-128
- IPv6 support with conditional configuration
- ebtables configuration for non-bridged mode
- Docker environment detection
- Nvidia module loading

The task description doesn't adequately capture this complexity.

**Recommended Fix:** Break Task 3.2 into more granular subtasks:
- 3.2.1: Extract and adapt network bridge creation functions
- 3.2.2: Extract and adapt tap interface creation functions
- 3.2.3: Implement firewalld vs iptables detection
- 3.2.4: Implement NAT configuration for both firewall types
- 3.2.5: Add dnsmasq startup logic
- 3.2.6: Add Docker environment handling
- 3.2.7: Test script with multiple num_cvd_accounts values

#### ISSUE 3.6: Missing task - Handle architecture-specific Bazel outputs
**Severity:** MEDIUM
**Location:** Missing from Task 4

**Issue:** The Bazel build produces different output paths for different architectures:
- `[amd64] cvd/bazel-out/k8-opt/bin/cuttlefish/package/cuttlefish-common`
- `[arm64] cvd/bazel-out/aarch64-opt/bin/cuttlefish/package/cuttlefish-common`

The spec file %install section needs to handle this, but there's no task for it.

**Recommended Fix:** Add to Task 4.4:
```
4.4.1: Detect build architecture using %{_arch}
4.4.2: Set bazel_output_path based on architecture
4.4.3: Copy binaries from architecture-specific Bazel output directory
```

#### ISSUE 3.7: Task 8.1 - EPEL and CRB repository names may vary
**Severity:** MEDIUM
**Location:** tasks.md:301-310

**Issue:** Task 8.1 assumes repository names:
- "crb" for CodeReady Builder
- "epel-release" package name

But these vary by distribution:
- RHEL 10/9: "crb"
- CentOS Stream 10: "crb"
- Fedora 43: Uses default repositories (no CRB needed)

**Recommended Fix:** Add OS version detection to Task 8.1:
```
8.1.1: Detect RHEL version and derivative
8.1.2: Set repository names based on OS version (crb for RHEL 10, powertools for RHEL 8)
8.1.3: Enable appropriate repository
```

#### ISSUE 3.8: Missing task - Handle %{_libdir} vs hardcoded /usr/lib
**Severity:** MEDIUM
**Location:** Multiple tasks use /usr/lib directly

**Issue:** Several tasks reference `/usr/lib/cuttlefish-common/bin/` but on RHEL x86_64 systems, the proper macro is `%{_libdir}` which expands to `/usr/lib64` on x86_64.

This could cause problems with library path searching.

**Recommended Fix:** Clarify in spec file tasks whether to use:
- `/usr/lib/cuttlefish-common` (fixed, non-library binaries/scripts)
- `%{_libdir}` (architecture-specific libraries)

Based on the Debian packaging, cuttlefish-common contains binaries not libraries, so `/usr/lib/cuttlefish-common` is likely correct, but this should be explicitly documented.

#### ISSUE 3.9: Task 11.4 - Insufficient troubleshooting coverage
**Severity:** LOW
**Location:** tasks.md:414-421

**Issue:** Task 11.4 (TROUBLESHOOTING.md) lists categories but is missing common issues:
- Bazel build failures (cache issues, memory limits)
- Certificate generation failures
- Port conflicts with operator/orchestrator
- KVM device permission issues
- QEMU version incompatibilities
- Insufficient system resources (memory, disk space)

**Recommended Fix:** Expand troubleshooting documentation task to include these scenarios.

#### ISSUE 3.10: Missing task - Create VERSION file or version management
**Severity:** MEDIUM
**Location:** Missing from tasks

**Issue:** Multiple tasks need to extract version numbers from debian/changelog, but there's no task to establish a version management strategy that works on both Debian and RHEL systems.

**Recommended Fix:** Add new task before Task 1:
```
Task 0: Establish version management
0.1: Create VERSION file in repository root
0.2: Update Debian changelog generation to read from VERSION
0.3: Update spec files to read from VERSION
0.4: Create version validation script
```

Alternatively, keep version in changelog but add a portable extraction script.

#### ISSUE 3.11: Task 12 (CI/CD) - Missing test data preparation
**Severity:** MEDIUM
**Location:** tasks.md:437-461

**Issue:** CI tests need to boot Cuttlefish devices (Task 12.2, Requirement 7.5) but there's no task for:
- Obtaining Android images for testing
- Storing test images in CI artifacts
- Determining which Android version to test with
- Handling large image sizes in CI

**Recommended Fix:** Add subtask:
```
12.4: Prepare test artifacts
12.4.1: Determine Android image version for CI testing
12.4.2: Create minimal test image or mock device
12.4.3: Configure CI artifact storage for test images
12.4.4: Document test image requirements
```

#### ISSUE 3.12: Task 17 (integration tests) assumes RHEL 10 test system
**Severity:** MEDIUM
**Location:** tasks.md:529-558

**Issue:** Tasks 17.1, 17.2, 17.3 all begin with "Verify script runs on RHEL 10 system" but don't specify:
- How to provision RHEL 10 test systems
- Whether to use containers, VMs, or bare metal
- How to reset system state between tests
- Whether tests run in CI or manually

**Recommended Fix:** Add task for test environment setup before Task 17:
```
Task 16.5: Create test environment infrastructure
16.5.1: Create Containerfile/Dockerfile for RHEL 10 test environment
16.5.2: Document VM provisioning for bare-metal tests
16.5.3: Create test system reset script
16.5.4: Configure CI to provision test systems
```

### 3.3 Missing Tasks

#### MISSING 3.1: RPM signing infrastructure
**Severity:** LOW

No tasks for setting up RPM signing, which is important for production distribution.

**Recommended Addition:**
```
Task 23: Set up package signing
23.1: Generate or import GPG signing key
23.2: Configure rpmbuild to sign packages
23.3: Export public key for repository
23.4: Document key management procedures
```

#### MISSING 3.2: Repository metadata generation
**Severity:** MEDIUM

No tasks for creating YUM/DNF repository metadata (createrepo_c).

**Recommended Addition:**
```
Task 24: Create package repository
24.1: Set up repository directory structure
24.2: Create repository metadata with createrepo_c
24.3: Configure web server for repository access
24.4: Document repository URL and configuration
```

#### MISSING 3.3: Migration from Debian testing
**Severity:** LOW

The requirements mention migration (Requirement 6), and there's a docs/rhel/MIGRATION.md in Task 22.1, but no task for actually testing the migration path - installing on a system that previously had Debian packages.

**Recommended Addition:**
```
Task 25: Test migration path
25.1: Install Debian packages on test system
25.2: Create migration script that switches to RPM packages
25.3: Test migration script on Ubuntu to RHEL migration scenario
25.4: Document migration procedures
```

#### MISSING 3.4: Dependency mapping verification
**Severity:** MEDIUM

Task 2 mentions mapping dependencies, but there's no verification task to ensure all Debian dependencies have RHEL equivalents.

**Recommended Addition:** Add to Task 2:
```
2.6: Verify dependency mapping completeness
2.6.1: Create script to extract all Debian dependencies
2.6.2: Cross-reference with RHEL dependency mappings
2.6.3: Verify all packages exist in RHEL/EPEL/CRB repos
2.6.4: Report any unmapped dependencies
```

### 3.4 Correctness Assessment

**Verdict:** ⚠️ TASKS NEED REVISION

The tasks are comprehensive and detailed, but have several sequencing issues and underestimate complexity in key areas. The most critical issues are:

1. SELinux task ordering (needs to move earlier)
2. setup-host-resources.sh complexity (needs more subtasks)
3. Version extraction portability (needs portable solution)
4. Missing test environment setup tasks

These issues are correctable without major restructuring. The overall task breakdown is sound and provides good implementation guidance once the identified issues are addressed.

---

## 4. Cross-Document Analysis

### 4.1 Requirement-Design Alignment

**Analysis:** Most requirements are well-addressed in the design, with these exceptions:

1. **Requirement 2.1a (Bazel installation)** - Design provides strategy but underspecifies fallback handling
2. **Requirement 3.4 (Firewalld vs iptables)** - Design addresses but with incorrect zone assumptions
3. **Requirement 12 (SELinux)** - Design severely underestimates complexity
4. **Requirement 7 (CI/CD)** - Design provides architecture but missing test data handling

**Recommendation:** Strengthen design sections for Bazel installation fallbacks and SELinux policy development.

### 4.2 Design-Tasks Alignment

**Analysis:** Tasks generally follow the design, but with these gaps:

1. **SELinux implementation tasks** - Tasks follow design but inherit its complexity underestimation
2. **Build system tasks** - Don't account for architecture-specific Bazel outputs adequately
3. **Testing tasks** - Missing test environment provisioning specified in design
4. **Repository publication** - Designed but no implementation tasks

**Recommendation:** Add missing tasks for test environment, repository creation, and RPM signing.

### 4.3 Internal Consistency

#### Requirements Internal Consistency: ✅ GOOD
- Requirements are numbered consistently
- No conflicting acceptance criteria identified
- Traceability is clear

#### Design Internal Consistency: ⚠️ ISSUES FOUND
- Property 11 conflicts with firewalld approach in Section 3
- Source tarball creation example doesn't match component specifications
- SELinux file contexts incomplete compared to stated requirements

#### Tasks Internal Consistency: ⚠️ ISSUES FOUND
- Task 9 references output of Task 8 but should come before it
- Task 14.1 needed by Task 10 but comes after
- Version extraction method in Task 8.2 won't work on RHEL

**Recommendation:** Reorder tasks to resolve dependencies and fix version extraction.

---

## 5. Codebase Alignment Assessment

### 5.1 Analysis Method

The actual Cuttlefish codebase was examined to verify alignment with specification documents:

**Files Reviewed:**
- `base/debian/control` - Package definitions and dependencies
- `base/debian/cuttlefish-base.cuttlefish-host-resources.init` - Init script (371 lines)
- `base/debian/cuttlefish-base.cuttlefish-host-resources.default` - Configuration
- `base/debian/cuttlefish-base.install` - File installation mapping
- `base/debian/rules` - Build rules (105 lines)
- `base/debian/cuttlefish-base.udev` - Udev rules
- `frontend/debian/control` - Frontend package definitions
- `frontend/debian/cuttlefish-user.cuttlefish-operator.init` - Operator init script
- `frontend/debian/cuttlefish-orchestration.cuttlefish-host_orchestrator.init` - Orchestrator init
- `.github/workflows/` - Existing CI infrastructure
- `.kokoro/` - Existing Kokoro CI configuration

### 5.2 Alignment Issues

#### ALIGNMENT 5.1: Init script complexity matches specifications
**Status:** ⚠️ PARTIAL MISMATCH

**Finding:** The actual init script has significantly more complexity than the specifications acknowledge:
- 371 lines of shell script logic
- Complex network configuration with multiple subnet ranges
- ebtables broute configuration for non-bridged mode
- Docker environment detection and device permission handling
- Nvidia kernel module preloading
- IPv6 configuration with prefix length handling

**Impact on Specs:**
- Design document should expand systemd conversion complexity estimate
- Task 3.2 should be broken into more granular subtasks
- Testing requirements should include Docker environment scenarios

#### ALIGNMENT 5.2: Package count matches
**Status:** ✅ CORRECT

**Finding:** The specifications correctly identify 6 packages:
1. cuttlefish-base (base/debian/control)
2. cuttlefish-common (base/debian/control - meta-package)
3. cuttlefish-integration (base/debian/control)
4. cuttlefish-defaults (base/debian/control)
5. cuttlefish-user (frontend/debian/control)
6. cuttlefish-orchestration (frontend/debian/control)

#### ALIGNMENT 5.3: Bazel build complexity understood
**Status:** ✅ CORRECT

**Finding:** The specifications correctly understand Bazel usage:
- Multiple compilation modes (dbg, opt, fastbuild)
- Architecture-specific output paths (k8-opt vs aarch64-opt)
- Complex flag passing from debian/rules to bazel
- Disk cache and remote cache support
- Debug symbol handling

**Evidence:** base/debian/rules shows sophisticated Bazel integration that specs acknowledge.

#### ALIGNMENT 5.4: Dependencies mapping needed
**Status:** ⚠️ INCOMPLETE

**Finding:** base/debian/control shows 50+ dependencies that need RHEL mapping. The specifications acknowledge this but don't provide complete mapping.

**Key dependencies requiring verification:**
- `libaom-dev` - May not be in RHEL repos (EPEL?)
- `libfmt-dev` → `fmt-devel` (available?)
- `libsrtp2-dev` → `libsrtp-devel` (SRTP2 version?)
- `libz3-dev` → `z3-devel` (available in CRB?)

**Recommendation:** Create complete dependency mapping table as appendix before implementation begins.

#### ALIGNMENT 5.5: CI infrastructure exists
**Status:** ✅ VERIFIED

**Finding:** The codebase has existing CI:
- GitHub Actions workflows (9 files in .github/workflows/)
- Kokoro configuration (.kokoro/presubmit.cfg)

The design correctly proposes adding parallel RHEL workflows to existing structure.

#### ALIGNMENT 5.6: Build utilities exist
**Status:** ✅ VERIFIED

**Finding:** tools/buildutils/ contains:
- build_package.sh
- build_packages.sh
- installbazel.sh

The design correctly proposes adding parallel build_rpm_packages.sh and install_rhel10_deps.sh.

#### ALIGNMENT 5.7: Udev rules exist and need handling
**Status:** ⚠️ UNDERSPECIFIED

**Finding:** Two udev rules files exist:
- base/debian/cuttlefish-base.udev
- base/debian/cuttlefish-integration.udev

These set permissions for /dev/kvm, /dev/vhost-*, and other devices. The specs mention udev rules but don't detail the permission management requirements.

**Recommendation:** Add detailed udev rules handling to design and tasks, including SELinux contexts for device nodes.

### 5.3 Codebase Alignment Summary

**Overall Alignment:** ✅ GOOD

The specifications demonstrate solid understanding of the codebase structure and requirements. The main gaps are:

1. Underestimating init script conversion complexity
2. Incomplete dependency mapping documentation
3. Insufficient detail on udev rules and device permissions

These are correctable without major specification revisions.

---

## 6. Risk Assessment

### 6.1 High Risk Areas

#### RISK 1: SELinux Policy Development
**Probability:** HIGH
**Impact:** HIGH
**Severity:** CRITICAL

**Analysis:** Creating functional SELinux policies for Cuttlefish is the highest risk aspect:
- Network bridge and tap interface creation requires privileged operations
- KVM and vhost device access needs special permissions
- Certificate generation and file management has security implications
- Incorrect policies will cause services to fail in enforcing mode
- Testing requires RHEL systems with SELinux enforcing

**Mitigation Strategies:**
1. Start with permissive mode and use audit2allow to generate policies
2. Engage with SELinux experts or Red Hat support early
3. Plan for 2-3 iteration cycles of policy development
4. Create comprehensive test suite for SELinux-enabled scenarios
5. Consider shipping initial version with SELinux permissive requirement

**Timeline Impact:** Could add 2-4 weeks to project if not scoped correctly.

#### RISK 2: Dependency Availability
**Probability:** MEDIUM
**Impact:** HIGH
**Severity:** HIGH

**Analysis:** Several Debian dependencies may not have direct RHEL equivalents:
- Some development libraries may only be in EPEL or CRB
- EPEL/CRB may have different versions than Debian
- Some packages may require compilation from source
- Bazel itself is not in official RHEL repos (requires Copr or manual install)

**Mitigation Strategies:**
1. Create complete dependency mapping before coding begins
2. Test install all dependencies on clean RHEL 10 system
3. Identify any missing packages early
4. Create contingency plan for building dependencies from source if needed
5. Document all third-party repository requirements

**Timeline Impact:** Could add 1-2 weeks if dependencies need to be built from source.

#### RISK 3: Init Script to Systemd Conversion Complexity
**Probability:** MEDIUM
**Impact:** MEDIUM
**Severity:** MEDIUM

**Analysis:** The 371-line init script has complex logic:
- Multiple network configuration scenarios
- Conditional logic based on configuration variables
- ebtables and iptables manipulation
- Docker environment detection
- IPv6 handling

Converting this to systemd while maintaining all functionality is non-trivial.

**Mitigation Strategies:**
1. Break conversion into phases (basic first, then full functionality)
2. Create comprehensive test suite for all configuration scenarios
3. Extract complex logic into separate scripts called by systemd
4. Test with multiple num_cvd_accounts values (1, 10, 64, 128)
5. Test both bridged and non-bridged modes

**Timeline Impact:** Could add 1 week if not properly scoped.

### 6.2 Medium Risk Areas

#### RISK 4: Bazel Build on RHEL
**Probability:** MEDIUM
**Impact:** MEDIUM
**Severity:** MEDIUM

**Analysis:** Bazel builds are complex and may have RHEL-specific issues:
- Compiler flag compatibility (RPM optflags vs Bazel defaults)
- Cache behavior differences
- Symlink handling in spec file
- Source tarball creation

**Mitigation:** Test Bazel build on RHEL 10 early, verify all compiler flags work.

#### RISK 5: Firewalld vs iptables Detection
**Probability:** LOW
**Impact:** MEDIUM
**Severity:** LOW

**Analysis:** RHEL systems may have firewalld disabled or iptables installed separately. Detection logic must be robust.

**Mitigation:** Test on systems with firewalld enabled, disabled, and not installed.

#### RISK 6: Architecture-Specific Builds
**Probability:** LOW
**Impact:** MEDIUM
**Severity:** LOW

**Analysis:** Supporting both x86_64 and aarch64 requires:
- Different GRUB packages
- Different Bazel output paths
- Different QEMU dependencies

**Mitigation:** Test builds on both architectures early in development.

### 6.3 Low Risk Areas

#### RISK 7: Documentation Creation
**Probability:** LOW
**Impact:** LOW
**Severity:** LOW

Documentation is straightforward and low risk.

#### RISK 8: CI/CD Setup
**Probability:** LOW
**Impact:** LOW
**Severity:** LOW

Adding GitHub Actions workflows is well-understood and low risk.

### 6.4 Overall Risk Level

**Project Risk:** MEDIUM-HIGH

The project is feasible but has significant risks in SELinux and dependency management. Recommend:
- Early prototyping of SELinux policies
- Complete dependency verification before implementation
- Phased rollout (permissive SELinux first, then enforcing)

---

## 7. Recommendations

### 7.1 Critical Actions Before Implementation

1. **Complete Dependency Mapping** (1-2 days)
   - Extract all dependencies from base/debian/control and frontend/debian/control
   - Map each to RHEL equivalent
   - Verify availability in RHEL 10, EPEL, and CRB repositories
   - Test install on clean RHEL 10 system
   - Document any missing dependencies

2. **SELinux Scope Revision** (2-3 days)
   - Expand SELinux design section with realistic complexity
   - Create prototype SELinux policy for cuttlefish-host-resources
   - Test prototype on RHEL 10 with SELinux enforcing
   - Estimate actual effort required (likely 2-4 weeks)
   - Consider phased approach (permissive → enforcing)

3. **Task Reordering** (1 day)
   - Move SELinux tasks before build system creation
   - Move .rpmlintrc creation before first use
   - Fix task dependencies

4. **Version Management Strategy** (1 day)
   - Decide: VERSION file vs portable changelog parsing
   - Implement chosen approach
   - Test on both Debian and RHEL systems

### 7.2 Design Document Revisions

**Priority 1 (Must Fix):**
1. Expand SELinux section with complete policy structure
2. Fix firewalld zone detection logic
3. Correct version extraction to be portable
4. Add udev rules handling details
5. Specify complete Go build flags for RHEL compliance

**Priority 2 (Should Fix):**
1. Add systemd unit hardening options
2. Clarify nginx configuration location for RHEL
3. Add missing dependency installation script details
4. Document RPM naming and versioning conventions
5. Add Mock build environment usage

**Priority 3 (Nice to Have):**
1. Add diagrams for service startup flow
2. Expand error handling for each component
3. Add performance considerations
4. Document resource requirements (memory, disk, CPU)

### 7.3 Requirements Document Revisions

**Priority 1 (Must Fix):**
1. Clarify tap interface count in Requirement 3.2
2. Expand SELinux requirements in Requirement 12
3. Add firewalld detection criteria to Requirement 3.4
4. Add kernel module loading to Requirement 3

**Priority 2 (Should Fix):**
1. Add detailed Bazel dependency requirements to Requirement 2.1a
2. Add ebtables requirement for network filtering
3. Add package distribution requirement (Requirement 13)
4. Add architecture detection requirement to Requirement 2

### 7.4 Tasks Document Revisions

**Priority 1 (Must Fix):**
1. Move Task 9 (SELinux) before Task 8 (build system)
2. Fix version extraction in Task 8.2 to be portable
3. Expand Task 3.2 (setup-host-resources.sh) into more granular subtasks
4. Add test environment provisioning task before Task 17

**Priority 2 (Should Fix):**
1. Move Task 14.1 (.rpmlintrc) before Task 10
2. Add architecture-specific Bazel handling to Task 4.4
3. Add OS version detection to Task 8.1 for repository names
4. Expand Task 11.4 (troubleshooting) coverage
5. Add dependency mapping verification to Task 2

**Priority 3 (Should Add):**
1. Add RPM signing tasks (Task 23)
2. Add repository metadata generation tasks (Task 24)
3. Add migration path testing tasks (Task 25)
4. Add test artifact preparation tasks

### 7.5 Implementation Approach Recommendations

**Phased Rollout:**

**Phase 1: Minimal Viable Package (4-6 weeks)**
- Focus on cuttlefish-base package only
- SELinux in permissive mode (document policies needed)
- Basic systemd units without full hardening
- Manual build process (no full CI yet)
- x86_64 architecture only
- **Goal:** Prove RHEL packaging is viable

**Phase 2: Complete Packages (4-6 weeks)**
- All 6 packages
- Full systemd integration with hardening
- Both x86_64 and aarch64
- Automated build scripts
- Basic CI integration
- **Goal:** Feature-complete packaging

**Phase 3: Production Ready (4-6 weeks)**
- SELinux enforcing mode with complete policies
- Full CI/CD pipeline with all test scenarios
- Repository publication
- Complete documentation
- Migration tools
- **Goal:** Production deployment ready

**Total Estimated Timeline:** 12-18 weeks (3-4.5 months)

### 7.6 Resource Recommendations

**Required Resources:**
1. **RHEL 10 test systems** - Physical or VMs for testing (x86_64 and aarch64)
2. **SELinux expertise** - Consultant or Red Hat support for policy development
3. **Package repository hosting** - For publishing RPMs
4. **GPG signing key** - For package signing
5. **CI infrastructure** - GitHub Actions runners or self-hosted with RHEL 10

**Recommended Team:**
- 1 lead developer (RHEL packaging expert)
- 1 SELinux specialist (consultant acceptable)
- 1 testing engineer
- Part-time technical writer for documentation

---

## 8. Conclusion

### 8.1 Summary of Findings

The RHEL migration specifications are **comprehensive and well-structured**, demonstrating a solid understanding of the project requirements. However, **critical revisions are needed** in the following areas:

1. **SELinux complexity** - Significantly underestimated; requires major design expansion
2. **Task sequencing** - Several tasks are out of order, creating build dependencies issues
3. **Technical accuracy** - Multiple technical details need correction (firewalld zones, version extraction, Go build flags)
4. **Completeness** - Missing tasks for test environment, repository creation, and dependency verification

### 8.2 Feasibility Assessment

**Question: Is this migration feasible?**
**Answer: YES, with modifications**

The migration is technically feasible but will require:
- More time than initially estimated (especially for SELinux)
- Expert consultation for SELinux policy development
- Thorough dependency verification before implementation
- Phased approach rather than all-at-once implementation

### 8.3 Readiness for Implementation

**Current Status: ⚠️ NOT READY**

**Blocking Issues:**
1. SELinux design must be expanded and validated
2. Task ordering must be corrected
3. Complete dependency mapping must be created
4. Version extraction portability must be resolved

**Estimated Time to Ready:** 1-2 weeks of specification revision

**Action Items Before Implementation:**
- [ ] Revise SELinux section of design document
- [ ] Reorder tasks to fix dependencies
- [ ] Create complete Debian→RHEL dependency mapping
- [ ] Implement portable version extraction
- [ ] Prototype SELinux policies on test system
- [ ] Validate all dependencies available on RHEL 10

### 8.4 Final Recommendation

**RECOMMENDATION: REVISE SPECIFICATIONS BEFORE PROCEEDING**

The specifications provide an excellent foundation but require revision in critical areas. Proceeding with implementation using the current specifications will likely result in:
- Significant rework when SELinux issues are encountered
- Build failures due to task ordering problems
- Delays due to missing dependencies

**Recommended Next Steps:**
1. Address Priority 1 revisions in all three documents (1-2 weeks)
2. Conduct dependency availability verification (2-3 days)
3. Create SELinux prototype and validate approach (1 week)
4. Re-assess specifications after revisions
5. Begin Phase 1 implementation (MVP)

With these revisions, the project has a high likelihood of success and will deliver functional RHEL 10 packages for the Cuttlefish project.

---

## Appendix A: Issue Summary Table

| ID | Severity | Document | Issue | Status |
|----|----------|----------|-------|--------|
| 1.1 | MEDIUM | requirements.md | Incorrect tap interface count | Fix |
| 1.2 | HIGH | requirements.md | Missing SELinux context requirements | Add |
| 1.3 | MEDIUM | requirements.md | Missing firewalld vs iptables requirement | Add |
| 1.4 | MEDIUM | requirements.md | Insufficient Bazel dependency detail | Expand |
| 1.5 | HIGH | requirements.md | Missing kernel module loading requirement | Add |
| 1.6 | MEDIUM | requirements.md | Missing ebtables requirement | Add |
| 2.1 | HIGH | design.md | SELinux complexity underestimated | Revise |
| 2.2 | MEDIUM | design.md | Firewalld zone assumptions | Fix |
| 2.3 | MEDIUM | design.md | Bazel output path assumptions | Fix |
| 2.4 | MEDIUM | design.md | Go build flags incomplete | Expand |
| 2.5 | MEDIUM | design.md | Version extraction not portable | Fix |
| 2.6 | MEDIUM | design.md | RPM spec %prep section unclear | Clarify |
| 2.7 | MEDIUM | design.md | Missing systemd hardening | Add |
| 2.8 | LOW | design.md | Property 11 incorrect | Fix |
| 2.9 | MEDIUM | design.md | Missing udev rules handling | Add |
| 2.10 | LOW | design.md | Nginx configuration location | Specify |
| 3.1 | HIGH | tasks.md | Task ordering - SELinux too late | Reorder |
| 3.2 | MEDIUM | tasks.md | Version extraction uses Debian tool | Fix |
| 3.3 | LOW | tasks.md | .rpmlintrc created too late | Reorder |
| 3.4 | LOW | tasks.md | Missing -devel suffix mapping | Add |
| 3.5 | HIGH | tasks.md | setup-host-resources.sh complexity | Expand |
| 3.6 | MEDIUM | tasks.md | Missing architecture-specific Bazel handling | Add |
| 3.7 | MEDIUM | tasks.md | Repository names vary by version | Fix |
| 3.8 | MEDIUM | tasks.md | %{_libdir} vs /usr/lib clarification | Clarify |
| 3.9 | LOW | tasks.md | Insufficient troubleshooting coverage | Expand |
| 3.10 | MEDIUM | tasks.md | Missing version management task | Add |
| 3.11 | MEDIUM | tasks.md | Missing test data preparation | Add |
| 3.12 | MEDIUM | tasks.md | Test system provisioning assumptions | Add |

**Total Issues:** 30
**Critical/High:** 7
**Medium:** 18
**Low:** 5

---

## Appendix B: Codebase Files Reviewed

### Debian Packaging Files
- `base/debian/changelog` - Version history
- `base/debian/control` - Package definitions (4 packages)
- `base/debian/rules` - Build rules (Bazel integration)
- `base/debian/cuttlefish-base.install` - File installation map
- `base/debian/cuttlefish-base.cuttlefish-host-resources.init` - Init script (371 lines)
- `base/debian/cuttlefish-base.cuttlefish-host-resources.default` - Configuration
- `base/debian/cuttlefish-base.postinst` - Post-installation script
- `base/debian/cuttlefish-base.udev` - Udev rules
- `base/debian/cuttlefish-integration.install` - Integration package files
- `base/debian/cuttlefish-integration.udev` - Integration udev rules
- `base/debian/cuttlefish-integration.postinst` - Post-install script
- `base/debian/cuttlefish-defaults.install` - Defaults package files

### Frontend Packaging Files
- `frontend/debian/changelog` - Frontend version history
- `frontend/debian/control` - Frontend package definitions (2 packages)
- `frontend/debian/rules` - Frontend build rules (Go builds)
- `frontend/debian/cuttlefish-user.install` - User package files
- `frontend/debian/cuttlefish-user.cuttlefish-operator.init` - Operator init (151 lines)
- `frontend/debian/cuttlefish-user.cuttlefish-operator.default` - Operator config
- `frontend/debian/cuttlefish-user.postinst` - User post-install
- `frontend/debian/cuttlefish-orchestration.install` - Orchestration files
- `frontend/debian/cuttlefish-orchestration.cuttlefish-host_orchestrator.init` - Orchestrator init (170 lines)
- `frontend/debian/cuttlefish-orchestration.cuttlefish-host_orchestrator.default` - Orchestrator config
- `frontend/debian/cuttlefish-orchestration.postinst` - Orchestration post-install

### Build Infrastructure
- `tools/buildutils/build_package.sh` - Package build script
- `tools/buildutils/build_packages.sh` - Multi-package build
- `tools/buildutils/installbazel.sh` - Bazel installation

### CI Infrastructure
- `.github/workflows/` - GitHub Actions (9 workflow files)
- `.kokoro/presubmit.cfg` - Kokoro CI configuration
- `.kokoro/presubmit.sh` - Kokoro build script

### Bazel Files
- Multiple `WORKSPACE` files
- Multiple `BUILD.bazel` files throughout codebase

**Total Files Reviewed:** 35+ files

---

*End of Assessment*
