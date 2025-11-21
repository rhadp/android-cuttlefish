#!/bin/bash
#
# Generate TLS Certificates for Cuttlefish Operator
#
# This script generates self-signed TLS certificates for the cuttlefish-operator
# service if they don't already exist. The certificates are used for HTTPS
# communication with the operator's web interface.
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

# Source configuration from /etc/sysconfig/
if [ -f /etc/sysconfig/cuttlefish-operator ]; then
    source /etc/sysconfig/cuttlefish-operator
fi

# Certificate directory (can be overridden in config file)
CERT_DIR="${operator_tls_cert_dir:-/etc/cuttlefish-common/operator/cert}"
CERT_FILE="${CERT_DIR}/cert.pem"
KEY_FILE="${CERT_DIR}/key.pem"

# Check if certificates already exist
if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
    echo "TLS certificates already exist:"
    echo "  Certificate: $CERT_FILE"
    echo "  Private Key: $KEY_FILE"
    echo "Skipping certificate generation."
    exit 0
fi

echo "Generating self-signed TLS certificates for cuttlefish-operator..."
echo "Certificate directory: $CERT_DIR"

# Create certificate directory if it doesn't exist
mkdir -p "${CERT_DIR}"

# Generate self-signed certificate
# - RSA 4096-bit key
# - SHA-256 signature
# - Valid for ~100 years (36000 days)
# - No password protection (nodes)
openssl req \
  -newkey rsa:4096 \
  -x509 \
  -sha256 \
  -days 36000 \
  -nodes \
  -out "${CERT_FILE}" \
  -keyout "${KEY_FILE}" \
  -subj "/C=US/ST=California/L=Mountain View/O=Android/CN=cuttlefish-operator"

# Set ownership to operator user and group
chown _cutf-operator:cvdnetwork "${CERT_FILE}"
chown _cutf-operator:cvdnetwork "${KEY_FILE}"

# Set permissions
# Certificate can be world-readable, but restrict private key
chmod 644 "${CERT_FILE}"
chmod 600 "${KEY_FILE}"

echo "TLS certificates generated successfully:"
echo "  Certificate: $CERT_FILE"
echo "  Private Key: $KEY_FILE"
echo ""
echo "NOTE: These are self-signed certificates. Browsers will show a security"
echo "      warning when accessing the operator HTTPS interface. For production"
echo "      use, consider replacing with certificates from a trusted CA."

exit 0
