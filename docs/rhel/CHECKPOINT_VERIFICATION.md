# RHEL Build Checkpoint Verification Guide

This document describes how to verify the RHEL package build process (Task 10 checkpoint).

## Prerequisites

### System Requirements
- RHEL 10 or Fedora (latest) - (RHEL 8/9 supported in compatibility mode)
- Minimum 8GB RAM
- Minimum 20GB free disk space
- Internet connection for repository access
- Root or sudo access

### Required Tools
The verification script will check for and use:
- `rpmlint` - RPM package validator
- `rpm` - RPM package manager
- Build tools (installed by `install_rhel10_deps.sh`)

## Verification Methods

### Method 1: Automated Verification (Recommended)

Use the provided verification script to automatically build and verify all packages:

```bash
# Run full verification (build + verify)
./tools/buildutils/verify_rhel_build.sh

# Or verify existing packages without rebuilding
./tools/buildutils/verify_rhel_build.sh --skip-build
```

The script will:
1. ✓ Verify OS type and version
2. ✓ Run the RPM package build
3. ✓ Verify all 6 packages are created
4. ✓ Verify SELinux policy modules are included
5. ✓ Run rpmlint validation
6. ✓ Verify package metadata
7. ✓ Verify package contents
8. ✓ Generate verification report

**Output:**
- Console output with colored test results
- Log file: `rpm-build-verification.log`
- rpmlint output: `rpmlint-output.txt`

### Method 2: Manual Verification

If you prefer to verify manually, follow these steps:

#### Step 1: Verify OS
```bash
cat /etc/os-release
```

Expected: `ID=rhel` (or `fedora`) and appropriate `VERSION_ID` (10.x for RHEL, 39+ for Fedora)

#### Step 2: Run Build
```bash
./tools/buildutils/build_rpm_packages.sh
```

Expected: Build completes without errors

#### Step 3: Verify Package Creation
```bash
ls -lh rpm-packages/
```

Expected output should include all 6 packages:
```
cuttlefish-base-*.rpm
cuttlefish-integration-*.rpm
cuttlefish-defaults-*.rpm
cuttlefish-user-*.rpm
cuttlefish-orchestration-*.rpm
cuttlefish-common-*.rpm
```

Plus source packages (`*.src.rpm`)

#### Step 4: Verify SELinux Policy Modules

Check cuttlefish-base:
```bash
rpm -qlp rpm-packages/cuttlefish-base-*.rpm | grep "\.pp$"
```
Expected: `/usr/share/selinux/packages/cuttlefish_host_resources.pp`

Check cuttlefish-user:
```bash
rpm -qlp rpm-packages/cuttlefish-user-*.rpm | grep "\.pp$"
```
Expected: `/usr/share/selinux/packages/cuttlefish_operator.pp`

Check cuttlefish-orchestration:
```bash
rpm -qlp rpm-packages/cuttlefish-orchestration-*.rpm | grep "\.pp$"
```
Expected: `/usr/share/selinux/packages/cuttlefish_orchestration.pp`

#### Step 5: Run rpmlint

Copy configuration:
```bash
cp .rpmlintrc ~/
```

Run validation:
```bash
rpmlint rpm-packages/*.rpm
```

Expected: No errors, warnings should be filtered by `.rpmlintrc`

## Verification Checklist

Use this checklist to track verification progress:

### Build Environment
- [ ] Running on RHEL 10 or Fedora (latest)
- [ ] Minimum 8GB RAM available
- [ ] Minimum 20GB disk space available
- [ ] Internet connection active
- [ ] sudo/root access available

### Build Process
- [ ] `install_rhel10_deps.sh` completes successfully
- [ ] EPEL repository enabled
- [ ] CRB/PowerTools repository enabled
- [ ] Bazel installed (bazelisk or from Copr)
- [ ] Build dependencies installed
- [ ] `build_rpm_packages.sh` completes without errors

### Package Creation
- [ ] `rpm-packages/` directory created
- [ ] `cuttlefish-base-*.rpm` created
- [ ] `cuttlefish-integration-*.rpm` created
- [ ] `cuttlefish-defaults-*.rpm` created
- [ ] `cuttlefish-user-*.rpm` created
- [ ] `cuttlefish-orchestration-*.rpm` created
- [ ] `cuttlefish-common-*.rpm` created
- [ ] Source packages (`*.src.rpm`) created

### SELinux Policy Modules
- [ ] `cuttlefish_host_resources.pp` in cuttlefish-base
- [ ] `cuttlefish_operator.pp` in cuttlefish-user
- [ ] `cuttlefish_orchestration.pp` in cuttlefish-orchestration

### Package Validation
- [ ] rpmlint passes with no errors
- [ ] All warnings are acceptable per `.rpmlintrc`
- [ ] Package metadata correct (name, version, release)
- [ ] Package dependencies correct
- [ ] File permissions correct

### Package Contents
- [ ] cuttlefish-base contains binaries in `/usr/lib/cuttlefish-common/bin/`
- [ ] cuttlefish-base contains systemd unit `cuttlefish-host-resources.service`
- [ ] cuttlefish-base contains config files in `/etc/sysconfig/`
- [ ] cuttlefish-base contains udev rules
- [ ] cuttlefish-user contains `operator` binary
- [ ] cuttlefish-user contains `cuttlefish-operator.service`
- [ ] cuttlefish-orchestration contains `host_orchestrator` binary
- [ ] cuttlefish-orchestration contains `cuttlefish-host_orchestrator.service`
- [ ] cuttlefish-orchestration contains nginx configuration
- [ ] cuttlefish-common is a meta-package (minimal size, only dependencies)

