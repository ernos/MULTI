# MULTI

Helper scripts for creating [Multipass](https://multipass.run) virtual machines
with a full remote-desktop (RDP) environment pre-configured.

## Requirements

| Tool | Install |
|------|---------|
| [Multipass](https://multipass.run/install) | **Linux:** `snap install multipass` · **macOS:** `brew install multipass` · **Windows:** [download the installer](https://multipass.run/install) |
| `openssl` | pre-installed on macOS/Linux; on Windows use Git Bash or WSL |

## Scripts

### `scripts/create-multipass-rdp.sh`

Creates a Multipass Ubuntu VM and automatically installs:

* **XFCE** desktop environment
* **xrdp** — lets you connect using any standard RDP client

#### Usage

```bash
# Default settings (VM name: rdp-vm, 2 CPUs, 2 GB RAM, 20 GB disk, Ubuntu 22.04)
./scripts/create-multipass-rdp.sh

# Custom settings
./scripts/create-multipass-rdp.sh \
  --name    my-vm   \
  --cpus    4       \
  --memory  4G      \
  --disk    30G     \
  --image   24.04   \
  --user    alice   \
  --password SecretPass1!
```

#### Options

| Flag | Default | Description |
|------|---------|-------------|
| `-n`, `--name` | `rdp-vm` | VM name |
| `-c`, `--cpus` | `2` | Number of CPUs |
| `-m`, `--memory` | `2G` | Memory (e.g. `2G`, `4G`) |
| `-d`, `--disk` | `20G` | Disk size (e.g. `20G`, `50G`) |
| `-i`, `--image` | `22.04` | Ubuntu image / release |
| `-u`, `--user` | `rdpuser` | Username to create inside the VM |
| `-p`, `--password` | *(random)* | Password for the RDP user (auto-generated if not provided) |
| `-h`, `--help` | | Show usage |

After the VM is ready the script prints the RDP connection details, for example:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VM 'rdp-vm' is ready!

  RDP connection details
  ──────────────────────
  Host     : 192.168.64.5
  Port     : 3389
  Username : rdpuser
  Password : a9Bx#kP2@mR7^qL5

  Connect with:
    Windows   → mstsc /v:192.168.64.5
    macOS     → Microsoft Remote Desktop → Add PC → 192.168.64.5
    Linux     → remmina -c rdp://rdpuser@192.168.64.5
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### `scripts/cloud-init-rdp.yaml`

The cloud-init template used internally by `create-multipass-rdp.sh`.
It can also be used standalone:

```bash
multipass launch --cloud-init scripts/cloud-init-rdp.yaml --name my-vm 22.04
```

This installs the desktop environment and xrdp but does **not** create an
extra user — you would connect as `ubuntu` (password must be set separately).

## Managing the VM

```bash
multipass shell  rdp-vm          # open an interactive shell
multipass stop   rdp-vm          # stop the VM
multipass start  rdp-vm          # start the VM
multipass delete rdp-vm --purge  # permanently delete the VM
multipass list                   # list all VMs
```
