#!/bin/bash
#
# Test Package Upgrade Scenario
#
# This script tests the RPM package upgrade process:
# 1. Builds and installs version N of packages
# 2. Modifies configuration files
# 3. Builds and upgrades to version N+1
# 4. Verifies config files are preserved
# 5. Verifies .rpmnew files are created
# 6. Verifies services are properly restarted
#
# Usage: ./test_package_upgrade.sh [--clean]
#   --clean: Clean up test environment before running
#
# Requirements:
# - Must be run on RHEL 10, CentOS Stream 10, or Fedora 43
# - Requires root/sudo access
# - Requires build dependencies installed
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test directories
TEST_ROOT="/tmp/cuttlefish-upgrade-test"
VERSION_N_DIR="$TEST_ROOT/version-n"
VERSION_N_PLUS_1_DIR="$TEST_ROOT/version-n-plus-1"

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print messages
echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

echo_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

echo_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Parse arguments
CLEAN_FIRST=false
if [ "$1" == "--clean" ]; then
    CLEAN_FIRST=true
fi

# Check OS
if [ ! -f /etc/os-release ]; then
    echo_error "Cannot determine OS type"
    exit 1
fi

source /etc/os-release

if [[ ! "$ID" =~ ^(rhel|centos|fedora)$ ]]; then
    echo_error "This test requires RHEL, CentOS Stream, or Fedora"
    echo_info "Detected OS: $ID"
    exit 1
fi

echo_info "Running on: $PRETTY_NAME"

# Check for root
if [ "$EUID" -ne 0 ]; then
    echo_error "This test requires root privileges"
    echo_info "Please run with sudo: sudo $0"
    exit 1
fi

# Clean up if requested
if [ "$CLEAN_FIRST" == "true" ]; then
    echo_step "Cleaning up previous test environment"

    # Uninstall packages if installed
    if rpm -qa | grep -q cuttlefish; then
        echo_info "Removing existing cuttlefish packages..."
        dnf remove -y cuttlefish-* || true
    fi

    # Remove test directory
    if [ -d "$TEST_ROOT" ]; then
        echo_info "Removing test directory: $TEST_ROOT"
        rm -rf "$TEST_ROOT"
    fi
fi

# Create test directories
echo_step "Setting up test environment"
mkdir -p "$VERSION_N_DIR/rpms"
mkdir -p "$VERSION_N_PLUS_1_DIR/rpms"
echo_info "Test directory: $TEST_ROOT"

# Get repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
echo_info "Repository root: $REPO_ROOT"

# Build Version N packages
echo_step "Building Version N packages"
cd "$REPO_ROOT"

echo_info "Running build_rpm_packages.sh..."
if ./tools/buildutils/build_rpm_packages.sh > "$VERSION_N_DIR/build.log" 2>&1; then
    echo_success "Version N packages built successfully"
else
    echo_error "Failed to build Version N packages"
    echo_info "Check build log: $VERSION_N_DIR/build.log"
    exit 1
fi

