#!/usr/bin/env bash
#
# Install RHEL 10 build dependencies for Cuttlefish RPM packages
#
# This script:
# - Detects RHEL version or Fedora
# - Enables required repositories (EPEL, CRB/PowerTools)
# - Installs Bazel (Bazelisk preferred, fallback to Copr)
# - Installs RPM build tools and SELinux policy development tools
# - Installs all build dependencies from spec files

set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function echo_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

function echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

function echo_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Task 9.1.1: Detect RHEL version and derivative
function detect_os() {
    echo_info "Detecting OS version and derivative..."

    if [ ! -f /etc/os-release ]; then
        echo_error "/etc/os-release not found. Cannot detect OS."
        exit 1
    fi

    # Source OS release info
    . /etc/os-release

    OS_ID="${ID}"
    OS_VERSION_ID="${VERSION_ID%%.*}"  # Extract major version (e.g., "10" from "10.0")
    OS_NAME="${NAME}"

    echo_info "Detected OS: ${OS_NAME} (ID: ${OS_ID}, Version: ${OS_VERSION_ID})"

    # Verify RHEL 10 or Fedora
    case "${OS_ID}" in
        rhel)
            if [ "${OS_VERSION_ID}" != "10" ] && [ "${OS_VERSION_ID}" != "8" ] && [ "${OS_VERSION_ID}" != "9" ]; then
                echo_error "Unsupported RHEL version: ${OS_VERSION_ID}"
                echo_error "This script supports RHEL 8, 9, and 10"
                exit 1
            fi
            echo_info "OS verification passed: ${OS_ID} ${OS_VERSION_ID} is supported"
            ;;
        fedora)
            # Fedora uses different version numbers (e.g., 39, 40, 41)
            # We accept any recent Fedora version (38+)
            if [ "${OS_VERSION_ID}" -lt 38 ]; then
                echo_warn "Fedora version ${OS_VERSION_ID} is quite old, recommend Fedora 39+"
            fi
            echo_info "OS verification passed: Fedora ${OS_VERSION_ID} is supported"
            ;;
        *)
            echo_error "Unsupported OS: ${OS_ID}"
            echo_error "This script only supports RHEL and Fedora"
            exit 1
            ;;
    esac

    export OS_ID OS_VERSION_ID OS_NAME
}

# Task 9.1.2: Set repository names based on OS version
function set_repo_names() {
    echo_info "Setting repository names for ${OS_ID} ${OS_VERSION_ID}..."

    # CRB/PowerTools repository name varies by version (RHEL only)
    if [ "${OS_ID}" == "rhel" ]; then
        case "${OS_VERSION_ID}" in
            10|9)
                CRB_REPO="crb"
                ;;
            8)
                CRB_REPO="powertools"
                ;;
            *)
                echo_error "Unknown RHEL version for repository naming: ${OS_VERSION_ID}"
                exit 1
                ;;
        esac
        echo_info "Using repository name: ${CRB_REPO}"
        export CRB_REPO
    elif [ "${OS_ID}" == "fedora" ]; then
        # Fedora doesn't use CRB/PowerTools, all packages are in main repos
        echo_info "Fedora uses default repositories (no CRB/PowerTools needed)"
        CRB_REPO=""
        export CRB_REPO
    fi
}

# Task 9.1.3: Enable required repositories
function enable_repositories() {
    echo_info "Enabling required repositories..."

    if [ "${OS_ID}" == "rhel" ]; then
        # Enable EPEL repository (RHEL only)
        if ! rpm -q epel-release &>/dev/null; then
            echo_info "Installing EPEL repository..."
            sudo dnf install -y epel-release
        else
            echo_info "EPEL repository already installed"
        fi

        # Enable CRB/PowerTools repository (RHEL only)
        echo_info "Enabling ${CRB_REPO} repository..."
        if ! sudo dnf config-manager --set-enabled "${CRB_REPO}" 2>/dev/null; then
            echo_warn "Failed to enable ${CRB_REPO} using config-manager, trying alternative method..."
            # For some systems, might need to use dnf config-manager differently
            sudo dnf config-manager --enable "${CRB_REPO}" 2>/dev/null || \
                echo_warn "Could not enable ${CRB_REPO}. Some dependencies might be missing."
        fi
    elif [ "${OS_ID}" == "fedora" ]; then
        # Fedora has all packages in default repositories
        echo_info "Fedora default repositories already enabled"
    fi

    # Enable vbatts/bazel Copr repository (backup method for Bazel)
    echo_info "Enabling vbatts/bazel Copr repository..."
    if command -v dnf &>/dev/null; then
        sudo dnf install -y 'dnf-command(copr)' || echo_warn "Could not install dnf-copr plugin"
        sudo dnf copr enable -y vbatts/bazel 2>/dev/null || echo_warn "Could not enable vbatts/bazel Copr"
    fi

    # Update repository metadata
    echo_info "Updating repository metadata..."
    sudo dnf makecache
}

