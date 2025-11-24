# Package Upgrade Testing Guide

This document describes how to test RPM package upgrades for Cuttlefish to ensure configuration files are properly preserved and services continue to function after upgrades.

## Table of Contents

- [Overview](#overview)
- [Upgrade Behavior](#upgrade-behavior)
- [Automated Testing](#automated-testing)
- [Manual Testing](#manual-testing)
- [Verification Checklist](#verification-checklist)
- [Troubleshooting](#troubleshooting)

## Overview

RPM package upgrades must handle configuration files correctly to prevent data loss and service disruption. Cuttlefish packages use RPM's `%config(noreplace)` directive and systemd macros to ensure:

1. **User modifications are preserved** - Custom configuration changes are not overwritten
2. **New defaults are available** - New configuration options appear as `.rpmnew` files
3. **Services are properly restarted** - systemd units are reloaded and restarted as needed

## Upgrade Behavior

### Configuration File Handling

**RPM `%config(noreplace)` behavior:**

| Scenario | Package Upgrade | Result |
|----------|----------------|--------|
| Config unchanged by user | Old config = New config | Config remains unchanged |
| Config modified by user | Old config ≠ New config | User config preserved, new config saved as `.rpmnew` |
| Config modified + deleted | Old config deleted | New config installed normally |

**Configuration files using `%config(noreplace)`:**

- `/etc/sysconfig/cuttlefish-host-resources`
- `/etc/sysconfig/cuttlefish-operator`
- `/etc/sysconfig/cuttlefish-host_orchestrator`
- `/etc/nginx/conf.d/cuttlefish-orchestration.conf`
- Various files in `/etc/modules-load.d/`, `/etc/modprobe.d/`, etc.

### Systemd Service Handling

**Systemd macros used in spec files:**

1. **`%systemd_post`** (in `%post` section):
   - Enables service units
   - Runs `systemctl daemon-reload`
   - Does NOT start services automatically

2. **`%systemd_preun`** (in `%preun` section):
   - Stops services before package removal
   - Only runs on package removal, NOT on upgrade

3. **`%systemd_postun`** (in `%postun` section):
   - Runs `systemctl daemon-reload` after package removal
   - Restarts services on upgrade (if `$1 -ge 1`)

**Service behavior during upgrade:**

```
Upgrade Process:
1. %pre (new version)      - Create users/groups if needed
2. Install new files
3. %post (new version)     - systemctl daemon-reload
4. %preun (old version)    - NOT called during upgrade
5. Remove old files
6. %postun (old version)   - systemctl daemon-reload + restart services
```

## Automated Testing

### Quick Verification

Run the config handling verification script:

```bash
# Verify spec files have proper config handling
./tools/buildutils/verify_config_handling.sh
```

**This checks:**
- ✓ All `/etc/sysconfig/` files use `%config(noreplace)`
- ✓ All config files are properly marked
- ✓ `%postun` scripts use `%systemd_postun` macro
- ✓ `%preun` scripts use `%systemd_preun` macro
- ✓ `%post` scripts use `%systemd_post` macro

### Full Upgrade Test

Run the automated upgrade test (requires root):

```bash
# Test complete upgrade scenario
sudo ./tools/buildutils/test_package_upgrade.sh --clean
```

**This test:**
1. Builds and installs version N packages
2. Modifies configuration files with test markers
3. Records checksums of modified configs
4. Builds version N+1 packages (simulated)
5. Upgrades to version N+1
6. Verifies user modifications are preserved
7. Checks for `.rpmnew` files (if package configs changed)
8. Verifies systemd services remain functional
9. Tests downgrade to version N
10. Cleans up test environment

**Expected output:**
```
Package Upgrade Test Summary
Tests passed: 15
Tests failed: 0

✓ All upgrade tests passed!

Verified:
  ✓ Config files preserved during upgrade
  ✓ %config(noreplace) working correctly
  ✓ systemd services remain accessible
  ✓ Package upgrade/downgrade functions properly
```

## Manual Testing

### Prerequisites

- RHEL 10, CentOS Stream 10, or Fedora 43 test system
- Root/sudo access
- Two versions of packages (old and new)

### Step 1: Install Old Version

```bash
# Build and install version N
./tools/buildutils/build_rpm_packages.sh
sudo dnf install rpm-packages/cuttlefish-base-*.rpm
```

### Step 2: Customize Configuration

```bash
# Modify host-resources config
sudo vi /etc/sysconfig/cuttlefish-host-resources

# Example modifications:
# num_cvd_accounts=15
# custom_option=my_value

# Save checksum for comparison
md5sum /etc/sysconfig/cuttlefish-host-resources > /tmp/config.md5.before
```

### Step 3: Prepare New Version

```bash
# Simulate new version by modifying changelog or spec
# In real scenario, this would be a new release

# Rebuild packages
./tools/buildutils/build_rpm_packages.sh

# Move old packages
mkdir -p /tmp/old-packages
mv rpm-packages/*.rpm /tmp/old-packages/
```

### Step 4: Build New Version

```bash
# Make some code change (optional)
echo "# Version bump" >> base/rhel/cuttlefish-base.spec

# Rebuild
./tools/buildutils/build_rpm_packages.sh
```

### Step 5: Perform Upgrade

```bash
# Upgrade packages
sudo dnf upgrade rpm-packages/cuttlefish-base-*.rpm

# Check for upgrade messages
# Look for lines like:
# "warning: /etc/sysconfig/cuttlefish-host-resources created as /etc/sysconfig/cuttlefish-host-resources.rpmnew"
```

### Step 6: Verify Configuration Preserved

```bash
# Check if modifications are still present
cat /etc/sysconfig/cuttlefish-host-resources

# Should contain your custom values:
# num_cvd_accounts=15
# custom_option=my_value

# Compare checksums
md5sum /etc/sysconfig/cuttlefish-host-resources > /tmp/config.md5.after
diff /tmp/config.md5.before /tmp/config.md5.after

# If identical: Config was preserved (EXPECTED)
# If different: Config was modified (ERROR)
```

### Step 7: Check for .rpmnew Files

```bash
# Look for .rpmnew files
find /etc/sysconfig -name "*.rpmnew"

# If found, compare with current config
diff /etc/sysconfig/cuttlefish-host-resources \
     /etc/sysconfig/cuttlefish-host-resources.rpmnew

# The .rpmnew file contains the NEW default from the package
# Your modified config is preserved as-is
```

### Step 8: Verify Services

```bash
# Check systemd units are still valid
systemctl daemon-reload
systemctl status cuttlefish-host-resources

# Verify service can start
sudo systemctl start cuttlefish-host-resources
sudo journalctl -u cuttlefish-host-resources -n 20
```

### Step 9: Test Downgrade (Optional)

```bash
# Downgrade to old version
sudo dnf downgrade /tmp/old-packages/cuttlefish-base-*.rpm

# Verify config still preserved
cat /etc/sysconfig/cuttlefish-host-resources
# Should still contain custom values
```

## Verification Checklist

Use this checklist when testing upgrades:

### Before Upgrade

- [ ] Old version packages installed
- [ ] Configuration files customized with known values
- [ ] Checksums of config files recorded
- [ ] Services are running (if applicable)
- [ ] Service status recorded

### During Upgrade

- [ ] Upgrade command completes without errors
- [ ] No "file conflicts" errors
- [ ] Watch for `.rpmnew` warnings in output
- [ ] No systemd errors in journal

### After Upgrade

- [ ] New version packages installed (verify with `rpm -q`)
- [ ] Configuration files contain original custom values
- [ ] Config file checksums match pre-upgrade checksums
- [ ] `.rpmnew` files present if package config changed
- [ ] systemd units are valid (`systemctl cat <service>`)
- [ ] systemd daemon was reloaded (check journal)
- [ ] Services can start without errors
- [ ] Service functionality works (if applicable)

### Config File Specific Checks

For each config file with `%config(noreplace)`:

- [ ] `/etc/sysconfig/cuttlefish-host-resources`
  - Custom `num_cvd_accounts` value preserved?
  - Custom `bridge_interface` value preserved?
  - Custom `ipv6` setting preserved?

- [ ] `/etc/sysconfig/cuttlefish-operator`
  - Custom port settings preserved?
  - Custom TLS settings preserved?

- [ ] `/etc/sysconfig/cuttlefish-host_orchestrator`
  - Custom configuration preserved?

### Service Restart Verification

- [ ] `cuttlefish-host-resources.service` - Check journal for restart
- [ ] `cuttlefish-operator.service` - Check journal for restart
- [ ] `cuttlefish-host_orchestrator.service` - Check journal for restart

## Troubleshooting

### Config File Was Overwritten

**Symptom:**
```bash
# Custom values are gone after upgrade
cat /etc/sysconfig/cuttlefish-host-resources
# Shows default values instead of custom values
```

**Causes:**
1. Config file not marked with `%config(noreplace)` in spec file
2. RPM database corrupted
3. Config file was reinstalled instead of upgraded

**Solution:**
```bash
# Check spec file
grep "cuttlefish-host-resources" base/rhel/cuttlefish-base.spec
# Should show: %config(noreplace) /etc/sysconfig/cuttlefish-host-resources

# If missing, add %config(noreplace) to %files section
```

### No .rpmnew File Created

**Symptom:**
```bash
# Package config changed but no .rpmnew file
find /etc -name "*.rpmnew"
# No results
```

**Causes:**
1. Package config file didn't change between versions
2. User config file is identical to new package config
3. `%config(noreplace)` is working correctly (no new file needed)

**Solution:**
```bash
# This is EXPECTED behavior if:
# - Package config didn't change, OR
# - User config matches new package config

# Only a problem if:
# - You KNOW package config changed
# - User config was modified
# - But no .rpmnew appeared

# Check if config changed between versions:
rpm -qlp old-package.rpm | grep sysconfig
rpm -qlp new-package.rpm | grep sysconfig
```

### Services Not Restarted

**Symptom:**
```bash
# Services still running old binary after upgrade
ps aux | grep cuttlefish
# Shows old process
```

**Causes:**
1. `%postun` section missing `%systemd_postun` macro
2. Service not enabled
3. systemd daemon not reloaded

**Solution:**
```bash
# Manually restart services
sudo systemctl daemon-reload
sudo systemctl restart cuttlefish-host-resources

# Check spec file has proper macros:
grep "%systemd_postun" base/rhel/cuttlefish-base.spec
# Should show: %systemd_postun cuttlefish-host-resources.service
```

### Downgrade Fails

**Symptom:**
```bash
sudo dnf downgrade cuttlefish-base-1.34.0-1.rpm
# Error: package downgrade failed
```

**Causes:**
1. Dependencies prevent downgrade
2. Config files conflict
3. Database changes not backward compatible

**Solution:**
```bash
# Force downgrade with --allowerasing
sudo dnf downgrade --allowerasing cuttlefish-base-1.34.0-1.rpm

# Or remove and reinstall
sudo dnf remove cuttlefish-base
sudo dnf install cuttlefish-base-1.34.0-1.rpm

# Note: User configs should be preserved even during remove/reinstall
# if %config(noreplace) is used correctly
```

### Config Preserved But Service Fails

**Symptom:**
```bash
# Config file unchanged
cat /etc/sysconfig/cuttlefish-host-resources  # Shows custom values

# But service fails to start
sudo systemctl start cuttlefish-host-resources
# Error: service failed
```

**Causes:**
1. New version incompatible with old config options
2. Config syntax changed
3. Missing new required options

**Solution:**
```bash
# Compare old and new default configs
diff /etc/sysconfig/cuttlefish-host-resources \
     /etc/sysconfig/cuttlefish-host-resources.rpmnew

# Look for new required options
# Update config with new options while preserving custom values

# Check service logs for specific error
sudo journalctl -u cuttlefish-host-resources -n 50
```

## Best Practices

### For Package Maintainers

1. **Always use `%config(noreplace)` for user-editable files**
   ```spec
   %files
   %config(noreplace) /etc/sysconfig/cuttlefish-host-resources
   ```

2. **Always use systemd macros**
   ```spec
   %post
   %systemd_post cuttlefish-host-resources.service

   %preun
   %systemd_preun cuttlefish-host-resources.service

   %postun
   %systemd_postun cuttlefish-host-resources.service
   ```

3. **Document new config options in changelog**
   ```spec
   %changelog
   * Thu Nov 21 2024 - 1.35.0-1
   - Added new option: enable_ipv6 (default: 0)
   - User action required: Review .rpmnew files
   ```

4. **Test upgrades before release**
   ```bash
   sudo ./tools/buildutils/test_package_upgrade.sh --clean
   ```

### For Users

1. **Always review `.rpmnew` files after upgrade**
   ```bash
   find /etc -name "*.rpmnew"
   vimdiff /etc/sysconfig/cuttlefish-host-resources{,.rpmnew}
   ```

2. **Backup configs before upgrading**
   ```bash
   sudo cp /etc/sysconfig/cuttlefish-host-resources{,.backup}
   ```

3. **Test in staging environment first**
   - Don't upgrade production systems directly
   - Test upgrade path on identical staging system

4. **Monitor services after upgrade**
   ```bash
   sudo systemctl status cuttlefish-*
   sudo journalctl -f
   ```

## Automated Testing in CI

The package upgrade test can be integrated into CI:

```yaml
# Example GitHub Actions job
upgrade-test:
  runs-on: fedora-latest
  container: fedora:43
  steps:
    - name: Checkout repository
      uses: actions/checkout@v4

    - name: Run upgrade test
      run: |
        sudo ./tools/buildutils/test_package_upgrade.sh --clean
```

## References

- [RPM Packaging Guide - Config Files](https://rpm-packaging-guide.github.io/#config-files)
- [Fedora Packaging Guidelines - Scriptlets](https://docs.fedoraproject.org/en-US/packaging-guidelines/Scriptlets/)
- [systemd RPM Macros Documentation](https://www.freedesktop.org/software/systemd/man/daemon.html#SysV%20Init%20Script%20to%20systemd%20Service%20Migration)
- [Development Guide](DEVELOPMENT.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
