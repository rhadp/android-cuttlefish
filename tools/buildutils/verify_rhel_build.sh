#!/usr/bin/env bash
#
# Verify Cuttlefish RHEL build and packages
#
# This script performs comprehensive verification of the RHEL build process:
# - Verifies running on RHEL 10 or compatible system
# - Runs build_rpm_packages.sh to build all packages
# - Verifies all 6 RPM packages are created
# - Verifies SELinux policy modules are included
# - Runs rpmlint validation using .rpmlintrc
# - Generates detailed verification report
#
# Usage: ./verify_rhel_build.sh [--skip-build]
#   --skip-build: Skip the build step, only verify existing packages

set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters for test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

function echo_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

function echo_step() {
    echo -e "${BLUE}[STEP]${NC} $*"
}

function echo_test() {
    echo -e "${CYAN}[TEST]${NC} $*"
}

function echo_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((TESTS_PASSED++))
}

function echo_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((TESTS_FAILED++))
}

function echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
    ((TESTS_WARNED++))
}

function echo_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Get repository root directory
REPO_DIR="$(realpath "$(dirname "$0")/../..")"
SCRIPT_DIR="$(dirname "$0")"
BUILD_SCRIPT="${SCRIPT_DIR}/build_rpm_packages.sh"
OUTPUT_DIR="${REPO_DIR}/rpm-packages"
VERIFICATION_LOG="${REPO_DIR}/rpm-build-verification.log"

# Parse arguments
SKIP_BUILD=false
if [ "$1" == "--skip-build" ]; then
    SKIP_BUILD=true
    echo_info "Skipping build step, will only verify existing packages"
fi

# Expected packages
EXPECTED_PACKAGES=(
    "cuttlefish-base"
    "cuttlefish-integration"
    "cuttlefish-defaults"
    "cuttlefish-user"
    "cuttlefish-orchestration"
    "cuttlefish-common"
)

# Start verification
function start_verification() {
    echo "=========================================="
    echo "Cuttlefish RHEL Build Verification"
    echo "=========================================="
    echo ""
    echo "Repository: ${REPO_DIR}"
    echo "Output directory: ${OUTPUT_DIR}"
    echo "Log file: ${VERIFICATION_LOG}"
    echo ""

    # Start logging
    exec &> >(tee "${VERIFICATION_LOG}")

    echo_info "Verification started at $(date)"
    echo ""
}

# Test 1: Verify OS
function test_verify_os() {
    echo_step "Test 1: Verify Operating System"

    if [ ! -f /etc/os-release ]; then
        echo_fail "OS verification: /etc/os-release not found"
        echo_error "This script must be run on a Linux system"
        exit 1
    fi

    . /etc/os-release

    echo_test "Checking OS type..."
    case "${ID}" in
        rhel|rocky|almalinux)
            echo_pass "OS type: ${NAME} (${ID})"
            ;;
        *)
            echo_fail "OS type: ${ID} is not supported"
            echo_error "This script requires RHEL, Rocky Linux, or AlmaLinux"
            exit 1
            ;;
    esac

    echo_test "Checking OS version..."
    OS_VERSION="${VERSION_ID%%.*}"
    if [ "${OS_VERSION}" == "10" ]; then
        echo_pass "OS version: ${VERSION_ID} (RHEL 10 - fully supported)"
    elif [ "${OS_VERSION}" == "9" ] || [ "${OS_VERSION}" == "8" ]; then
        echo_warn "OS version: ${VERSION_ID} (RHEL ${OS_VERSION} - compatibility mode)"
    else
        echo_fail "OS version: ${VERSION_ID} is not supported"
        echo_error "This script requires RHEL 8, 9, or 10"
        exit 1
    fi

    echo ""
}

# Test 2: Run build
function test_run_build() {
    if [ "${SKIP_BUILD}" == "true" ]; then
        echo_step "Test 2: Build (SKIPPED)"
        echo_info "Skipping build as requested"
        echo ""
        return 0
    fi

    echo_step "Test 2: Run RPM Package Build"

    if [ ! -x "${BUILD_SCRIPT}" ]; then
        echo_fail "Build script not found or not executable: ${BUILD_SCRIPT}"
        exit 1
    fi

    echo_test "Running build_rpm_packages.sh..."
    if "${BUILD_SCRIPT}"; then
        echo_pass "Build script completed successfully"
    else
        echo_fail "Build script failed"
        echo_error "Check build logs above for details"
        exit 1
    fi

    echo ""
}