# Task 9.1.4: Install Bazel
function install_bazel() {
    echo_info "Installing Bazel..."

    # Check if Bazel is already installed
    if command -v bazel &>/dev/null; then
        BAZEL_VERSION=$(bazel version 2>/dev/null | grep "Build label" | awk '{print $3}' || echo "unknown")
        echo_info "Bazel already installed: ${BAZEL_VERSION}"
        return 0
    fi

    # Check for .bazelversion file
    REPO_DIR="$(realpath "$(dirname "$0")/../..")"
    if [ -f "${REPO_DIR}/.bazelversion" ]; then
        REQUIRED_BAZEL_VERSION=$(cat "${REPO_DIR}/.bazelversion")
        echo_info "Required Bazel version from .bazelversion: ${REQUIRED_BAZEL_VERSION}"
    else
        echo_warn ".bazelversion file not found, will install latest Bazel"
    fi

    # Try installing Bazelisk (primary method)
    echo_info "Attempting to install Bazelisk from GitHub releases..."
    ARCH=$(uname -m)
    case "${ARCH}" in
        x86_64)
            BAZELISK_ARCH="amd64"
            ;;
        aarch64)
            BAZELISK_ARCH="arm64"
            ;;
        *)
            echo_warn "Unsupported architecture for Bazelisk: ${ARCH}"
            BAZELISK_ARCH=""
            ;;
    esac

    if [ -n "${BAZELISK_ARCH}" ]; then
        BAZELISK_URL="https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-${BAZELISK_ARCH}"
        if sudo wget -O /usr/local/bin/bazelisk "${BAZELISK_URL}" 2>/dev/null; then
            sudo chmod +x /usr/local/bin/bazelisk
            sudo ln -sf /usr/local/bin/bazelisk /usr/local/bin/bazel
            echo_info "Bazelisk installed successfully"
            bazel version
            return 0
        else
            echo_warn "Failed to download Bazelisk from GitHub"
        fi
    fi

    # Fallback: Try installing from vbatts/bazel Copr
    echo_info "Attempting to install Bazel from vbatts/bazel Copr..."
    if sudo dnf install -y bazel 2>/dev/null; then
        echo_info "Bazel installed from Copr repository"
        bazel version
        return 0
    else
        echo_warn "Failed to install Bazel from Copr"
    fi

    # All methods failed
    echo_error "Failed to install Bazel using all available methods"
    echo_error ""
    echo_error "Please install Bazel manually using one of these methods:"
    echo_error ""
    echo_error "1. Install Bazelisk:"
    echo_error "   wget https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64"
    echo_error "   chmod +x bazelisk-linux-amd64"
    echo_error "   sudo mv bazelisk-linux-amd64 /usr/local/bin/bazelisk"
    echo_error "   sudo ln -s /usr/local/bin/bazelisk /usr/local/bin/bazel"
    echo_error ""
    echo_error "2. Install from Copr:"
    echo_error "   sudo dnf copr enable vbatts/bazel"
    echo_error "   sudo dnf install bazel"
    echo_error ""
    echo_error "3. See https://bazel.build/install for more options"
    exit 1
}

# Task 9.1.5: Install build tools
function install_build_tools() {
    echo_info "Installing RPM build tools..."

    sudo dnf install -y \
        rpm-build \
        rpmdevtools \
        rpmlint \
        mock \
        createrepo_c

    echo_info "Installing SELinux policy development tools..."
    sudo dnf install -y \
        selinux-policy-devel \
        checkpolicy \
        policycoreutils \
        policycoreutils-python-utils

    echo_info "Build tools installed successfully"
}

# Task 9.1.6: Install all build dependencies from spec files
function install_build_dependencies() {
    echo_info "Installing build dependencies from spec files..."

    REPO_DIR="$(realpath "$(dirname "$0")/../..")"

    # Find all spec files
    SPEC_FILES=$(find "${REPO_DIR}" -name "*.spec" -type f)

    if [ -z "${SPEC_FILES}" ]; then
        echo_warn "No spec files found in repository"
        return 0
    fi

    # Extract unique BuildRequires from all spec files
    echo_info "Parsing BuildRequires from spec files..."
    DEPENDENCIES=$(grep "^BuildRequires:" ${SPEC_FILES} | \
        awk '{print $2}' | \
        sort -u | \
        grep -v "^$")

    if [ -z "${DEPENDENCIES}" ]; then
        echo_warn "No BuildRequires found in spec files"
        return 0
    fi

    echo_info "Found $(echo "${DEPENDENCIES}" | wc -l) unique build dependencies"

    # Install dependencies
    # Note: Some packages might not be available, so we don't exit on error
    echo_info "Installing dependencies (this may take a while)..."

    FAILED_PACKAGES=""
    for pkg in ${DEPENDENCIES}; do
        echo_info "Installing ${pkg}..."
        if ! sudo dnf install -y "${pkg}" 2>/dev/null; then
            echo_warn "Failed to install: ${pkg}"
            FAILED_PACKAGES="${FAILED_PACKAGES} ${pkg}"
        fi
    done

    if [ -n "${FAILED_PACKAGES}" ]; then
        echo_warn "The following packages could not be installed:${FAILED_PACKAGES}"
        echo_warn "Some builds may fail due to missing dependencies"
        echo_warn "Please verify these packages are available in your repositories"
    else
        echo_info "All build dependencies installed successfully"
    fi
}

# Main execution
function main() {
    echo_info "Starting RHEL 10 build dependency installation..."
    echo_info ""

    detect_os
    set_repo_names
    enable_repositories
    install_bazel
    install_build_tools
    install_build_dependencies

    echo_info ""
    echo_info "=========================================="
    echo_info "Build dependency installation complete!"
    echo_info "=========================================="
    echo_info ""
    echo_info "You can now build Cuttlefish RPM packages using:"
    echo_info "  ./tools/buildutils/build_rpm_packages.sh"
    echo_info ""
}

# Run main function
main "$@"