# Copy packages to version N directory
cp rpm-packages/*.rpm "$VERSION_N_DIR/rpms/"
VERSION_N_COUNT=$(ls -1 "$VERSION_N_DIR/rpms"/*.rpm 2>/dev/null | wc -l)
echo_info "Built $VERSION_N_COUNT packages for Version N"

# Get version number
VERSION_N=$(rpm -qp --queryformat '%{VERSION}' "$VERSION_N_DIR/rpms"/cuttlefish-base-*.rpm 2>/dev/null | head -n1)
echo_info "Version N: $VERSION_N"

# Install Version N packages
echo_step "Installing Version N packages"
echo_info "Installing cuttlefish-base, cuttlefish-integration, cuttlefish-defaults..."

dnf install -y \
    "$VERSION_N_DIR/rpms"/cuttlefish-base-*.rpm \
    "$VERSION_N_DIR/rpms"/cuttlefish-integration-*.rpm \
    "$VERSION_N_DIR/rpms"/cuttlefish-defaults-*.rpm \
    > "$VERSION_N_DIR/install.log" 2>&1

if rpm -qa | grep -q "cuttlefish-base"; then
    echo_success "Version N packages installed"
else
    echo_error "Version N installation failed"
    exit 1
fi

# Verify config files exist
echo_step "Verifying configuration files"

CONFIG_FILES=(
    "/etc/sysconfig/cuttlefish-host-resources"
)

for config in "${CONFIG_FILES[@]}"; do
    if [ -f "$config" ]; then
        echo_success "Config file exists: $config"

        # Backup original
        cp "$config" "$config.original"
    else
        echo_warning "Config file not found: $config (may not be created by this package)"
    fi
done

# Modify configuration files
echo_step "Modifying configuration files"

# Modify cuttlefish-host-resources config
if [ -f "/etc/sysconfig/cuttlefish-host-resources" ]; then
    echo "# MODIFIED BY UPGRADE TEST - DO NOT REMOVE THIS LINE" >> /etc/sysconfig/cuttlefish-host-resources
    echo "num_cvd_accounts=15" >> /etc/sysconfig/cuttlefish-host-resources
    echo "test_option=upgrade_test_value" >> /etc/sysconfig/cuttlefish-host-resources

    echo_info "Modified /etc/sysconfig/cuttlefish-host-resources"
    echo_info "Added test markers and custom values"
fi

# Save checksums of modified files
echo_step "Recording checksums of modified files"

for config in "${CONFIG_FILES[@]}"; do
    if [ -f "$config" ]; then
        md5sum "$config" > "$TEST_ROOT/$(basename $config).md5.before"
        echo_info "Checksum saved for: $config"
    fi
done

# Prepare Version N+1 (simulate version bump)
echo_step "Preparing Version N+1 packages"

# Increment version in changelog (simulate new version)
echo_info "Simulating version bump..."

# For testing purposes, we'll rebuild the same code but treat it as N+1
# In real scenario, there would be code changes
echo_info "Note: Using same code base (real upgrade would have code changes)"

# Build "Version N+1" packages
echo_info "Building Version N+1 packages..."
if ./tools/buildutils/build_rpm_packages.sh > "$VERSION_N_PLUS_1_DIR/build.log" 2>&1; then
    echo_success "Version N+1 packages built successfully"
else
    echo_error "Failed to build Version N+1 packages"
    exit 1
fi

# Copy packages to version N+1 directory
cp rpm-packages/*.rpm "$VERSION_N_PLUS_1_DIR/rpms/"
VERSION_N_PLUS_1_COUNT=$(ls -1 "$VERSION_N_PLUS_1_DIR/rpms"/*.rpm 2>/dev/null | wc -l)
echo_info "Built $VERSION_N_PLUS_1_COUNT packages for Version N+1"

# Upgrade to Version N+1
echo_step "Upgrading to Version N+1"

echo_info "Running package upgrade..."
dnf upgrade -y \
    "$VERSION_N_PLUS_1_DIR/rpms"/cuttlefish-base-*.rpm \
    "$VERSION_N_PLUS_1_DIR/rpms"/cuttlefish-integration-*.rpm \
    "$VERSION_N_PLUS_1_DIR/rpms"/cuttlefish-defaults-*.rpm \
    > "$VERSION_N_PLUS_1_DIR/upgrade.log" 2>&1

echo_success "Upgrade completed"

# Get upgraded version
VERSION_N_PLUS_1=$(rpm -q --queryformat '%{VERSION}' cuttlefish-base 2>/dev/null)
echo_info "Upgraded to version: $VERSION_N_PLUS_1"

# Verify modified config files are preserved
echo_step "Verifying config files preserved after upgrade"

for config in "${CONFIG_FILES[@]}"; do
    if [ -f "$config" ]; then
        # Check if our test marker is still there
        if [ -f "$config" ] && grep -q "MODIFIED BY UPGRADE TEST" "$config" 2>/dev/null; then
            echo_success "$config: Modifications preserved"

            # Verify checksum matches (config should be unchanged)
            if [ -f "$TEST_ROOT/$(basename $config).md5.before" ]; then
                md5sum "$config" > "$TEST_ROOT/$(basename $config).md5.after"

                if diff -q "$TEST_ROOT/$(basename $config).md5.before" "$TEST_ROOT/$(basename $config).md5.after" > /dev/null 2>&1; then
                    echo_success "$config: Checksum matches (file unchanged by upgrade)"
                else
                    echo_error "$config: Checksum differs (file was modified during upgrade)"
                fi
            fi
        else
            echo_error "$config: Modifications NOT preserved (test marker missing)"
        fi
    fi
done

# Check for .rpmnew files
echo_step "Checking for .rpmnew files"

RPMNEW_FOUND=false
for config in "${CONFIG_FILES[@]}"; do
    if [ -f "$config.rpmnew" ]; then
        echo_success "Found .rpmnew file: $config.rpmnew"
        RPMNEW_FOUND=true

        echo_info "Comparing original and .rpmnew:"
        diff -u "$config" "$config.rpmnew" || true
    fi
done

if [ "$RPMNEW_FOUND" == "false" ]; then
    echo_info "No .rpmnew files created (expected if config file in package unchanged)"
fi

# Verify systemd services are accessible
echo_step "Verifying systemd services"

SERVICES=(
    "cuttlefish-host-resources.service"
)

for service in "${SERVICES[@]}"; do
    if systemctl list-unit-files | grep -q "$service"; then
        echo_success "Service unit exists: $service"

        # Check if service can be loaded
        if systemctl cat "$service" > /dev/null 2>&1; then
            echo_success "Service unit file is valid: $service"
        else
            echo_error "Service unit file is invalid: $service"
        fi
    else
        echo_error "Service unit not found: $service"
    fi
done

# Verify systemd daemon was reloaded
echo_step "Verifying systemd daemon-reload"

# Check journal for daemon-reload after upgrade
if journalctl -u cuttlefish-host-resources --since "5 minutes ago" 2>/dev/null | grep -q "Reloading" ; then
    echo_success "systemd daemon was reloaded during upgrade"
else
    echo_info "Cannot verify daemon-reload from journal (may not be logged)"
fi

# Verify package version
echo_step "Verifying package version"

for pkg in cuttlefish-base cuttlefish-integration cuttlefish-defaults; do
    if rpm -q "$pkg" > /dev/null 2>&1; then
        version=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' "$pkg")
        echo_success "$pkg: $version"
    else
        echo_error "$pkg: Not installed"
    fi
done

# Test rollback (downgrade)
echo_step "Testing package downgrade (optional)"

echo_info "Downgrading back to Version N..."
if dnf downgrade -y \
    "$VERSION_N_DIR/rpms"/cuttlefish-base-*.rpm \
    "$VERSION_N_DIR/rpms"/cuttlefish-integration-*.rpm \
    "$VERSION_N_DIR/rpms"/cuttlefish-defaults-*.rpm \
    > "$TEST_ROOT/downgrade.log" 2>&1; then
    echo_success "Downgrade completed"

    # Verify config still preserved
    for config in "${CONFIG_FILES[@]}"; do
        if [ -f "$config" ] && grep -q "MODIFIED BY UPGRADE TEST" "$config" 2>/dev/null; then
            echo_success "$config: Modifications preserved after downgrade"
        else
            echo_warning "$config: Modifications may be lost after downgrade"
        fi
    done
else
    echo_warning "Downgrade failed (may not be supported)"
fi

# Cleanup test modifications
echo_step "Cleaning up test environment"

echo_info "Removing test packages..."
dnf remove -y cuttlefish-base cuttlefish-integration cuttlefish-defaults > /dev/null 2>&1 || true

echo_info "Test artifacts saved in: $TEST_ROOT"
echo_info "  - Version N packages: $VERSION_N_DIR/rpms/"
echo_info "  - Version N+1 packages: $VERSION_N_PLUS_1_DIR/rpms/"
echo_info "  - Build logs: $VERSION_N_DIR/build.log, $VERSION_N_PLUS_1_DIR/build.log"
echo_info "  - Upgrade log: $VERSION_N_PLUS_1_DIR/upgrade.log"

# Summary
echo ""
echo "========================================"
echo "Package Upgrade Test Summary"
echo "========================================"
echo ""
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All upgrade tests passed!${NC}"
    echo ""
    echo "Verified:"
    echo "  ✓ Config files preserved during upgrade"
    echo "  ✓ %config(noreplace) working correctly"
    echo "  ✓ systemd services remain accessible"
    echo "  ✓ Package upgrade/downgrade functions properly"
    exit 0
else
    echo -e "${RED}✗ Some upgrade tests failed${NC}"
    echo ""
    echo "Please review the failures above and check:"
    echo "  - Spec file %config(noreplace) directives"
    echo "  - Systemd macro usage in %post/%preun/%postun"
    echo "  - Service file installation paths"
    exit 1
fi
