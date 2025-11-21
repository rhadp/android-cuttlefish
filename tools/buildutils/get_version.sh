#!/bin/bash
#
# Portable version extraction from debian/changelog
# Works on both Debian/Ubuntu and RHEL systems
#
# Usage: get_version.sh <path-to-changelog>
# Example: get_version.sh base/debian/changelog
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

usage() {
    echo "Usage: $0 <path-to-changelog>" >&2
    echo "Example: $0 base/debian/changelog" >&2
    exit 1
}

# Check arguments
if [ $# -ne 1 ]; then
    usage
fi

CHANGELOG_FILE="$1"

# Verify changelog file exists
if [ ! -f "$CHANGELOG_FILE" ]; then
    echo "Error: Changelog file not found: $CHANGELOG_FILE" >&2
    exit 1
fi

# Extract version using portable sed/awk
# Changelog format: package-name (version) distribution; urgency=level
# Example: cuttlefish-common (1.34.0) UNRELEASED; urgency=medium
#
# 1. head -n1: Get first line of changelog
# 2. sed 's/.*(\([^)]*\)).*/\1/': Extract content within parentheses
# 3. cut -d- -f1: Remove Debian revision (everything after first '-')
VERSION=$(head -n1 "$CHANGELOG_FILE" | sed 's/.*(\([^)]*\)).*/\1/' | cut -d- -f1)

# Validate version format (should match X.Y.Z pattern)
if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+'; then
    echo "Error: Invalid version format extracted: $VERSION" >&2
    echo "Expected format: X.Y.Z (e.g., 1.34.0)" >&2
    exit 1
fi

# Output version
echo "$VERSION"
