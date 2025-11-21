# CI/CD Testing for RHEL Packages

This document describes the continuous integration and testing infrastructure for Cuttlefish RHEL packages.

## Table of Contents

- [Overview](#overview)
- [GitHub Actions Workflows](#github-actions-workflows)
- [Test Artifact Requirements](#test-artifact-requirements)
- [Running Tests Locally](#running-tests-locally)
- [Troubleshooting CI Failures](#troubleshooting-ci-failures)

## Overview

The RHEL package CI/CD infrastructure consists of three main workflows:

1. **rhel-build.yml** - Builds RPM packages for all supported distributions and architectures
2. **rhel-test.yml** - Tests package installation and service functionality
3. **compatibility.yml** - Ensures RHEL changes don't break Debian packages

### Supported Test Matrix

**Distributions:**
- RHEL 10 (x86_64, aarch64)
- CentOS Stream 10 (x86_64, aarch64)
- Fedora 43 (x86_64, aarch64)

**Test Types:**
- Clean installation
- Multi-device configuration (5, 10 CVD accounts)
- Service functionality
- Debian compatibility

## GitHub Actions Workflows

### 1. RHEL Package Build (`rhel-build.yml`)

**Trigger:** Pull requests and pushes affecting base/, frontend/, or tools/buildutils/

**What it does:**
- Builds all 6 RPM packages for each distribution/architecture combination
- Runs rpmlint validation on all packages
- Archives build artifacts for 30 days
- Verifies package count and naming conventions

**Matrix:**
```yaml
os: [rhel:10, centos:stream10, fedora:43]
arch: [x86_64, aarch64]
```

**Artifacts produced:**
- `rpm-packages-<os>-<arch>/` - Built RPM packages
- `build-logs-<os>-<arch>/` - Build logs (7 day retention)

**Jobs:**
1. **build-matrix** - Builds packages in parallel for each OS/arch combination
2. **verify-build** - Downloads all artifacts and verifies completeness
3. **notify-success** - Reports overall build status

### 2. RHEL Package Testing (`rhel-test.yml`)

**Trigger:** Runs after successful completion of `rhel-build.yml`

**What it does:**
- Tests clean installation of packages
- Tests multi-device configurations
- Verifies service functionality
- Checks user/group creation
- Validates systemd units and configuration files

**Test jobs:**

#### Clean Installation Test
- Installs all packages from artifacts
- Verifies binaries are accessible (`cvd version`)
- Checks systemd unit files are installed
- Verifies SELinux modules (if available)
- Confirms configuration files exist
- Validates user/group creation (cvdnetwork, _cutf-operator, httpcvd)
- Tests package removal

#### Multi-Device Configuration Test
- Configures different `num_cvd_accounts` values (5, 10)
- Verifies configuration file updates
- Validates expected network interface counts

#### Service Functionality Test
- Loads required kernel modules
- Checks wrapper script syntax
- Tests firewall detection logic (firewalld vs iptables)
- Verifies udev rules installation

### 3. Debian-RHEL Compatibility (`compatibility.yml`)

**Trigger:** Pull requests and pushes affecting base/, frontend/, or tools/buildutils/

**What it does:**
- Compares Debian packages before/after RHEL changes
- Runs Debian package regression tests
- Checks version synchronization
- Verifies file organization

**Compatibility jobs:**

#### Debian Package Comparison
- Builds baseline packages from main branch
- Builds current packages with RHEL changes
- Compares file lists and metadata
- Fails if Debian package contents changed unexpectedly

#### Debian Regression Test
- Builds Debian packages with current code
- Tests package installation
- Verifies Debian-specific files remain intact

#### Version Synchronization Check
- Extracts versions from debian/changelog
- Compares with RHEL spec file versions
- Warns on version mismatches

#### File Organization Check
- Verifies RHEL files are in rhel/ subdirectories
- Ensures Debian files are not contaminated
- Validates documentation organization

## Test Artifact Requirements

### Android Images for Testing (Task 12.4)

**Note:** Full device boot testing is currently **not implemented** in CI due to image size and complexity constraints.

#### Current CI Testing Scope

The CI workflows test:
- ✅ Package building
- ✅ Package installation
- ✅ Service file installation
- ✅ Configuration file creation
- ✅ User/group creation
- ✅ Network configuration scripts

The CI workflows **do not** test:
- ❌ Actual device boot
- ❌ WebRTC functionality
- ❌ Orchestrator runtime behavior

#### Android Image Requirements (for manual testing)

To test actual device boot, you need Android device images:

**Obtaining Images:**

1. **From Android CI** (recommended):
   ```bash
   # Visit https://ci.android.com/
   # Search for "aosp_cf_x86_64_phone" or "aosp_cf_arm64_phone"
   # Download latest successful build
   ```

2. **Build from AOSP source**:
   ```bash
   # See https://source.android.com/setup/build/cuttlefish
   ```

**Image Size Considerations:**
- Minimal Cuttlefish image: ~2-4 GB
- Full system image: ~8-15 GB
- Not practical for CI artifact storage

**Recommended Testing Approach:**

For full device testing:
1. Install packages from CI artifacts
2. Manually download Android images
3. Test device boot locally:
   ```bash
   cvd start --system_image_dir ~/android-images --daemon
   cvd status
   ```

### CI Artifact Caching

Build artifacts are cached with the following retention:

| Artifact Type | Retention | Size Limit |
|---------------|-----------|------------|
| RPM packages | 30 days | ~100 MB per matrix cell |
| Build logs | 7 days | ~10 MB per matrix cell |
| Test results | 7 days | ~1 MB |

**Storage calculation:**
- 3 distributions × 2 architectures = 6 matrix cells
- 6 cells × 100 MB = ~600 MB total per build
- With 30-day retention: manageable within GitHub limits

## Running Tests Locally

### Running Build Tests Locally

**Using Docker/Podman:**

```bash
# Test RHEL 10 build
podman run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  registry.access.redhat.com/ubi10/ubi \
  bash -c "./tools/buildutils/install_rhel10_deps.sh && ./tools/buildutils/build_rpm_packages.sh"

# Test CentOS Stream 10 build
podman run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  quay.io/centos/centos:stream10 \
  bash -c "./tools/buildutils/install_rhel10_deps.sh && ./tools/buildutils/build_rpm_packages.sh"

# Test Fedora 43 build
podman run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  fedora:43 \
  bash -c "./tools/buildutils/install_rhel10_deps.sh && ./tools/buildutils/build_rpm_packages.sh"
```

### Running Installation Tests Locally

```bash
# Test installation in container
podman run -it --rm \
  -v $(pwd)/rpm-packages:/packages:ro \
  fedora:43 \
  bash

# Inside container:
dnf install -y /packages/cuttlefish-common-*.rpm
rpm -qa | grep cuttlefish
systemctl list-unit-files | grep cuttlefish
```

### Running Compatibility Tests Locally

**Compare Debian packages:**

```bash
# Build baseline
git checkout main
cd base && dpkg-buildpackage -b -uc -us
cd .. && mkdir baseline-packages && mv *.deb baseline-packages/

# Build current
git checkout your-branch
cd base && dpkg-buildpackage -b -uc -us
cd .. && mkdir current-packages && mv *.deb current-packages/

# Compare
for pkg in baseline-packages/*.deb; do
  dpkg-deb -c "$pkg" | awk '{print $6}' | sort > baseline.txt
  dpkg-deb -c "current-packages/$(basename $pkg)" | awk '{print $6}' | sort > current.txt
  diff -u baseline.txt current.txt
done
```

### Running Version Sync Check Locally

```bash
# Extract and compare versions
DEBIAN_VERSION=$(head -n1 base/debian/changelog | sed 's/.*(\([^)]*\)).*/\1/' | cut -d- -f1)
echo "Debian version: $DEBIAN_VERSION"

for spec in base/rhel/*.spec; do
  SPEC_VERSION=$(grep "^Version:" "$spec" | awk '{print $2}')
  echo "$(basename $spec): $SPEC_VERSION"
done
```

## Troubleshooting CI Failures

### Build Failures

**Symptom:** `rhel-build.yml` fails during package build

**Common causes:**
1. **Missing dependencies**
   ```
   Error: Package 'foo-devel' not found
   ```
   **Fix:** Add dependency to `install_rhel10_deps.sh`

2. **Bazel build errors**
   ```
   ERROR: Analysis of target failed
   ```
   **Fix:** Check Bazel build locally, verify .bazelversion

3. **SELinux policy compilation fails**
   ```
   checkmodule: error: syntax error
   ```
   **Fix:** Test policy compilation locally, check syntax

4. **rpmlint errors**
   ```
   E: invalid-spec-name
   ```
   **Fix:** Update .rpmlintrc to filter acceptable warnings

**Debug steps:**
```bash
# Download build logs artifact from failed workflow
# Check ~/rpmbuild/BUILD/*/build.log
# Run build locally in same container image
```

### Installation Test Failures

**Symptom:** `rhel-test.yml` fails during clean installation

**Common causes:**
1. **Missing users/groups**
   ```
   ERROR: cvdnetwork group NOT found
   ```
   **Fix:** Check %pre scripts in spec files

2. **Systemd unit not found**
   ```
   ERROR: cuttlefish-host-resources.service NOT found
   ```
   **Fix:** Verify %install section installs unit to %{_unitdir}

3. **Binary not in PATH**
   ```
   ERROR: cvd not found in PATH
   ```
   **Fix:** Check /usr/bin/cvd symlink creation

**Debug steps:**
```bash
# Run installation test locally
podman run -it --rm fedora:43 bash
dnf install -y <path-to-rpms>/cuttlefish-common-*.rpm
rpm -V cuttlefish-base  # Verify files
```

### Compatibility Test Failures

**Symptom:** `compatibility.yml` fails

**Common causes:**
1. **Debian package contents changed**
   ```
   ERROR: File list differs
   ```
   **Fix:** Ensure RHEL changes don't modify Debian packages

2. **Version mismatch**
   ```
   WARNING: spec version differs from Debian
   ```
   **Fix:** Update spec file version to match debian/changelog

3. **RHEL contamination in Debian files**
   ```
   ERROR: Found rpmbuild in base/debian/
   ```
   **Fix:** Remove RHEL-specific references from Debian files

**Debug steps:**
```bash
# Compare package contents locally
dpkg-deb -c baseline.deb > baseline.txt
dpkg-deb -c current.deb > current.txt
diff -u baseline.txt current.txt
```

### Container Limitations in CI

Some tests have limitations in GitHub Actions containers:

**Systemd limitations:**
- Full systemd not available in standard containers
- Services cannot actually start
- Tests verify unit files are installed but don't test runtime

**Workarounds:**
- Use `systemd-analyze verify` to check unit file syntax
- Test service startup manually on real systems
- CI focuses on package structure, not runtime behavior

**Networking limitations:**
- Cannot create actual network bridges in containers
- Cannot load kernel modules
- Tests verify scripts exist and have valid syntax

**Workarounds:**
- Verify wrapper scripts with `bash -n`
- Document expected network configuration
- Perform full networking tests on real RHEL systems

## CI Workflow Dependencies

```
┌─────────────────┐
│ Pull Request    │
│ or Push         │
└────────┬────────┘
         │
         ├──────────────┐
         │              │
         ▼              ▼
┌────────────────┐ ┌──────────────────┐
│ rhel-build.yml │ │ compatibility.yml│
│ (parallel)     │ │ (parallel)       │
└────────┬───────┘ └──────────────────┘
         │
         ▼
┌────────────────┐
│ rhel-test.yml  │
│ (sequential)   │
└────────────────┘
```

**Execution order:**
1. `rhel-build.yml` and `compatibility.yml` run in parallel on PR
2. `rhel-test.yml` runs after `rhel-build.yml` completes successfully
3. All three must pass for PR to be mergeable

## Best Practices

### For Contributors

1. **Test locally before pushing:**
   ```bash
   ./tools/buildutils/build_rpm_packages.sh
   ./tools/buildutils/verify_rhel_build.sh
   ```

2. **Check Debian compatibility:**
   ```bash
   cd base && dpkg-buildpackage -b -uc -us
   ```

3. **Keep versions synchronized:**
   - Update debian/changelog first
   - RHEL spec files read version from changelog

4. **Use proper file organization:**
   - RHEL files in `base/rhel/` and `frontend/rhel/`
   - Debian files stay in `base/debian/` and `frontend/debian/`
   - Don't cross-contaminate

### For Maintainers

1. **Monitor CI failures:**
   - Check failed workflows in GitHub Actions tab
   - Download build logs for debugging
   - Use artifact comparison tools

2. **Update CI when dependencies change:**
   - Modify `install_rhel10_deps.sh`
   - Update container images if needed
   - Adjust test matrices for new distributions

3. **Maintain artifact retention:**
   - Clean up old artifacts periodically
   - Adjust retention policies if storage limits reached

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [RHEL Development Guide](DEVELOPMENT.md)
- [Build Verification Guide](CHECKPOINT_VERIFICATION.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
