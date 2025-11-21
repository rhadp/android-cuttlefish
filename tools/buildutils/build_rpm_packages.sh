#!/usr/bin/env bash
#
# Build Cuttlefish RPM packages for RHEL 10 and compatible distributions
#
# This script:
# - Detects OS type and verifies RHEL/Rocky/AlmaLinux 10
# - Installs build dependencies
# - Sets up RPM build environment
# - Extracts version from debian/changelog
# - Creates source tarballs
# - Compiles SELinux policy modules
# - Builds all 6 RPM packages
# - Runs rpmlint validation
# - Copies packages to output directory

set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function echo_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

function echo_step() {
    echo -e "${BLUE}[STEP]${NC} $*"
}

function echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

function echo_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Get repository root directory
REPO_DIR="$(realpath "$(dirname "$0")/../..")"
SCRIPT_DIR="$(dirname "$0")"
GET_VERSION="${SCRIPT_DIR}/get_version.sh"
INSTALL_DEPS="${SCRIPT_DIR}/install_rhel10_deps.sh"

# Output directory for built packages
OUTPUT_DIR="${REPO_DIR}/rpm-packages"

# Detect OS type
function detect_os() {
    echo_step "Detecting OS type..."

    if [ ! -f /etc/os-release ]; then
        echo_error "/etc/os-release not found. Cannot detect OS."
        exit 1
    fi

    . /etc/os-release

    OS_ID="${ID}"
    OS_VERSION_ID="${VERSION_ID%%.*}"
    OS_NAME="${NAME}"

    echo_info "Detected: ${OS_NAME} (ID: ${OS_ID}, Version: ${OS_VERSION_ID})"

    # Verify RHEL or compatible
    case "${OS_ID}" in
        rhel|rocky|almalinux)
            echo_info "OS verification passed"
            ;;
        *)
            echo_error "Unsupported OS: ${OS_ID}"
            echo_error "This script only supports RHEL, Rocky Linux, and AlmaLinux"
            exit 1
            ;;
    esac

    # Prefer RHEL 10, but support 8 and 9
    if [ "${OS_VERSION_ID}" != "10" ] && [ "${OS_VERSION_ID}" != "9" ] && [ "${OS_VERSION_ID}" != "8" ]; then
        echo_warn "This script is designed for RHEL 10, you are running version ${OS_VERSION_ID}"
        echo_warn "Some features may not work as expected"
    fi
}

# Install build dependencies
function install_dependencies() {
    echo_step "Installing build dependencies..."

    if [ ! -x "${INSTALL_DEPS}" ]; then
        echo_error "Dependency installation script not found or not executable: ${INSTALL_DEPS}"
        exit 1
    fi

    # Run installation script
    "${INSTALL_DEPS}"
}

# Setup RPM build directory structure
function setup_rpmbuild_tree() {
    echo_step "Setting up RPM build directory structure..."

    # Use rpmdev-setuptree to create standard directory structure
    rpmdev-setuptree

    echo_info "RPM build tree created at ~/rpmbuild/"
    ls -la ~/rpmbuild/
}

# Extract version from debian/changelog
function extract_versions() {
    echo_step "Extracting package versions..."

    if [ ! -x "${GET_VERSION}" ]; then
        echo_error "Version extraction script not found: ${GET_VERSION}"
        exit 1
    fi

    # Extract base package version
    BASE_VERSION=$("${GET_VERSION}" "${REPO_DIR}/base/debian/changelog")
    echo_info "Base package version: ${BASE_VERSION}"

    # Extract frontend package version
    FRONTEND_VERSION=$("${GET_VERSION}" "${REPO_DIR}/frontend/debian/changelog")
    echo_info "Frontend package version: ${FRONTEND_VERSION}"

    export BASE_VERSION FRONTEND_VERSION
}

