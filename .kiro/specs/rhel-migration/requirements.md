# Requirements Document

## Introduction

This document specifies the requirements for adding RHEL/RPM support to the Android Cuttlefish project. The project currently supports only Debian/Ubuntu systems through .deb packages. This migration will add parallel support for RHEL 10, CentOS Stream 10, and Fedora 43 through .rpm packages, while maintaining existing Debian support.

## Glossary

- **Cuttlefish System**: Android Virtual Device (AVD) system for running Android in virtual machines
- **RHEL**: Red Hat Enterprise Linux operating system
- **RHEL 10**: The target version of Red Hat Enterprise Linux for this migration
- **RPM**: Red Hat Package Manager, the package format used by RHEL-based systems
- **DEB**: Debian package format used by Debian/Ubuntu systems
- **Spec File**: RPM package specification file that defines how to build and install an RPM package
- **Systemd**: System and service manager used by modern Linux distributions
- **LSB Init Script**: Legacy System V init script format
- **Bazel**: Build system used by Cuttlefish for C++ components
- **Go**: Programming language used for Cuttlefish frontend services
- **EPEL**: Extra Packages for Enterprise Linux repository
- **CRB**: CodeReady Builder repository for RHEL
- **Copr**: Community-maintained package repository system for Fedora/RHEL
- **cvdnetwork Group**: System group for Cuttlefish network access
- **Host Orchestrator Service**: Service that manages Cuttlefish device instances
- **Operator Service**: WebRTC signaling server for multi-device flows
- **Package Manager**: The dnf or yum tool used for installing RPM packages on RHEL systems
- **Build System**: The collection of scripts and tools that compile and package Cuttlefish components

## Requirements

### Requirement 1

**User Story:** As a RHEL system administrator, I want to install Cuttlefish packages using dnf, so that I can deploy Android virtual devices on RHEL 10 systems.

#### Acceptance Criteria

1. WHEN a user runs `dnf install cuttlefish-base` on RHEL 10 THEN the Package Manager SHALL resolve all dependencies and install the package successfully
2. WHEN the cuttlefish-base package is installed THEN the Package Manager SHALL create the cvdnetwork Group
3. WHEN the cuttlefish-base package is installed THEN the Package Manager SHALL install all required binaries to /usr/lib/cuttlefish-common/bin/
4. WHEN the cuttlefish-base package is installed THEN the Package Manager SHALL create a symlink from /usr/bin/cvd to the installed binary
5. WHEN the cuttlefish-base package is installed THEN the Package Manager SHALL install and enable the cuttlefish-host-resources systemd service

### Requirement 2

**User Story:** As a developer, I want to build RPM packages from source on RHEL 10 systems, so that I can create custom builds or contribute to the project.

#### Acceptance Criteria

1. WHEN a developer runs the build script on RHEL 10 THEN the Build System SHALL install all build dependencies from EPEL and CRB repositories
2. WHEN the build script checks for Bazel THEN the Build System SHALL verify compatibility with the version specified in .bazelversion
3. WHEN Bazel is not installed THEN the Build System SHALL attempt to install Bazelisk as the primary method
4. WHEN Bazelisk is unavailable THEN the Build System SHALL fall back to the vbatts/bazel Copr repository
5. WHEN all Bazel installation methods fail THEN the Build System SHALL exit with a clear error message and manual installation instructions
6. WHEN the build process executes THEN the Build System SHALL compile all C++ components using Bazel with RPM-compliant compiler flags
7. WHEN the build process executes THEN the Build System SHALL compile all Go components with position-independent executable flags
8. WHEN the build completes THEN the Build System SHALL produce six RPM packages matching the existing Debian package structure
9. WHEN the build process executes on aarch64 THEN the Build System SHALL use aarch64-specific dependencies
10. WHEN the build process executes on x86_64 THEN the Build System SHALL use x86_64-specific dependencies

### Requirement 3

**User Story:** As a system administrator, I want Cuttlefish services to start automatically using systemd, so that the virtual device infrastructure is ready after system boot.

#### Acceptance Criteria

