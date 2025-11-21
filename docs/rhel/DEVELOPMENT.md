# Cuttlefish Development Guide for RHEL-based Systems

This guide provides instructions for building Cuttlefish packages from source on RHEL 10, CentOS Stream 10, and Fedora 43.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Build Environment Setup](#build-environment-setup)
- [Building RPM Packages](#building-rpm-packages)
- [Local Testing](#local-testing)
- [Development Workflow](#development-workflow)
- [Debugging Build Issues](#debugging-build-issues)
- [SELinux Policy Development](#selinux-policy-development)
- [Contributing](#contributing)

## Prerequisites

### System Requirements

- **Operating System**: One of the following:
  - RHEL 10 (recommended)
  - CentOS Stream 10
  - Fedora 43
  - RHEL 9 (deprecated, upgrade recommended)

- **Hardware**:
  - CPU: x86_64 or aarch64
  - RAM: Minimum 16GB (32GB recommended for parallel builds)
  - Disk: Minimum 50GB free space for build artifacts
  - Network: Internet connection for downloading dependencies

- **Privileges**: Root or sudo access required for installing dependencies

### Required Knowledge

- Basic understanding of RPM packaging
- Familiarity with Bazel build system
- Understanding of systemd service management
- Knowledge of SELinux (for policy development)

## Build Environment Setup

### Step 1: Clone Repository

```bash
# Clone Cuttlefish repository
git clone https://github.com/google/android-cuttlefish.git
cd android-cuttlefish
```

### Step 2: Install Build Dependencies

Use the automated dependency installation script:

```bash
# Run dependency installation script
sudo ./tools/buildutils/install_rhel10_deps.sh
```

This script will:
1. Detect your OS type and version
2. Enable required repositories (EPEL, CRB for RHEL/CentOS Stream)
3. Install all build dependencies
4. Install Bazel via Bazelisk or Copr repository

**What gets installed:**

**For RHEL 10 / CentOS Stream 10:**
- Development tools: `gcc`, `gcc-c++`, `make`, `cmake`, `ninja-build`
- Build systems: `rpm-build`, `rpmdevtools`, `rpmlint`
- SELinux tools: `selinux-policy-devel`, `checkpolicy`
- Dependencies from EPEL and CRB repositories
- Bazel (via Bazelisk or Copr)

**For Fedora 43:**
- Same as above, but packages come from default Fedora repositories
- No EPEL or CRB configuration needed

### Step 3: Verify Installation

```bash
# Check Bazel is installed
bazel version

# Check RPM build tools
rpmbuild --version

# Check SELinux tools
checkmodule -V

# Verify repository setup (RHEL/CentOS Stream only)
sudo dnf repolist | grep -E "(epel|crb)"
```

### Step 4: Set Up RPM Build Environment

The build scripts automatically create the RPM build directory structure, but you can verify it:

```bash
# RPM build tree structure
ls -la ~/rpmbuild/
# Expected directories:
# BUILD/      - Where packages are built
# RPMS/       - Output binary RPM packages
# SOURCES/    - Source tarballs and patches
# SPECS/      - RPM spec files
# SRPMS/      - Source RPM packages
```

## Building RPM Packages

### Quick Start: Build All Packages

```bash
# Build all 6 Cuttlefish RPM packages
./tools/buildutils/build_rpm_packages.sh
```

This will:
1. Verify OS type and version
2. Extract package versions from debian/changelog
3. Create source tarballs
4. Compile SELinux policy modules
5. Build all RPM packages
6. Run rpmlint validation
7. Copy packages to `rpm-packages/` directory

**Expected output directory:**
```
rpm-packages/
├── cuttlefish-base-1.34.0-1.el10.x86_64.rpm
├── cuttlefish-integration-1.34.0-1.el10.x86_64.rpm
├── cuttlefish-defaults-1.34.0-1.el10.x86_64.rpm
├── cuttlefish-user-1.34.0-1.el10.x86_64.rpm
├── cuttlefish-orchestration-1.34.0-1.el10.x86_64.rpm
├── cuttlefish-common-1.34.0-1.el10.noarch.rpm
└── *.src.rpm (source packages)
```

### Build Individual Packages

To build specific packages, use rpmbuild directly:

```bash
# Build base package only
rpmbuild -ba ~/rpmbuild/SPECS/cuttlefish-base.spec

# Build user package only
rpmbuild -ba ~/rpmbuild/SPECS/cuttlefish-user.spec

# Build orchestration package only
rpmbuild -ba ~/rpmbuild/SPECS/cuttlefish-orchestration.spec
```

### Build Options

**Skip specific steps:**

```bash
# Skip SELinux policy compilation (if already compiled)
# Edit build_rpm_packages.sh and comment out compile_selinux_policies

# Skip rpmlint validation
# Edit build_rpm_packages.sh and comment out run_rpmlint
```

**Customize build flags:**

```bash
# Set custom Bazel flags
export BAZEL_BUILD_FLAGS="--compilation_mode=dbg"

# Set custom RPM flags
export RPM_BUILD_FLAGS="--define '_smp_mflags -j4'"

# Run build
./tools/buildutils/build_rpm_packages.sh
```

### Clean Build

```bash
# Remove all build artifacts
rm -rf ~/rpmbuild/BUILD/*
rm -rf ~/rpmbuild/BUILDROOT/*
rm -rf rpm-packages/

# Clean Bazel cache
bazel clean --expunge

# Rebuild from scratch
./tools/buildutils/build_rpm_packages.sh
```

## Local Testing

### Testing with rpmbuild

**Check package contents:**

```bash
# List files in package
rpm -qlp rpm-packages/cuttlefish-base-*.rpm

# Show package metadata
rpm -qip rpm-packages/cuttlefish-base-*.rpm

# Show package dependencies
rpm -qRp rpm-packages/cuttlefish-base-*.rpm

# Show package scripts
rpm -qp --scripts rpm-packages/cuttlefish-base-*.rpm
```

**Validate with rpmlint:**

```bash
# Validate all packages
rpmlint rpm-packages/*.rpm

# Validate specific package
rpmlint rpm-packages/cuttlefish-base-*.rpm

# Use project .rpmlintrc configuration
cp .rpmlintrc ~/
rpmlint rpm-packages/*.rpm
```

### Testing with Mock (Recommended)

Mock provides clean-room RPM builds in isolated chroot environments.

**Install Mock:**

```bash
# Install mock
sudo dnf install -y mock

# Add user to mock group
sudo usermod -a -G mock $USER

# Log out and log back in for group changes to take effect
```

**Build with Mock:**

```bash
# Build for RHEL 10
mock -r rhel-10-x86_64 rpm-packages/*.src.rpm

# Build for CentOS Stream 10
mock -r centos-stream-10-x86_64 rpm-packages/*.src.rpm

# Build for Fedora 43
mock -r fedora-43-x86_64 rpm-packages/*.src.rpm

# Output packages are in:
# /var/lib/mock/*/result/
```

**Mock advantages:**
- Clean environment ensures reproducible builds
- Tests dependency resolution
- Verifies package doesn't require build-time-only dependencies
- Catches missing BuildRequires

### Testing Installation

**Test install on local system:**

```bash
# Install meta-package (installs all components)
sudo dnf install rpm-packages/cuttlefish-common-*.rpm

# Or install individual packages
sudo dnf install \
    rpm-packages/cuttlefish-base-*.rpm \
    rpm-packages/cuttlefish-integration-*.rpm \
    rpm-packages/cuttlefish-defaults-*.rpm \
    rpm-packages/cuttlefish-user-*.rpm \
    rpm-packages/cuttlefish-orchestration-*.rpm
```

**Verify installation:**

```bash
# Check services are installed
sudo systemctl status cuttlefish-host-resources
sudo systemctl status cuttlefish-operator
sudo systemctl status cuttlefish-host_orchestrator

# Check binaries are accessible
which cvd
cvd version

# Check SELinux modules are installed
sudo semodule -l | grep cuttlefish

# Check network setup
ip link show | grep cvd
```

**Test service startup:**

```bash
# Start host resources
sudo systemctl start cuttlefish-host-resources

# Check for errors
sudo journalctl -u cuttlefish-host-resources -n 50

# Verify network bridges created
ip addr show cvd-ebr
ip addr show cvd-wbr

# Check tap interfaces
ip link show | grep cvd-.*tap
```

### Testing in Container (Quick Validation)

```bash
# Create test container (Fedora 43 example)
podman run -it --rm \
    -v $(pwd)/rpm-packages:/packages:ro \
    fedora:43 bash

# Inside container:
dnf install -y /packages/cuttlefish-common-*.rpm

# Verify package metadata
rpm -qa | grep cuttlefish
rpm -V cuttlefish-base
```

### Automated Verification

Use the provided verification script:

```bash
# Run full verification (build + validate)
./tools/buildutils/verify_rhel_build.sh

# Or verify existing packages without rebuilding
./tools/buildutils/verify_rhel_build.sh --skip-build
```

See [CHECKPOINT_VERIFICATION.md](CHECKPOINT_VERIFICATION.md) for detailed verification procedures.

## Development Workflow

### Making Changes to Packages

#### Modifying Package Specs

1. **Edit spec file:**
   ```bash
   vi base/rhel/cuttlefish-base.spec
   ```

2. **Update changelog:**
   ```bash
   # Add entry to base/debian/changelog
   # The version will be extracted from here
   ```

3. **Rebuild package:**
   ```bash
   ./tools/buildutils/build_rpm_packages.sh
   ```

4. **Test changes:**
   ```bash
   sudo dnf reinstall rpm-packages/cuttlefish-base-*.rpm
   ```

#### Modifying Systemd Units

1. **Edit systemd unit file:**
   ```bash
   vi base/rhel/cuttlefish-host-resources.service
   ```

2. **Rebuild package:**
   ```bash
   ./tools/buildutils/build_rpm_packages.sh
   ```

3. **Test updated service:**
   ```bash
   sudo dnf reinstall rpm-packages/cuttlefish-base-*.rpm
   sudo systemctl daemon-reload
   sudo systemctl restart cuttlefish-host-resources
   sudo journalctl -u cuttlefish-host-resources -f
   ```

#### Modifying Wrapper Scripts

1. **Edit script:**
   ```bash
   vi base/rhel/setup-host-resources.sh
   ```

2. **Test script directly (before packaging):**
   ```bash
   bash -n base/rhel/setup-host-resources.sh  # Syntax check
   sudo bash -x base/rhel/setup-host-resources.sh  # Debug run
   ```

3. **Package and test:**
   ```bash
   ./tools/buildutils/build_rpm_packages.sh
   sudo dnf reinstall rpm-packages/cuttlefish-base-*.rpm
   ```

### Iterative Development

**Quick iteration cycle:**

```bash
# 1. Make code changes
vi base/rhel/setup-host-resources.sh

# 2. Rebuild only affected package
rpmbuild -ba ~/rpmbuild/SPECS/cuttlefish-base.spec

# 3. Reinstall package
sudo dnf reinstall ~/rpmbuild/RPMS/x86_64/cuttlefish-base-*.rpm

# 4. Test changes
sudo systemctl restart cuttlefish-host-resources
sudo journalctl -u cuttlefish-host-resources -n 50
```

### Testing on Different Distributions

**Use containers for multi-distribution testing:**

```bash
# Test on RHEL 10 (requires subscription)
podman run -it --rm \
    -v $(pwd):/workspace \
    registry.access.redhat.com/ubi10/ubi bash

# Test on CentOS Stream 10
podman run -it --rm \
    -v $(pwd):/workspace \
    quay.io/centos/centos:stream10 bash

# Test on Fedora 43
podman run -it --rm \
    -v $(pwd):/workspace \
    fedora:43 bash
```

## Debugging Build Issues

### Common Build Failures

#### Bazel Build Fails

**Symptom:**
```
ERROR: Analysis of target failed
```

**Solutions:**

```bash
# 1. Clear Bazel cache
bazel clean --expunge

# 2. Verify Bazel version
bazel version
# Should match .bazelversion file

# 3. Check compiler flags
bazel build --verbose_failures //cuttlefish/package:cuttlefish-common

# 4. Reduce parallelism if out of memory
bazel build --jobs=2 --local_ram_resources=4096 //cuttlefish/package:cuttlefish-common
```

#### Missing Dependencies

**Symptom:**
```
Error: Package 'gflags-devel' not found
```

**Solutions:**

```bash
# 1. Verify repositories are enabled
sudo dnf repolist

# For RHEL/CentOS Stream, ensure EPEL and CRB are enabled
sudo dnf config-manager --set-enabled crb
sudo dnf install -y epel-release

# 2. Update repository metadata
sudo dnf clean all
sudo dnf makecache

# 3. Search for package
dnf search gflags-devel

# 4. Re-run dependency installation
sudo ./tools/buildutils/install_rhel10_deps.sh
```

#### SELinux Policy Compilation Fails

**Symptom:**
```
checkmodule: error: syntax error
```

**Solutions:**

```bash
# 1. Install SELinux development tools
sudo dnf install -y selinux-policy-devel checkpolicy

# 2. Manually compile to see detailed errors
cd base/rhel/selinux
make -f /usr/share/selinux/devel/Makefile cuttlefish_host_resources.pp

# 3. Check policy syntax
checkmodule -M -m -o /dev/null cuttlefish_host_resources.te

# 4. Verify policy version
sestatus | grep "Policy version"
```

#### RPM Build Errors

**Symptom:**
```
error: Bad exit status from /var/tmp/rpm-tmp.XXX (%install)
```

**Solutions:**

```bash
# 1. Check build log
tail -n 100 ~/rpmbuild/BUILD/cuttlefish-base-*/build.log

# 2. Manually run %install section
cd ~/rpmbuild/BUILD/cuttlefish-base-*/
# Copy %install commands from spec file and run manually

# 3. Check file permissions
ls -la ~/rpmbuild/BUILD/cuttlefish-base-*/

# 4. Verify BuildRoot is clean
rm -rf ~/rpmbuild/BUILDROOT/cuttlefish-base-*
```

### Enable Debug Mode

**Bazel debug build:**

```bash
# Build with debug symbols
export BAZEL_BUILD_FLAGS="--compilation_mode=dbg"
./tools/buildutils/build_rpm_packages.sh

# Or edit spec file:
%build
cd base
bazel build --compilation_mode=dbg //cuttlefish/package:cuttlefish-common
```

**RPM debug build:**

```bash
# Keep build artifacts
rpmbuild -ba --short-circuit ~/rpmbuild/SPECS/cuttlefish-base.spec

# Don't clean BUILD directory
# Edit spec file and remove %clean section
```

**Script debugging:**

```bash
# Add to wrapper scripts:
set -x  # Print commands as executed
set -e  # Exit on error
set -u  # Exit on undefined variable
```

### Checking Logs

```bash
# Build script logs
./tools/buildutils/build_rpm_packages.sh 2>&1 | tee build.log

# RPM build logs
tail -f ~/rpmbuild/BUILD/cuttlefish-base-*/build.log

# Mock build logs
tail -f /var/lib/mock/*/result/build.log

# Bazel build logs
bazel build --verbose_failures //cuttlefish/package:cuttlefish-common 2>&1 | tee bazel.log
```

## SELinux Policy Development

### Initial Policy Creation

SELinux policies are located in:
- `base/rhel/selinux/cuttlefish_host_resources.te`
- `frontend/rhel/selinux/cuttlefish_operator.te`
- `frontend/rhel/selinux/cuttlefish_orchestration.te`

**Policy structure:**

```
policy_module(cuttlefish_host_resources, 1.0.0)

# Type definitions
type cuttlefish_host_resources_t;
type cuttlefish_host_resources_exec_t;

# Domain transition
init_daemon_domain(cuttlefish_host_resources_t, cuttlefish_host_resources_exec_t)

# Permissions
# ... (allow rules)
```

### Iterative Policy Development

**Development workflow:**

1. **Start with permissive mode:**
   ```bash
   sudo semanage permissive -a cuttlefish_host_resources_t
   ```

2. **Run service and collect denials:**
   ```bash
   sudo systemctl start cuttlefish-host-resources
   sudo ausearch -m avc -ts recent | grep cuttlefish
   ```

3. **Generate policy additions:**
   ```bash
   sudo ausearch -m avc -ts recent | audit2allow -M mycuttlefish_additions
   cat mycuttlefish_additions.te
   ```

4. **Add rules to main policy:**
   ```bash
   vi base/rhel/selinux/cuttlefish_host_resources.te
   # Add necessary allow rules
   ```

5. **Recompile and test:**
   ```bash
   cd base/rhel/selinux
   make -f /usr/share/selinux/devel/Makefile cuttlefish_host_resources.pp
   sudo semodule -i cuttlefish_host_resources.pp
   sudo systemctl restart cuttlefish-host-resources
   ```

6. **Switch to enforcing when stable:**
   ```bash
   sudo semanage permissive -d cuttlefish_host_resources_t
   ```

### Testing SELinux Policies

```bash
# Check policy is loaded
sudo semodule -l | grep cuttlefish

# View policy details
sudo sesearch -A -s cuttlefish_host_resources_t

# Check file contexts
ls -lZ /usr/lib/cuttlefish-common/bin/setup-host-resources.sh

# Restore contexts if incorrect
sudo restorecon -Rv /usr/lib/cuttlefish-common

# View recent denials
sudo ausearch -m avc -ts recent | grep cuttlefish

# Check boolean settings
sudo getsebool -a | grep cuttlefish
```

See [SELINUX_INTEGRATION.md](SELINUX_INTEGRATION.md) for comprehensive SELinux documentation.

## Contributing

### Contribution Process

1. **Fork and clone repository:**
   ```bash
   # Fork on GitHub
   git clone https://github.com/YOUR_USERNAME/android-cuttlefish.git
   cd android-cuttlefish
   git remote add upstream https://github.com/google/android-cuttlefish.git
   ```

2. **Create feature branch:**
   ```bash
   git checkout -b rhel-feature-name
   ```

3. **Make changes following project guidelines:**
   - Follow existing code style
   - Update relevant documentation
   - Add tests if applicable
   - Ensure builds succeed on all target distributions

4. **Test changes thoroughly:**
   ```bash
   # Build packages
   ./tools/buildutils/build_rpm_packages.sh

   # Run verification
   ./tools/buildutils/verify_rhel_build.sh

   # Test on all target distributions
   # (RHEL 10, CentOS Stream 10, Fedora 43)
   ```

5. **Commit with descriptive messages:**
   ```bash
   git add .
   git commit -m "rhel: Add support for feature X

   - Modify cuttlefish-base.spec to include feature X
   - Update setup-host-resources.sh with new configuration
   - Add documentation to INSTALL.md

   Tested on RHEL 10, CentOS Stream 10, and Fedora 43."
   ```

6. **Push and create pull request:**
   ```bash
   git push origin rhel-feature-name
   # Create PR on GitHub
   ```

### RHEL-Specific Contribution Guidelines

**When contributing RHEL-specific changes:**

1. **Maintain backward compatibility with Debian:**
   - Don't modify Debian packaging files unless necessary
   - Keep RHEL-specific code in `base/rhel/` and `frontend/rhel/`
   - Test that Debian packages still build after your changes

2. **Support all target distributions:**
   - Test on RHEL 10, CentOS Stream 10, and Fedora 43
   - Document any distribution-specific quirks
   - Use conditional logic in spec files if needed

3. **Follow RPM packaging best practices:**
   - Use macros instead of hardcoded paths: `%{_bindir}`, `%{_libdir}`
   - Include proper dependencies in spec files
   - Write meaningful changelog entries
   - Follow [Fedora Packaging Guidelines](https://docs.fedoraproject.org/en-US/packaging-guidelines/)

4. **SELinux policy changes:**
   - Test in enforcing mode before submitting
   - Document any new booleans or contexts
   - Minimize permissions (principle of least privilege)
   - Include audit2allow output in PR description

5. **Documentation:**
   - Update relevant docs in `docs/rhel/`
   - Include examples for all supported distributions
   - Update TROUBLESHOOTING.md if introducing new failure modes

### Code Review Checklist

Before submitting, verify:

- [ ] Builds successfully on RHEL 10, CentOS Stream 10, and Fedora 43
- [ ] All rpmlint warnings are acceptable or filtered in `.rpmlintrc`
- [ ] Services start without errors
- [ ] SELinux policies work in enforcing mode
- [ ] Documentation is updated
- [ ] Debian packaging is not broken
- [ ] No hardcoded paths or version numbers
- [ ] Changelog entries are added
- [ ] Commit messages are descriptive

## Additional Resources

### Documentation

- [INSTALL.md](INSTALL.md) - Installation instructions
- [REPOSITORIES.md](REPOSITORIES.md) - Repository setup guide
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions
- [CHECKPOINT_VERIFICATION.md](CHECKPOINT_VERIFICATION.md) - Build verification guide
- [DEPENDENCIES.md](DEPENDENCIES.md) - Dependency mapping reference
- [SELINUX_INTEGRATION.md](SELINUX_INTEGRATION.md) - SELinux policy guide

### External Resources

- [RPM Packaging Guide](https://rpm-packaging-guide.github.io/)
- [Fedora Packaging Guidelines](https://docs.fedoraproject.org/en-US/packaging-guidelines/)
- [RHEL 10 Documentation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/10)
- [SELinux Policy Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/10/html/using_selinux/)
- [Bazel Documentation](https://bazel.build/docs)
- [systemd Documentation](https://www.freedesktop.org/software/systemd/man/)

### Getting Help

- **GitHub Issues**: https://github.com/google/android-cuttlefish/issues
- **Cuttlefish Documentation**: https://source.android.com/docs/setup/create/cuttlefish
- **RHEL Support**: https://access.redhat.com/support (RHEL subscribers)
- **Fedora Community**: https://ask.fedoraproject.org/

## Quick Reference

### Essential Commands

```bash
# Install dependencies
sudo ./tools/buildutils/install_rhel10_deps.sh

# Build all packages
./tools/buildutils/build_rpm_packages.sh

# Verify build
./tools/buildutils/verify_rhel_build.sh

# Install packages
sudo dnf install rpm-packages/cuttlefish-common-*.rpm

# Check services
sudo systemctl status cuttlefish-host-resources
sudo journalctl -u cuttlefish-host-resources -f

# SELinux debugging
sudo ausearch -m avc -ts recent | grep cuttlefish
sudo audit2allow -a -M mycuttlefish

# Clean rebuild
bazel clean --expunge
rm -rf ~/rpmbuild/BUILD/* rpm-packages/
./tools/buildutils/build_rpm_packages.sh
```

### Directory Structure

```
android-cuttlefish/
├── base/
│   ├── debian/          # Debian packaging (reference)
│   └── rhel/            # RHEL packaging files
│       ├── *.spec       # RPM spec files
│       ├── *.service    # Systemd units
│       ├── *.sh         # Wrapper scripts
│       └── selinux/     # SELinux policies
├── frontend/
│   ├── debian/          # Debian packaging (reference)
│   └── rhel/            # RHEL packaging files
├── tools/buildutils/    # Build scripts
│   ├── install_rhel10_deps.sh
│   ├── build_rpm_packages.sh
│   ├── verify_rhel_build.sh
│   └── verify_rhel_deps.sh
├── docs/rhel/           # RHEL documentation
└── rpm-packages/        # Output directory (created by build)
```