# Test 3: Verify package creation
function test_verify_packages() {
    echo_step "Test 3: Verify RPM Packages Created"

    if [ ! -d "${OUTPUT_DIR}" ]; then
        echo_fail "Output directory not found: ${OUTPUT_DIR}"
        exit 1
    fi

    echo_test "Checking output directory: ${OUTPUT_DIR}"

    local all_found=true
    for pkg_name in "${EXPECTED_PACKAGES[@]}"; do
        if ls "${OUTPUT_DIR}/${pkg_name}"-*.rpm 1> /dev/null 2>&1; then
            local rpm_file=$(ls "${OUTPUT_DIR}/${pkg_name}"-*.rpm | head -n1)
            local rpm_size=$(du -h "${rpm_file}" | cut -f1)
            echo_pass "Package found: $(basename ${rpm_file}) (${rpm_size})"
        else
            echo_fail "Package NOT found: ${pkg_name}-*.rpm"
            all_found=false
        fi
    done

    if [ "${all_found}" == "true" ]; then
        echo_pass "All 6 expected packages found"
    else
        echo_fail "Some packages are missing"
    fi

    # List all packages
    echo_info "All packages in output directory:"
    ls -lh "${OUTPUT_DIR}"/*.rpm

    echo ""
}

# Test 4: Verify SELinux policy modules
function test_verify_selinux_policies() {
    echo_step "Test 4: Verify SELinux Policy Modules"

    # Check for SELinux policy modules in packages
    echo_test "Checking for SELinux policy modules..."

    local policies_found=0

    # Check cuttlefish-base for cuttlefish_host_resources.pp
    if ls "${OUTPUT_DIR}/cuttlefish-base"-*.rpm 1> /dev/null 2>&1; then
        local base_rpm=$(ls "${OUTPUT_DIR}/cuttlefish-base"-*.rpm | head -n1)
        if rpm -qlp "${base_rpm}" 2>/dev/null | grep -q "cuttlefish_host_resources.pp"; then
            echo_pass "cuttlefish-base contains cuttlefish_host_resources.pp"
            ((policies_found++))
        else
            echo_fail "cuttlefish-base missing cuttlefish_host_resources.pp"
        fi
    fi

    # Check cuttlefish-user for cuttlefish_operator.pp
    if ls "${OUTPUT_DIR}/cuttlefish-user"-*.rpm 1> /dev/null 2>&1; then
        local user_rpm=$(ls "${OUTPUT_DIR}/cuttlefish-user"-*.rpm | head -n1)
        if rpm -qlp "${user_rpm}" 2>/dev/null | grep -q "cuttlefish_operator.pp"; then
            echo_pass "cuttlefish-user contains cuttlefish_operator.pp"
            ((policies_found++))
        else
            echo_fail "cuttlefish-user missing cuttlefish_operator.pp"
        fi
    fi

    # Check cuttlefish-orchestration for cuttlefish_orchestration.pp
    if ls "${OUTPUT_DIR}/cuttlefish-orchestration"-*.rpm 1> /dev/null 2>&1; then
        local orch_rpm=$(ls "${OUTPUT_DIR}/cuttlefish-orchestration"-*.rpm | head -n1)
        if rpm -qlp "${orch_rpm}" 2>/dev/null | grep -q "cuttlefish_orchestration.pp"; then
            echo_pass "cuttlefish-orchestration contains cuttlefish_orchestration.pp"
            ((policies_found++))
        else
            echo_fail "cuttlefish-orchestration missing cuttlefish_orchestration.pp"
        fi
    fi

    if [ ${policies_found} -eq 3 ]; then
        echo_pass "All 3 SELinux policy modules found in packages"
    else
        echo_fail "Expected 3 SELinux policy modules, found ${policies_found}"
    fi

    echo ""
}

# Test 5: Run rpmlint validation
function test_run_rpmlint() {
    echo_step "Test 5: Run rpmlint Validation"

    # Check if rpmlint is installed
    if ! command -v rpmlint &> /dev/null; then
        echo_fail "rpmlint not installed"
        echo_error "Install with: sudo dnf install rpmlint"
        return 1
    fi

    # Copy .rpmlintrc to home directory
    if [ -f "${REPO_DIR}/.rpmlintrc" ]; then
        cp "${REPO_DIR}/.rpmlintrc" ~/
        echo_info "Using .rpmlintrc configuration from repository"
    else
        echo_warn ".rpmlintrc not found in repository"
    fi

    # Run rpmlint on all packages
    echo_test "Running rpmlint on all packages..."

    local rpmlint_output="${REPO_DIR}/rpmlint-output.txt"
    if rpmlint "${OUTPUT_DIR}"/*.rpm > "${rpmlint_output}" 2>&1; then
        echo_pass "rpmlint validation passed with no errors"
    else
        # rpmlint returns non-zero for warnings too, so check the output
        local error_count=$(grep -c "^E:" "${rpmlint_output}" || true)
        local warning_count=$(grep -c "^W:" "${rpmlint_output}" || true)

        if [ ${error_count} -gt 0 ]; then
            echo_fail "rpmlint found ${error_count} errors"
            echo_info "Showing errors:"
            grep "^E:" "${rpmlint_output}" || true
        else
            echo_pass "rpmlint found no errors"
        fi

        if [ ${warning_count} -gt 0 ]; then
            echo_warn "rpmlint found ${warning_count} warnings (may be acceptable per .rpmlintrc)"
            echo_info "Showing warnings:"
            grep "^W:" "${rpmlint_output}" | head -n 10
            if [ ${warning_count} -gt 10 ]; then
                echo_info "... (${warning_count} total warnings, showing first 10)"
            fi
        fi

        echo_info "Full rpmlint output saved to: ${rpmlint_output}"
    fi

    echo ""
}

# Test 6: Verify package metadata
function test_verify_package_metadata() {
    echo_step "Test 6: Verify Package Metadata"

    for pkg_name in "${EXPECTED_PACKAGES[@]}"; do
        if ! ls "${OUTPUT_DIR}/${pkg_name}"-*.rpm 1> /dev/null 2>&1; then
            echo_warn "Skipping ${pkg_name} (not found)"
            continue
        fi

        local rpm_file=$(ls "${OUTPUT_DIR}/${pkg_name}"-*.rpm | head -n1)

        echo_test "Verifying ${pkg_name}..."

        # Check Name
        local name=$(rpm -qp --queryformat '%{NAME}' "${rpm_file}" 2>/dev/null)
        if [ "${name}" == "${pkg_name}" ]; then
            echo "  ✓ Name: ${name}"
        else
            echo_fail "  ${pkg_name}: Name mismatch (got: ${name})"
        fi

        # Check Version
        local version=$(rpm -qp --queryformat '%{VERSION}' "${rpm_file}" 2>/dev/null)
        echo "  ✓ Version: ${version}"

        # Check Release
        local release=$(rpm -qp --queryformat '%{RELEASE}' "${rpm_file}" 2>/dev/null)
        echo "  ✓ Release: ${release}"

        # Check Architecture
        local arch=$(rpm -qp --queryformat '%{ARCH}' "${rpm_file}" 2>/dev/null)
        echo "  ✓ Architecture: ${arch}"

        # Check License
        local license=$(rpm -qp --queryformat '%{LICENSE}' "${rpm_file}" 2>/dev/null)
        echo "  ✓ License: ${license}"

        # Check if signed (optional)
        if rpm -qp --queryformat '%{SIGPGP:pgpsig}' "${rpm_file}" 2>/dev/null | grep -q "Key ID"; then
            echo "  ✓ Package is signed"
        else
            echo "  - Package is not signed (optional)"
        fi

        echo ""
    done

    echo_pass "Package metadata verification complete"
    echo ""
}

# Test 7: Verify package contents
function test_verify_package_contents() {
    echo_step "Test 7: Verify Package Contents"

    # Check cuttlefish-base
    if ls "${OUTPUT_DIR}/cuttlefish-base"-*.rpm 1> /dev/null 2>&1; then
        local base_rpm=$(ls "${OUTPUT_DIR}/cuttlefish-base"-*.rpm | head -n1)
        echo_test "Checking cuttlefish-base contents..."

        local has_binaries=$(rpm -qlp "${base_rpm}" 2>/dev/null | grep -c "/usr/lib/cuttlefish-common/bin/" || true)
        local has_systemd=$(rpm -qlp "${base_rpm}" 2>/dev/null | grep -c "cuttlefish-host-resources.service" || true)
        local has_config=$(rpm -qlp "${base_rpm}" 2>/dev/null | grep -c "/etc/sysconfig/" || true)

        if [ ${has_binaries} -gt 0 ]; then
            echo_pass "  cuttlefish-base contains binaries (${has_binaries} files)"
        else
            echo_fail "  cuttlefish-base missing binaries"
        fi

        if [ ${has_systemd} -gt 0 ]; then
            echo_pass "  cuttlefish-base contains systemd units"
        else
            echo_fail "  cuttlefish-base missing systemd units"
        fi

        if [ ${has_config} -gt 0 ]; then
            echo_pass "  cuttlefish-base contains config files"
        else
            echo_fail "  cuttlefish-base missing config files"
        fi
    fi

    # Check cuttlefish-user
    if ls "${OUTPUT_DIR}/cuttlefish-user"-*.rpm 1> /dev/null 2>&1; then
        local user_rpm=$(ls "${OUTPUT_DIR}/cuttlefish-user"-*.rpm | head -n1)
        echo_test "Checking cuttlefish-user contents..."

        local has_operator=$(rpm -qlp "${user_rpm}" 2>/dev/null | grep -c "/usr/lib/cuttlefish-common/bin/operator" || true)

        if [ ${has_operator} -gt 0 ]; then
            echo_pass "  cuttlefish-user contains operator binary"
        else
            echo_fail "  cuttlefish-user missing operator binary"
        fi
    fi

    # Check cuttlefish-orchestration
    if ls "${OUTPUT_DIR}/cuttlefish-orchestration"-*.rpm 1> /dev/null 2>&1; then
        local orch_rpm=$(ls "${OUTPUT_DIR}/cuttlefish-orchestration"-*.rpm | head -n1)
        echo_test "Checking cuttlefish-orchestration contents..."

        local has_orchestrator=$(rpm -qlp "${orch_rpm}" 2>/dev/null | grep -c "/usr/lib/cuttlefish-common/bin/host_orchestrator" || true)

        if [ ${has_orchestrator} -gt 0 ]; then
            echo_pass "  cuttlefish-orchestration contains host_orchestrator binary"
        else
            echo_fail "  cuttlefish-orchestration missing host_orchestrator binary"
        fi
    fi

    echo ""
}

# Generate summary report
function generate_summary() {
    echo "=========================================="
    echo "Verification Summary"
    echo "=========================================="
    echo ""
    echo "Tests passed:  ${GREEN}${TESTS_PASSED}${NC}"
    echo "Tests failed:  ${RED}${TESTS_FAILED}${NC}"
    echo "Tests warned:  ${YELLOW}${TESTS_WARNED}${NC}"
    echo ""

    if [ ${TESTS_FAILED} -eq 0 ]; then
        echo -e "${GREEN}✓ All critical tests passed!${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Install packages: sudo dnf install ${OUTPUT_DIR}/cuttlefish-common-*.rpm"
        echo "  2. Test services: sudo systemctl status cuttlefish-host-resources"
        echo "  3. Check SELinux: sudo semodule -l | grep cuttlefish"
        echo ""
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        echo ""
        echo "Please review the failures above and:"
        echo "  1. Check the build logs"
        echo "  2. Verify all dependencies are installed"
        echo "  3. Ensure SELinux policies compiled correctly"
        echo "  4. Review spec files for errors"
        echo ""
        return 1
    fi
}

# Main execution
function main() {
    start_verification
    test_verify_os
    test_run_build
    test_verify_packages
    test_verify_selinux_policies
    test_run_rpmlint
    test_verify_package_metadata
    test_verify_package_contents
    generate_summary
}

# Run main function
main "$@"