1. WHEN the cuttlefish-host-resources service starts THEN the Cuttlefish System SHALL create network bridges cvd-ebr and cvd-wbr
2. WHEN the cuttlefish-host-resources service starts THEN the Cuttlefish System SHALL create exactly 4 tap interfaces per configured CVD account (cvd-etap-XX, cvd-mtap-XX, cvd-wtap-XX, cvd-wifiap-XX)
3. WHEN the cuttlefish-host-resources service starts THEN the Cuttlefish System SHALL start dnsmasq DHCP servers on both bridges
4. WHEN the cuttlefish-host-resources service starts THEN the Cuttlefish System SHALL load required kernel modules (bridge, vhost-net, vhost-vsock)
5. WHEN firewalld is active THEN the Cuttlefish System SHALL use firewall-cmd for NAT configuration
6. WHEN firewalld is inactive THEN the Cuttlefish System SHALL use iptables for NAT configuration
7. WHEN the service detects the firewall configuration THEN the Cuttlefish System SHALL verify the method used via systemctl is-active firewalld
8. WHEN the cuttlefish-host-resources service starts and bridge_interface is configured THEN the Cuttlefish System SHALL configure ebtables-legacy for broute operations
9. WHEN the Operator Service starts THEN the Cuttlefish System SHALL generate TLS certificates if they do not exist
10. WHEN any Cuttlefish service fails THEN Systemd SHALL restart the service automatically after 5 seconds

### Requirement 4

**User Story:** As a package maintainer, I want RPM spec files that follow RHEL packaging guidelines, so that packages can be distributed through official and community repositories.

#### Acceptance Criteria

1. WHEN an RPM spec file is created THEN the Spec File SHALL include all required sections: Name, Version, Release, Summary, License, URL, Source, BuildRequires, Requires, %description, %prep, %build, %install, %files, and %changelog
2. WHEN an RPM spec file defines dependencies THEN the Spec File SHALL map all Debian package names to their RHEL equivalents
3. WHEN an RPM spec file installs files THEN the Spec File SHALL use appropriate macros for systemd units, configuration files, and documentation
4. WHEN an RPM package is built THEN the Build System SHALL include proper file permissions and ownership in the package
5. WHEN an RPM package includes systemd services THEN the Spec File SHALL use systemd RPM macros for service management

### Requirement 5

**User Story:** As a system administrator, I want service configuration files in RHEL-standard locations, so that I can manage Cuttlefish services using familiar RHEL conventions.

#### Acceptance Criteria

1. WHEN service configuration files are installed THEN the Package Manager SHALL place them in /etc/sysconfig/ instead of /etc/default/
2. WHEN systemd unit files are installed THEN the Package Manager SHALL place them in /usr/lib/systemd/system/
3. WHEN udev rules are installed THEN the Package Manager SHALL place them in /usr/lib/udev/rules.d/
4. WHEN kernel module configuration is installed THEN the Package Manager SHALL place files in /etc/modules-load.d/ and /etc/modprobe.d/
5. WHEN configuration files are marked as config files THEN the Package Manager SHALL preserve user modifications during package upgrades

### Requirement 6

**User Story:** As a developer, I want comprehensive documentation for RHEL deployment, so that I can understand the differences from Debian and troubleshoot issues.

#### Acceptance Criteria

1. WHEN documentation is created THEN the Cuttlefish System SHALL include installation instructions for RHEL 10
2. WHEN documentation is created THEN the Cuttlefish System SHALL document all required repository configurations (EPEL, CRB, and vbatts/bazel Copr for Bazel)
3. WHEN documentation is created THEN the Cuttlefish System SHALL explain package dependency mappings from Debian to RHEL
4. WHEN documentation is created THEN the Cuttlefish System SHALL provide troubleshooting guides for common RHEL-specific issues including SELinux and firewalld
5. WHEN documentation is created THEN the Cuttlefish System SHALL include development setup instructions for building RPM packages

### Requirement 7

**User Story:** As a CI/CD engineer, I want automated build and test infrastructure for RHEL packages, so that we can ensure quality and catch regressions.

#### Acceptance Criteria

1. WHEN CI configuration is created THEN the Build System SHALL include build jobs for RHEL 10
2. WHEN CI builds execute THEN the Build System SHALL build all six RPM packages
3. WHEN CI tests execute THEN the Build System SHALL verify package installation on clean RHEL systems
4. WHEN CI tests execute THEN the Build System SHALL verify service startup and network configuration
5. WHEN CI tests execute THEN the Build System SHALL verify that a Cuttlefish device can boot successfully

### Requirement 8

**User Story:** As a system administrator, I want user and group management to work correctly on RHEL, so that Cuttlefish services run with appropriate permissions.

#### Acceptance Criteria