# Create source tarballs
function create_source_tarballs() {
    echo_step "Creating source tarballs..."

    cd "${REPO_DIR}"

    # Create base source tarball
    echo_info "Creating cuttlefish-base-${BASE_VERSION}.tar.gz..."
    tar --exclude='.git' \
        --exclude='*.pyc' \
        --exclude='__pycache__' \
        --exclude='bazel-*' \
        --exclude='.bazel*' \
        --dereference \
        -czf ~/rpmbuild/SOURCES/cuttlefish-base-${BASE_VERSION}.tar.gz \
        -C "${REPO_DIR}" \
        base/ \
        cvd/ \
        shared/ \
        tools/

    echo_info "Base source tarball size: $(du -h ~/rpmbuild/SOURCES/cuttlefish-base-${BASE_VERSION}.tar.gz | cut -f1)"

    # Create frontend source tarball
    echo_info "Creating cuttlefish-frontend-${FRONTEND_VERSION}.tar.gz..."
    tar --exclude='.git' \
        --exclude='*.pyc' \
        --exclude='__pycache__' \
        --exclude='bazel-*' \
        --exclude='.bazel*' \
        --dereference \
        -czf ~/rpmbuild/SOURCES/cuttlefish-frontend-${FRONTEND_VERSION}.tar.gz \
        -C "${REPO_DIR}" \
        frontend/

    echo_info "Frontend source tarball size: $(du -h ~/rpmbuild/SOURCES/cuttlefish-frontend-${FRONTEND_VERSION}.tar.gz | cut -f1)"

    echo_info "Source tarballs created successfully"
    ls -lh ~/rpmbuild/SOURCES/
}

