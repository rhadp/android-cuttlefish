#!/usr/bin/env bash

set -e -x

# Detect OS type
function detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID}"
  else
    # Fallback: assume Debian-based if /etc/os-release doesn't exist
    OS_ID="debian"
  fi
  echo "${OS_ID}"
}

function install_debuild_dependencies() {
  echo "Installing debuild dependencies"
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y --allow-downgrades \
    -o Dpkg::Options::="--force-confold" \
    -o Dpkg::Options::="--force-confdef" \
    upgrade
  sudo apt-get install -y devscripts config-package-dev debhelper-compat equivs
}

REPO_DIR="$(realpath "$(dirname "$0")/../..")"
SCRIPT_DIR="$(dirname $0)"
INSTALL_BAZEL="${SCRIPT_DIR}/installbazel.sh"
BUILD_PACKAGE="${SCRIPT_DIR}/build_package.sh"
BUILD_RPM="${SCRIPT_DIR}/build_rpm_packages.sh"

# Detect operating system
OS_TYPE=$(detect_os)

case "${OS_TYPE}" in
  rhel|centos|fedora)
    # RHEL/CentOS Stream/Fedora system detected - use RPM build
    echo "Detected RPM-based system: ${OS_TYPE}"
    echo "Using RPM build process..."
    exec "${BUILD_RPM}" "$@"
    ;;
  debian|ubuntu)
    # Debian-based system detected - use DEB build
    echo "Detected Debian-based system: ${OS_TYPE}"
    echo "Using DEB build process..."
    command -v bazel &> /dev/null || sudo "${INSTALL_BAZEL}"
    install_debuild_dependencies
    "${BUILD_PACKAGE}" "${REPO_DIR}/base" $@
    "${BUILD_PACKAGE}" "${REPO_DIR}/frontend" $@
    ;;
  *)
    # Unsupported OS
    echo "ERROR: Unsupported operating system: ${OS_TYPE}" >&2
    echo "This script supports:" >&2
    echo "  - Debian-based: debian, ubuntu" >&2
    echo "  - RPM-based: rhel, centos, fedora" >&2
    exit 1
    ;;
esac