## Expected Results

### Successful Build Output

A successful build should produce output similar to:

```
[INFO] Starting Cuttlefish RPM package build...
[STEP] Detecting OS type...
[INFO] Detected: Red Hat Enterprise Linux 10.0 (ID: rhel, Version: 10)
[STEP] Installing build dependencies...
[INFO] Build dependencies installed successfully
[STEP] Setting up RPM build directory structure...
[INFO] RPM build tree created at ~/rpmbuild/
[STEP] Extracting package versions...
[INFO] Base package version: 1.34.0
[INFO] Frontend package version: 1.34.0
[STEP] Creating source tarballs...
[INFO] Source tarballs created successfully
[STEP] Copying spec files...
[INFO] Spec files copied
[STEP] Compiling SELinux policy modules...
[INFO] SELinux policy modules compiled
[STEP] Building RPM packages...
[INFO] All RPM packages built successfully
[STEP] Running rpmlint validation...
[INFO] rpmlint validation complete
[STEP] Copying packages to output directory...
[INFO] Packages copied to: /path/to/repo/rpm-packages

==========================================
RPM Build Summary
==========================================

Built packages:
  - cuttlefish-base-1.34.0-1.el10.x86_64.rpm
  - cuttlefish-integration-1.34.0-1.el10.x86_64.rpm
  - cuttlefish-defaults-1.34.0-1.el10.x86_64.rpm
  - cuttlefish-user-1.34.0-1.el10.x86_64.rpm
  - cuttlefish-orchestration-1.34.0-1.el10.x86_64.rpm
  - cuttlefish-common-1.34.0-1.el10.noarch.rpm

Output directory: /path/to/repo/rpm-packages

Build complete!
```

### Package Sizes

Approximate expected sizes:
- cuttlefish-base: 10-50 MB (contains binaries + SELinux policy)
- cuttlefish-integration: < 1 MB (udev rules only)
- cuttlefish-defaults: < 1 MB (config files only)
- cuttlefish-user: 5-20 MB (Go binary + SELinux policy)
- cuttlefish-orchestration: 5-20 MB (Go binary + SELinux policy + nginx config)
- cuttlefish-common: < 100 KB (meta-package, no files)

### rpmlint Results

With `.rpmlintrc` configuration, acceptable warnings include:
- Non-standard user names (`_cutf-operator`, `httpcvd`)
- Non-standard directory paths (`/usr/lib/cuttlefish-common`)
- `setcap` usage in `%post` scripts

All **errors** should be investigated and resolved.

## Troubleshooting

### Build Fails

**Issue**: Build fails with missing dependencies
```
Error: Package 'gflags-devel' not found
```

**Solution**:
```bash
# Ensure EPEL and CRB are enabled
sudo dnf install epel-release
sudo dnf config-manager --set-enabled crb

# Run dependency installation again
./tools/buildutils/install_rhel10_deps.sh
```

### SELinux Policy Compilation Fails

**Issue**: SELinux policy compilation errors
```
checkmodule: error: Invalid module
```

**Solution**:
```bash
# Install SELinux development tools
sudo dnf install selinux-policy-devel checkpolicy

# Manually compile to see detailed errors
cd base/rhel/selinux
make clean
make -f /usr/share/selinux/devel/Makefile cuttlefish_host_resources.pp
```

### rpmlint Shows Errors

**Issue**: rpmlint reports errors that should be filtered

**Solution**:
```bash
# Ensure .rpmlintrc is in home directory
cp .rpmlintrc ~/

# Re-run rpmlint
rpmlint rpm-packages/*.rpm
```

### Bazel Not Found

**Issue**: Bazel not installed

**Solution**:
```bash
# Install Bazelisk manually
wget https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64
chmod +x bazelisk-linux-amd64
sudo mv bazelisk-linux-amd64 /usr/local/bin/bazelisk
sudo ln -s /usr/local/bin/bazelisk /usr/local/bin/bazel
```

## Next Steps After Verification

Once verification passes:

1. **Test Installation**:
   ```bash
   sudo dnf install rpm-packages/cuttlefish-common-*.rpm
   ```

2. **Verify Services**:
   ```bash
   sudo systemctl status cuttlefish-host-resources
   sudo systemctl status cuttlefish-operator
   sudo systemctl status cuttlefish-host_orchestrator
   ```

3. **Verify SELinux Modules**:
   ```bash
   sudo semodule -l | grep cuttlefish
   ```

4. **Check Network Bridges**:
   ```bash
   ip link show | grep cvd
   ```

5. **Move to Task 11**: Create comprehensive documentation

## Reporting Issues

If verification fails, gather the following information:

1. **System Information**:
   ```bash
   cat /etc/os-release
   uname -a
   free -h
   df -h
   ```

2. **Build Logs**:
   - `rpm-build-verification.log`
   - `~/rpmbuild/BUILD/` logs
   - `rpmlint-output.txt`

3. **Error Messages**:
   - Copy full error output
   - Include context (which step failed)

4. **Package Status**:
   ```bash
   ls -lh rpm-packages/
   rpm -qp --queryformat '%{NAME}-%{VERSION}-%{RELEASE}\n' rpm-packages/*.rpm
   ```

Report issues with this information to help with debugging.

## References

- [RHEL 10 Release Notes](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/10)
- [RPM Packaging Guide](https://rpm-packaging-guide.github.io/)
- [SELinux Policy Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/10/html/using_selinux/)
- [Bazel Build Documentation](https://bazel.build/)