# Copy spec files to RPM build directory
function copy_spec_files() {
    echo_step "Copying spec files..."

    # Copy all spec files from base/rhel/ and frontend/rhel/
    find "${REPO_DIR}/base/rhel" "${REPO_DIR}/frontend/rhel" -name "*.spec" -type f | while read spec_file; do
        echo_info "Copying $(basename ${spec_file})..."
        cp "${spec_file}" ~/rpmbuild/SPECS/
    done

    echo_info "Spec files copied:"
    ls -1 ~/rpmbuild/SPECS/*.spec
}

# Compile SELinux policy modules
function compile_selinux_policies() {
    echo_step "Compiling SELinux policy modules..."

    # Compile base SELinux policies
    if [ -d "${REPO_DIR}/base/rhel/selinux" ]; then
        echo_info "Compiling base SELinux policies..."
        cd "${REPO_DIR}/base/rhel/selinux"
        if [ -f Makefile ]; then
            make clean || true
            make all
            # Copy compiled .pp files to SOURCES
            find . -name "*.pp" -type f -exec cp {} ~/rpmbuild/SOURCES/ \;
        else
            echo_warn "No Makefile found in base/rhel/selinux"
        fi
    fi

    # Compile frontend SELinux policies
    if [ -d "${REPO_DIR}/frontend/rhel/selinux" ]; then
        echo_info "Compiling frontend SELinux policies..."
        cd "${REPO_DIR}/frontend/rhel/selinux"
        if [ -f Makefile ]; then
            make clean || true
            make all
            # Copy compiled .pp files to SOURCES
            find . -name "*.pp" -type f -exec cp {} ~/rpmbuild/SOURCES/ \;
        else
            echo_warn "No Makefile found in frontend/rhel/selinux"
        fi
    fi

    echo_info "SELinux policy modules compiled:"
    ls -lh ~/rpmbuild/SOURCES/*.pp 2>/dev/null || echo_warn "No .pp files found"

    cd "${REPO_DIR}"
}

# Build RPM packages
function build_rpm_packages() {
    echo_step "Building RPM packages..."

    cd ~/rpmbuild/SPECS

    # List of spec files to build (in dependency order)
    SPEC_FILES=(
        "cuttlefish-base.spec"
        "cuttlefish-integration.spec"
        "cuttlefish-defaults.spec"
        "cuttlefish-user.spec"
        "cuttlefish-orchestration.spec"
        "cuttlefish-common.spec"
    )

    for spec_file in "${SPEC_FILES[@]}"; do
        if [ ! -f "${spec_file}" ]; then
            echo_warn "Spec file not found: ${spec_file}, skipping..."
            continue
        fi

        echo_info "Building package from ${spec_file}..."

        # Build both source and binary RPMs
        rpmbuild -ba "${spec_file}" || {
            echo_error "Failed to build ${spec_file}"
            echo_error "Check build log above for details"
            exit 1
        }

        echo_info "Successfully built ${spec_file}"
    done

    echo_info "All RPM packages built successfully"
    echo_info "Binary packages:"
    ls -lh ~/rpmbuild/RPMS/*/*.rpm 2>/dev/null || true
    echo_info "Source packages:"
    ls -lh ~/rpmbuild/SRPMS/*.rpm 2>/dev/null || true
}

# Run rpmlint on built packages
function run_rpmlint() {
    echo_step "Running rpmlint validation..."

    # Copy .rpmlintrc to home directory for rpmlint to find it
    if [ -f "${REPO_DIR}/.rpmlintrc" ]; then
        cp "${REPO_DIR}/.rpmlintrc" ~/
        echo_info "Using .rpmlintrc configuration from repository"
    fi

    # Run rpmlint on all built RPMs
    echo_info "Checking binary packages..."
    if ls ~/rpmbuild/RPMS/*/*.rpm 1> /dev/null 2>&1; then
        rpmlint ~/rpmbuild/RPMS/*/*.rpm || {
            echo_warn "rpmlint found issues in binary packages"
            echo_warn "Review the warnings above (some may be acceptable per .rpmlintrc)"
        }
    fi

    echo_info "Checking source packages..."
    if ls ~/rpmbuild/SRPMS/*.rpm 1> /dev/null 2>&1; then
        rpmlint ~/rpmbuild/SRPMS/*.rpm || {
            echo_warn "rpmlint found issues in source packages"
            echo_warn "Review the warnings above (some may be acceptable per .rpmlintrc)"
        }
    fi

    echo_info "rpmlint validation complete"
}

# Copy built packages to output directory
function copy_packages_to_output() {
    echo_step "Copying packages to output directory..."

    # Create output directory
    mkdir -p "${OUTPUT_DIR}"

    # Copy binary RPMs
    if ls ~/rpmbuild/RPMS/*/*.rpm 1> /dev/null 2>&1; then
        echo_info "Copying binary packages..."
        cp ~/rpmbuild/RPMS/*/*.rpm "${OUTPUT_DIR}/"
    fi

    # Copy source RPMs
    if ls ~/rpmbuild/SRPMS/*.rpm 1> /dev/null 2>&1; then
        echo_info "Copying source packages..."
        cp ~/rpmbuild/SRPMS/*.rpm "${OUTPUT_DIR}/"
    fi

    echo_info "Packages copied to: ${OUTPUT_DIR}"
    echo_info "Package list:"
    ls -lh "${OUTPUT_DIR}"/*.rpm
}

# Generate build summary
function print_summary() {
    echo ""
    echo "=========================================="
    echo "RPM Build Summary"
    echo "=========================================="
    echo ""
    echo "Repository: ${REPO_DIR}"
    echo "Base version: ${BASE_VERSION}"
    echo "Frontend version: ${FRONTEND_VERSION}"
    echo ""
    echo "Built packages:"
    ls -1 "${OUTPUT_DIR}"/*.rpm 2>/dev/null | while read pkg; do
        echo "  - $(basename ${pkg})"
    done
    echo ""
    echo "Output directory: ${OUTPUT_DIR}"
    echo ""
    echo "To install packages:"
    echo "  sudo dnf install ${OUTPUT_DIR}/cuttlefish-common-*.rpm"
    echo ""
    echo "To create a repository:"
    echo "  createrepo_c ${OUTPUT_DIR}"
    echo ""
    echo "=========================================="
}

# Main execution
function main() {
    echo_info "Starting Cuttlefish RPM package build..."
    echo_info "Repository: ${REPO_DIR}"
    echo ""

    detect_os
    install_dependencies
    setup_rpmbuild_tree
    extract_versions
    create_source_tarballs
    copy_spec_files
    compile_selinux_policies
    build_rpm_packages
    run_rpmlint
    copy_packages_to_output
    print_summary

    echo_info "Build complete!"
}

# Run main function
main "$@"
