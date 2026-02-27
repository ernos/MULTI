#!/usr/bin/env bash
# create-multipass-rdp.sh
#
# Simplifies launching a Multipass VM with a remote-desktop (RDP) environment.
#
# Usage:
#   ./create-multipass-rdp.sh [OPTIONS]
#
# Options:
#   -n, --name     NAME   VM name (default: rdp-vm)
#   -c, --cpus     N      Number of CPUs (default: 2)
#   -m, --memory   SIZE   Memory, e.g. 2G (default: 2G)
#   -d, --disk     SIZE   Disk size, e.g. 20G (default: 20G)
#   -i, --image    IMAGE  Ubuntu image to use, e.g. 22.04 (default: 22.04)
#   -u, --user     USER   Username to create inside the VM (default: rdpuser)
#   -p, --password PASS   Password for the user (auto-generated if not set)
#   -h, --help            Show this help message
#
# Requirements:
#   - Multipass  https://multipass.run
#   - ssh-keygen (usually pre-installed)
#
# After the script finishes it prints the RDP connection string so you can
# connect from any RDP client (Windows "mstsc", Remmina, Microsoft Remote
# Desktop on macOS, etc.).

set -euo pipefail

# ── Defaults ────────────────────────────────────────────────────────────────
VM_NAME="rdp-vm"
CPUS=2
MEMORY="2G"
DISK="20G"
IMAGE="22.04"
RDP_USER="rdpuser"
RDP_PASS=""   # auto-generated below if not supplied via -p
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUD_INIT="${SCRIPT_DIR}/cloud-init-rdp.yaml"

# ── Helpers ──────────────────────────────────────────────────────────────────
usage() {
    # Print the comment block at the top of this file (lines 2-N until first non-comment)
    sed -n '2,/^[^#]/{ /^[^#]/d; s/^# \{0,1\}//; p }' "$0"
    exit 0
}

info()  { echo "[INFO]  $*"; }
warn()  { echo "[WARN]  $*" >&2; }
error() { echo "[ERROR] $*" >&2; exit 1; }

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || error "'$1' is not installed or not in PATH."
}

# ── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--name)     VM_NAME="$2";   shift 2 ;;
        -c|--cpus)     CPUS="$2";      shift 2 ;;
        -m|--memory)   MEMORY="$2";    shift 2 ;;
        -d|--disk)     DISK="$2";      shift 2 ;;
        -i|--image)    IMAGE="$2";     shift 2 ;;
        -u|--user)     RDP_USER="$2";  shift 2 ;;
        -p|--password) RDP_PASS="$2";  shift 2 ;;
        -h|--help)     usage ;;
        *) error "Unknown option: $1" ;;
    esac
done

# ── Pre-flight checks ─────────────────────────────────────────────────────────
require_cmd multipass
require_cmd openssl

[[ -f "$CLOUD_INIT" ]] || error "cloud-init file not found: $CLOUD_INIT"

if multipass list --format csv 2>/dev/null | grep -q "^${VM_NAME},"; then
    error "A VM named '${VM_NAME}' already exists. Choose a different name with -n."
fi

# Generate a random password if the user did not supply one
if [[ -z "$RDP_PASS" ]]; then
    RDP_PASS="$(openssl rand -base64 16 | tr -dc 'A-Za-z0-9@#%^&*' | head -c 16)"
fi

# ── Generate a temporary cloud-init with the requested user ──────────────────
# Use a restrictive umask so the temp file is readable only by the current user
OLD_UMASK=$(umask)
umask 077
TMP_CLOUD_INIT="$(mktemp /tmp/cloud-init-rdp-XXXXXX.yaml)"
umask "$OLD_UMASK"
trap 'rm -f "$TMP_CLOUD_INIT"' EXIT

cat "$CLOUD_INIT" > "$TMP_CLOUD_INIT"

# Append user creation to the temporary cloud-init
cat >> "$TMP_CLOUD_INIT" << YAML

users:
  - default
  - name: ${RDP_USER}
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) ALL
    lock_passwd: false
    passwd: $(openssl passwd -6 "${RDP_PASS}")

# Write the xsession for the new user as well
write_files:
  - path: /home/${RDP_USER}/.xsession
    content: "startxfce4\n"
    owner: "${RDP_USER}:${RDP_USER}"
    permissions: '0644'
YAML

# ── Launch the VM ─────────────────────────────────────────────────────────────
info "Launching Multipass VM '${VM_NAME}' (Ubuntu ${IMAGE}, ${CPUS} CPU(s), ${MEMORY} RAM, ${DISK} disk)…"
multipass launch \
    --name    "${VM_NAME}" \
    --cpus    "${CPUS}" \
    --memory  "${MEMORY}" \
    --disk    "${DISK}" \
    --cloud-init "${TMP_CLOUD_INIT}" \
    "${IMAGE}"

# ── Wait for cloud-init to finish ─────────────────────────────────────────────
info "Waiting for cloud-init to complete (this may take a few minutes)…"
multipass exec "${VM_NAME}" -- cloud-init status --wait

# ── Retrieve the VM IP address ────────────────────────────────────────────────
VM_IP=$(multipass info "${VM_NAME}" --format csv \
    | awk -F',' 'NR>1 {print $3}' \
    | tr -d ' ' \
    | head -n1)

[[ -n "$VM_IP" ]] || error "Could not determine IP address for '${VM_NAME}'."

# ── Done ──────────────────────────────────────────────────────────────────────
cat << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VM '${VM_NAME}' is ready!

  RDP connection details
  ──────────────────────
  Host     : ${VM_IP}
  Port     : 3389
  Username : ${RDP_USER}
  Password : ${RDP_PASS}

  Connect with:
    Windows   → mstsc /v:${VM_IP}
    macOS     → Microsoft Remote Desktop → Add PC → ${VM_IP}
    Linux     → remmina -c rdp://${RDP_USER}@${VM_IP}

  Manage the VM:
    multipass shell ${VM_NAME}   (open a shell)
    multipass stop  ${VM_NAME}   (stop the VM)
    multipass start ${VM_NAME}   (start the VM)
    multipass delete ${VM_NAME} --purge  (delete the VM)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
