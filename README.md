# Rocky Cluster Provisioner
[![CI](https://github.com/GavinLenz/rocky-cluster-provisioner/actions/workflows/ci.yml/badge.svg)](https://github.com/GavinLenz/rocky-cluster-provisioner/actions/workflows/ci.yml)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

_Rocky 9 Micro-Cluster Automation_

A minimal reproducible workflow for bootstrapping a Rocky 9 controller and a small fleet
of PXE-booted compute nodes. The controller owns PXE (dnsmasq, Apache, TFTP) while compute
nodes stay intentionally bare so new schedulers or application stacks can be layered later.
Inventory and playbooks live in this repo so deployments stay deterministic.

> Status: Fully operational for baseline provisioning. The controller configures correctly, serves PXE/iPXE, and installs compute nodes via Kickstart. Freshly provisioned compute nodes boot cleanly, accept SSH, and run Python immediately after installation.

> Next steps: Scheduler, storage, and workload roles will be added next.

---

### Safety Notice

Provisioning commands such as `make controller`, `make pxe`, and `make compute` modify the machine they are run on:

• network interfaces
• static IPs and routing
• firewall rules
• dnsmasq, Apache, and PXE services
• system configuration files

These commands must only be executed on the dedicated controller node, never on the development machine, laptop, or workstation.

Development commands (make dev-venv, make inv, make lint) are safe and do not modify system state.

---

## Overview

- **Topology** – One controller host (`controller`) with static IP `10.0.0.1`, three compute nodes
  on the same `/24` LAN, Cat6e cabling into a 2.5 GbE switch.
- **Provisioning flow** – Kickstart via iPXE → Ansible roles:
  - `controller_common → controller → pxe` on the controller
  - `compute_common` on compute nodes (creates automation user + verifies Python is already present)

See `docs/ARCHITECTURE.md` for the full wiring contract and `docs/HOSTS.md` for per-role
responsibilities.

## Development and Controller Environments

This repository supports **two execution paths**, each with different tooling requirements:

### 1. Development Environment (Bare Metal or WSL)

Used for writing playbooks, editing configuration, generating inventory, and running CI checks.

The developer environment requires:

- Python 3.9+
- virtualenv/pip toolchain
- Make, Git, rsync, jq
- Ansible and collections (installed via `make dev-venv` or manually)

```bash
git clone https://github.com/GavinLenz/rocky-cluster-provisioner
cd rocky-cluster-provisioner
make dev-venv
```

Or, developers may activate the environment manually:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements/dev.txt
```

This enables inventory generation (`make inv`), linting, formatting, and local testing.

---

### 2. Controller Environment (The Head Node)

The controller is a **Rocky Linux 9 bare-metal host**. It requires:

```bash
sudo dnf -y install python3 python3-devel make curl wget tar gzip unzip vim tmux jq rsync ansible-core
```

Then the user clones the repository and prepares the controller’s virtual environment:

```bash
git clone https://github.com/GavinLenz/rocky-cluster-provisioner
cd rocky-cluster-provisioner
make controller-venv
```

From this point forward, **all provisioning commands must be run on the controller host**, because the inventory defines:

```
ansible_connection: local
```

If run from another machine, Ansible would reconfigure that machine instead of `10.0.0.1`.

## Quick Start

1. **Clone the repository and prepare the development environment (optional):**

   ```bash
   git clone https://github.com/GavinLenz/rocky-cluster-provisioner
   cd rocky-cluster-provisioner
   make dev-venv
   source .venv/bin/activate
   ```

2. **Populate `.env` with PXE password hashes:**

   ```bash
   make hashes
   # copy output into .env
   # this password will be used for part 8
   ```

3. **Describe the cluster in `config/*.yml`:** nodes and their MACs, network layout, PXE image + published SHA256, and the role stack.

4. **Generate inventory on the development machine:**

   ```bash
   make inv
   ```

5. **SSH into the controller host and prep its virtualenv:**

   ```bash
   ssh controller
   cd rocky-cluster-provisioner
   make controller-venv
   ```

6. **Provision the controller (PXE stack, dnsmasq, Apache, TFTP, Kickstart tree):**

   ```bash
   ASK_BECOME_PASS=1 make controller
   ```

7. **Boot compute nodes via PXE.** After they complete the Kickstart installation, set `pxe.ipxe.default_target` in `config/pxe.yml` to `local` so PXE falls back to each node’s disk:

   ```yaml
   pxe:
     ipxe:
       default_target: local
   ```

8. **Establish SSH trust (one time):**
  > Once the nodes have booted from their local drive, run this from the controller node.
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
   ssh-copy-id -i ~/.ssh/id_ed25519 ansible@10.0.0.11
   ssh-copy-id -i ~/.ssh/id_ed25519 ansible@10.0.0.12
   ssh-copy-id -i ~/.ssh/id_ed25519 ansible@10.0.0.13
   ```

9. **Provision compute nodes:**

   ```bash
   make compute
   ```

Every target reruns the dynamic inventory; no static inventory file is committed.

## Repository Layout

```
config/         # Nodes, network, PXE, role stacks
docs/           # Architecture, host guides, setup flow
inventory/      # Dynamic generator + cached JSON
playbooks/      # controller.yml, compute.yml, pxe.yml
roles/          # controller_common, controller, compute_common, pxe
scripts/        # hash generator, cleanup helpers, venv creation scripts
requirements/   # dev / controller pip requirements + galaxy requirements.yml
```

Key documentation:

- `docs/ARCHITECTURE.md` – topology, control flow, state surfaces
- `docs/HOSTS.md` – controller vs compute responsibilities
- `docs/RESOURCES.md` – external references for Kickstart, Ansible, and controller roles

## Make Targets

| Target            | Description                                               |
| ----------------- | --------------------------------------------------------- |
| `make inv`        | Regenerate `inventory/inventory.json` from `config/*.yml` |
| `make controller` | Apply controller roles (PXE, static IP prep)              |
| `make compute`    | Seed compute nodes with SSH user + Python validation      |
| `make lint`       | Run Black, Ruff, Yamllint, ansible-lint                   |
| `make clean`      | Remove caches and temporary files                         |

## Contributing & Support

- Keep changes idempotent and update `docs/` to match behavioral shifts.
- Use `make lint` before sending patches.
- Sensitive values (`.env`, inventory artifacts) stay out of git; `.gitignore` covers them.
