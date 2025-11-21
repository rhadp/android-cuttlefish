#!/bin/bash
#
# Verify RHEL dependency mapping completeness
#
# This script:
# 1. Extracts all dependencies from RPM spec files
# 2. Verifies each package exists in RHEL repositories (requires RHEL system)
# 3. Reports any missing or unmapped dependencies
#
# Copyright (C) 2025 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
total_deps=0
available_deps=0
missing_deps=0
unknown_deps=0

# Arrays for missing packages
declare -a missing_packages
declare -a unknown_packages

echo "========================================"
echo "Cuttlefish RHEL Dependency Verification"
echo "========================================"
echo ""

# Check if running on RHEL-compatible system
if [ -f /etc/os-release ]; then
    source /etc/os-release
    if [[ "$ID" =~ ^(rhel|fedora)$ ]]; then
        echo -e "${GREEN}✓${NC} Running on RPM-based system: $PRETTY_NAME"
        can_test_dnf=true
    else
        echo -e "${YELLOW}⚠${NC} Not running on RPM-based system: $PRETTY_NAME"
        echo "  Package availability checks will be skipped"
        can_test_dnf=false
    fi
else
    echo -e "${YELLOW}⚠${NC} Cannot detect OS, assuming non-RPM system"
    echo "  Package availability checks will be skipped"
    can_test_dnf=false
fi
echo ""

# Function to extract dependencies from spec file
extract_deps_from_spec() {
    local spec_file="$1"
    local package_name=$(basename "$spec_file" .spec)

    echo "Analyzing: $package_name"

    # Extract BuildRequires
    local build_deps=$(grep '^BuildRequires:' "$spec_file" | sed 's/BuildRequires:[[:space:]]*//' | awk '{print $1}')

    # Extract Requires
    local runtime_deps=$(grep '^Requires:' "$spec_file" | sed 's/Requires:[[:space:]]*//' | awk '{print $1}')

    # Combine and deduplicate
    local all_deps=$(echo -e "$build_deps\n$runtime_deps" | sort -u | grep -v '^$')

    # Check each dependency
    for dep in $all_deps; do
        # Skip cuttlefish-* internal dependencies
        if [[ "$dep" =~ ^cuttlefish- ]]; then
            continue
        fi

        total_deps=$((total_deps + 1))

        if [ "$can_test_dnf" = true ]; then
            # Test with dnf info
            if dnf info "$dep" &>/dev/null; then
                echo -e "  ${GREEN}✓${NC} $dep"
                available_deps=$((available_deps + 1))
            else
                # Try with dnf search as fallback
                if dnf search "$dep" &>/dev/null | grep -q "$dep"; then
                    echo -e "  ${YELLOW}?${NC} $dep (found via search, may need repository enabled)"
                    unknown_packages+=("$dep")
                    unknown_deps=$((unknown_deps + 1))
                else
                    echo -e "  ${RED}✗${NC} $dep (NOT FOUND)"
                    missing_packages+=("$dep")
                    missing_deps=$((missing_deps + 1))
                fi
            fi
        else
            echo -e "  ${BLUE}·${NC} $dep (not verified)"
        fi
    done

    echo ""
}

# Check base package specs
echo "=== Base Packages ==="
for spec in base/rhel/*.spec; do
    if [ -f "$spec" ]; then
        extract_deps_from_spec "$spec"
    fi
done

# Check frontend package specs
echo "=== Frontend Packages ==="
for spec in frontend/rhel/*.spec; do
    if [ -f "$spec" ]; then
        extract_deps_from_spec "$spec"
    fi
done

# Summary
echo "========================================"
echo "Summary"
echo "========================================"
echo "Total dependencies checked: $total_deps"

if [ "$can_test_dnf" = true ]; then
    echo -e "Available packages:        ${GREEN}$available_deps${NC}"
    echo -e "Missing packages:          ${RED}$missing_deps${NC}"
    echo -e "Unknown packages:          ${YELLOW}$unknown_deps${NC}"

    if [ $missing_deps -gt 0 ]; then
        echo ""
        echo -e "${RED}Missing Packages:${NC}"
        for pkg in "${missing_packages[@]}"; do
            echo "  - $pkg"
        done
        echo ""
        echo "These packages may require:"
        echo "  1. Enabling EPEL repository:      dnf install epel-release"
        echo "  2. Enabling CRB repository:       dnf config-manager --set-enabled crb"
        echo "  3. Enabling vbatts/bazel Copr:    dnf copr enable vbatts/bazel"
        echo "  4. Installing from source or alternative repositories"
    fi

    if [ $unknown_deps -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}Unknown Packages (may need repository enabled):${NC}"
        for pkg in "${unknown_packages[@]}"; do
            echo "  - $pkg"
        done
    fi

    echo ""

    if [ $missing_deps -gt 0 ]; then
        echo -e "${RED}✗ Dependency verification FAILED${NC}"
        echo "  Please resolve missing dependencies before building RPM packages"
        exit 1
    elif [ $unknown_deps -gt 0 ]; then
        echo -e "${YELLOW}⚠ Dependency verification completed with warnings${NC}"
        echo "  Some packages may require additional repositories to be enabled"
        exit 0
    else
        echo -e "${GREEN}✓ All dependencies are available${NC}"
        exit 0
    fi
else
    echo "Verification skipped (not on RHEL-compatible system)"
    echo ""
    echo "To verify dependencies on a RHEL system:"
    echo "  1. Transfer this repository to a RHEL 10 system"
    echo "  2. Enable required repositories (EPEL, CRB)"
    echo "  3. Run this script again: ./tools/buildutils/verify_rhel_deps.sh"
    echo ""
    echo -e "${BLUE}Dependency extraction completed successfully${NC}"
    exit 0
fi