1. WHEN the cuttlefish-base package is installed THEN the Package Manager SHALL create the cvdnetwork Group as a system group with GID less than 1000
2. WHEN the cuttlefish-user package is installed THEN the Package Manager SHALL create the _cutf-operator system user with /sbin/nologin shell
3. WHEN the cuttlefish-orchestration package is installed THEN the Package Manager SHALL create the httpcvd system user
4. WHEN service users are created THEN the Package Manager SHALL add them to the cvdnetwork Group
5. WHEN packages are removed THEN the Package Manager SHALL preserve all system users and groups created during installation

### Requirement 9

**User Story:** As a developer, I want the build system to support both Debian and RHEL packaging, so that I can maintain both package formats from a single codebase.

#### Acceptance Criteria

1. WHEN the repository structure is modified THEN the Build System SHALL maintain existing debian/ directories unchanged
2. WHEN RHEL packaging is added THEN the Build System SHALL create parallel rhel/ directories for RPM spec files
3. WHEN build scripts are created THEN the Build System SHALL detect the operating system and use the appropriate packaging format
4. WHEN version numbers are updated THEN the Build System SHALL maintain consistency between Debian and RHEL packages
5. WHEN files are installed THEN both packaging systems SHALL install files to the same locations (except for /etc/default vs /etc/sysconfig)

### Requirement 10

**User Story:** As a system administrator, I want package upgrades to preserve my configuration changes, so that I don't lose custom settings when updating Cuttlefish.

#### Acceptance Criteria

1. WHEN configuration files are marked with %config(noreplace) THEN the Package Manager SHALL create .rpmnew files for new versions instead of overwriting
2. WHEN systemd service files are updated THEN the Package Manager SHALL reload the systemd daemon automatically
3. WHEN services are running during upgrade THEN the Package Manager SHALL restart services with the new binaries
4. WHEN packages are upgraded THEN the Package Manager SHALL preserve user and group memberships
5. WHEN packages are upgraded THEN the Cuttlefish System SHALL maintain network bridge and tap interface configurations

### Requirement 11

**User Story:** As a developer, I want existing project tests to continue passing after RHEL migration changes, so that I can ensure backward compatibility and prevent regressions.

#### Acceptance Criteria

1. WHEN RHEL packaging changes are implemented THEN the Build System SHALL execute all existing test suites
2. WHEN existing tests are executed THEN the Build System SHALL report the same pass rate as before RHEL changes
3. WHEN test failures occur THEN the Build System SHALL identify whether failures are due to RHEL changes or pre-existing issues
4. WHEN Debian package builds are executed THEN the Build System SHALL produce packages identical to pre-migration builds
5. WHEN Debian systems run Cuttlefish THEN the Cuttlefish System SHALL maintain all existing functionality without degradation

### Requirement 12

**User Story:** As a system administrator, I want Cuttlefish to work with SELinux in enforcing mode, so that I can maintain security compliance on RHEL systems.

#### Acceptance Criteria

1. WHEN packages are installed THEN the Package Manager SHALL set correct SELinux file contexts on all binaries, services, and configuration files
2. WHEN binaries are installed THEN the Cuttlefish System SHALL apply appropriate SELinux file contexts to /usr/lib/cuttlefish-common/bin/ and /var/lib/cuttlefish-common/
3. WHEN runtime directories are created THEN the Cuttlefish System SHALL apply appropriate SELinux contexts to /run/cuttlefish/
4. WHEN certificates are generated THEN the Cuttlefish System SHALL apply appropriate SELinux contexts to /etc/cuttlefish-common/operator/cert/
5. WHEN network services bind to ports THEN SELinux SHALL permit the bindings via port labeling or policy
6. WHEN administrators need flexibility THEN SELinux boolean policies SHALL allow selective relaxation of restrictions
7. WHEN services access KVM and vhost devices THEN SELinux SHALL permit access to /dev/kvm, /dev/vhost-net, and /dev/vhost-vsock
8. WHEN services start with SELinux in enforcing mode THEN all operations SHALL succeed without AVC denials
9. WHEN custom SELinux policies are required THEN packages SHALL include compiled policy modules (.pp files)
10. WHEN SELinux denials occur THEN documentation SHALL provide troubleshooting steps including audit2allow usage
11. WHEN network operations are performed THEN SELinux SHALL permit network bridge creation, tap interface creation, and iptables/firewalld configuration

### Requirement 13

**User Story:** As a RHEL administrator, I want to install Cuttlefish from standard package repositories, so that I can use familiar package management workflows.

#### Acceptance Criteria

1. WHEN packages are built THEN the Build System SHALL publish them to a public repository
2. WHEN documentation is created THEN the Cuttlefish System SHALL include repository configuration instructions
3. WHEN packages are updated THEN the Build System SHALL refresh repository metadata automatically
