#!/usr/bin/env bash
#
# Configure K3s API Server with OIDC Authentication
# This script adds OIDC parameters to K3s for OAuth integration
#
# Usage: ./configure-oidc.sh <client_id> <client_secret> <issuer_url> <username_claim> <groups_claim> <username_prefix>

set -euo pipefail

CLIENT_ID="${1:-}"
CLIENT_SECRET="${2:-}"
ISSUER_URL="${3:-https://accounts.google.com}"
USERNAME_CLAIM="${4:-email}"
GROUPS_CLAIM="${5:-groups}"
USERNAME_PREFIX="${6:--}"

if [[ -z "$CLIENT_ID" ]] || [[ -z "$CLIENT_SECRET" ]]; then
    echo "Usage: $0 <client_id> <client_secret> [issuer_url] [username_claim] [groups_claim] [username_prefix]"
    exit 1
fi

# K3s config directory
K3S_CONFIG_DIR="/etc/rancher/k3s"
K3S_CONFIG_FILE="$K3S_CONFIG_DIR/config.yaml"

# Create config directory if it doesn't exist
mkdir -p "$K3S_CONFIG_DIR"

# Create or update K3s configuration with OIDC settings
cat > "$K3S_CONFIG_FILE" <<EOF
# K3s Configuration with OIDC Authentication
kube-apiserver-arg:
  - "oidc-issuer-url=$ISSUER_URL"
  - "oidc-client-id=$CLIENT_ID"
  - "oidc-username-claim=$USERNAME_CLAIM"
  - "oidc-groups-claim=$GROUPS_CLAIM"
  - "oidc-username-prefix=$USERNAME_PREFIX"
EOF

echo "OIDC configuration written to $K3S_CONFIG_FILE"
echo "Restarting K3s service..."

# Restart K3s to apply changes
systemctl restart k3s

# Wait for K3s to be ready
echo "Waiting for K3s to restart..."
sleep 10

for i in {1..30}; do
    if k3s kubectl get nodes &> /dev/null; then
        echo "K3s restarted successfully with OIDC configuration"
        exit 0
    fi
    sleep 2
done

echo "ERROR: K3s did not restart properly"
exit 1
