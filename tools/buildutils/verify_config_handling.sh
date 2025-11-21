#!/bin/bash
#
# Verify Config File Handling in RPM Spec Files
#
# This script verifies that:
# 1. All config files in /etc/sysconfig/ use %config(noreplace)
# 2. All %postun scripts use proper systemd macros
# 3. All config files are properly marked
#
# Usage: ./verify_config_handling.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

echo "========================================"
echo "RPM Spec File Config Verification"
echo "========================================"
echo ""

# Function to print test result
print_result() {
    local status=$1
    local message=$2

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    case $status in
        "PASS")
            echo -e "${GREEN}✓${NC} $message"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            ;;
        "FAIL")
            echo -e "${RED}✗${NC} $message"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            ;;
        "WARN")
            echo -e "${YELLOW}⚠${NC} $message"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            ;;
    esac
}

# Find all spec files
SPEC_FILES=$(find base/rhel frontend/rhel -name "*.spec" 2>/dev/null)

if [ -z "$SPEC_FILES" ]; then
    echo -e "${RED}ERROR: No spec files found${NC}"
    exit 1
fi

echo "Found spec files:"
for spec in $SPEC_FILES; do
    echo "  - $(basename $spec)"
done
echo ""

# Check 1: Verify /etc/sysconfig/ files have %config(noreplace)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Check 1: /etc/sysconfig/ config file handling"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for spec in $SPEC_FILES; do
    spec_name=$(basename "$spec")
    echo "Checking: $spec_name"

    # Extract %files section
    if grep -q "^%files" "$spec"; then
        # Check for /etc/sysconfig/ entries in %files section
        sysconfig_files=$(sed -n '/^%files/,/^%changelog/p' "$spec" | grep "/etc/sysconfig/" | grep -v "^#" || true)

        if [ -n "$sysconfig_files" ]; then
            # Check each sysconfig file
            while IFS= read -r line; do
                file_path=$(echo "$line" | awk '{print $NF}')

                if echo "$line" | grep -q "%config(noreplace)"; then
                    print_result "PASS" "$spec_name: $file_path uses %config(noreplace)"
                else
                    print_result "FAIL" "$spec_name: $file_path missing %config(noreplace)"
                fi
            done <<< "$sysconfig_files"
        else
            echo "  INFO: No /etc/sysconfig/ files in $spec_name"
        fi
    else
        print_result "WARN" "$spec_name: No %files section found"
    fi
    echo ""
done

# Check 2: Verify all config files use %config(noreplace)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Check 2: All config files use %config(noreplace)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for spec in $SPEC_FILES; do
    spec_name=$(basename "$spec")
    echo "Checking: $spec_name"

    # Find all config files (in /etc/)
    etc_files=$(sed -n '/^%files/,/^%changelog/p' "$spec" | grep "^/etc/" | grep -v "^#" | grep -v "/etc/udev" | grep -v "/etc/modules-load.d" || true)

    if [ -n "$etc_files" ]; then
        while IFS= read -r line; do
            file_path=$(echo "$line" | awk '{print $NF}')

            # Check if it's a config file (skip directories)
            if ! echo "$file_path" | grep -q "/$"; then
                if echo "$line" | grep -q "%config"; then
                    if echo "$line" | grep -q "%config(noreplace)"; then
                        print_result "PASS" "$spec_name: $file_path uses %config(noreplace)"
                    else
                        print_result "WARN" "$spec_name: $file_path uses %config but not (noreplace)"
                    fi
                else
                    # Check if it's a config-like file
                    if echo "$file_path" | grep -qE "\.(conf|cfg|config)$"; then
                        print_result "WARN" "$spec_name: $file_path might need %config(noreplace)"
                    fi
                fi
            fi
        done <<< "$etc_files"
    fi
    echo ""
done

# Check 3: Verify %postun scripts use systemd macros
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Check 3: %postun scripts use systemd macros"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for spec in $SPEC_FILES; do
    spec_name=$(basename "$spec")
    echo "Checking: $spec_name"

    if grep -q "^%postun" "$spec"; then
        # Check if %postun contains %systemd_postun
        if grep -A 10 "^%postun" "$spec" | grep -q "%systemd_postun"; then
            print_result "PASS" "$spec_name: %postun uses %systemd_postun macro"
        else
            # Check if it manually calls daemon-reload
            if grep -A 10 "^%postun" "$spec" | grep -q "daemon-reload"; then
                print_result "WARN" "$spec_name: %postun manually calls daemon-reload (consider using %systemd_postun)"
            else
                # Check if package has systemd services
                if grep -q "\.service" "$spec"; then
                    print_result "FAIL" "$spec_name: %postun exists but doesn't use %systemd_postun or daemon-reload"
                else
                    print_result "PASS" "$spec_name: %postun present (no services to reload)"
                fi
            fi
        fi
    else
        # Check if package has systemd services
        if grep -q "\.service" "$spec"; then
            print_result "WARN" "$spec_name: Has systemd services but no %postun section"
        else
            echo "  INFO: No %postun section (no services)"
        fi
    fi
    echo ""
done

# Check 4: Verify %systemd_preun is used in %preun
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Check 4: %preun scripts use systemd macros"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for spec in $SPEC_FILES; do
    spec_name=$(basename "$spec")
    echo "Checking: $spec_name"

    if grep -q "\.service" "$spec"; then
        if grep -q "^%preun" "$spec"; then
            if grep -A 5 "^%preun" "$spec" | grep -q "%systemd_preun"; then
                print_result "PASS" "$spec_name: %preun uses %systemd_preun macro"
            else
                print_result "FAIL" "$spec_name: %preun exists but doesn't use %systemd_preun"
            fi
        else
            print_result "FAIL" "$spec_name: Has systemd services but no %preun section"
        fi
    else
        echo "  INFO: No systemd services in $spec_name"
    fi
    echo ""
done

# Check 5: Verify %post scripts use %systemd_post
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Check 5: %post scripts use systemd macros"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for spec in $SPEC_FILES; do
    spec_name=$(basename "$spec")
    echo "Checking: $spec_name"

    if grep -q "\.service" "$spec"; then
        if grep -q "^%post$" "$spec"; then
            if grep -A 10 "^%post$" "$spec" | grep -q "%systemd_post"; then
                print_result "PASS" "$spec_name: %post uses %systemd_post macro"
            else
                print_result "WARN" "$spec_name: %post exists but might not use %systemd_post"
            fi
        else
            print_result "WARN" "$spec_name: Has systemd services but no %post section"
        fi
    else
        echo "  INFO: No systemd services in $spec_name"
    fi
    echo ""
done

# Summary
echo "========================================"
echo "Verification Summary"
echo "========================================"
echo ""
echo "Total checks: $TOTAL_CHECKS"
echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
echo -e "${YELLOW}Warnings: $WARNING_CHECKS${NC}"
echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
echo ""

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Please review the errors above.${NC}"
    exit 1
fi
