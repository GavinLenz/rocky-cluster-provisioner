## HOSTS.md

This guide describes what each host role does today. The controller is feature-rich
because it owns PXE and repo state; compute nodes are intentionally
minimal so they can be wiped and rebuilt quickly.

> **Work in progress**: Compute nodes only get the automation user + SSH bootstrap today (Python ships in the Kickstart image). 
> Scheduler, storage, and workload roles will be layered later!

---

## 1. Controller Role

### Responsibilities

1. **PXE authority** – dnsmasq + Apache + TFTP netboot the fleet. All Kickstart
   media, iPXE binaries, and repo mirrors live under `/var/www/html` and `/srv/tftp`.
2. **Configuration hub** – dynamic inventory, playbooks, and repo mirrors live here.

### Provisioning Flow

1. Clone the repo and populate `.env` with password hashes from
   `scripts/generate_hashes.py`.
2. `make inv` to generate `inventory/inventory.json`.
3. On the controller host, run:
   - `make controller-venv` once to create the Ansible virtualenv.
   - `make controller`, which enforces:
     - `controller_common`: users, SSH keys, sudoers drop-in, baseline packages.
     - `controller`: hostname, static IP, and controller identity management.
     - `pxe`: dnsmasq, Apache, firewall, PXE assets, ISO mounts.

### Reminders

- Never edit `/etc/dnsmasq*` or `/etc/NetworkManager/system-connections/*` manually, 
   instead change the role templates and rerun Ansible.
- Keep `inventory/inventory.json` current (`make inv`) before any playbook runs.
- When applying firewall changes over SSH, confirm the source IP so the guard logic
  adds the correct temporary allow rule.

---

## 2. Compute Role

### Responsibilities

1. Boot via PXE/iPXE/Kickstart and register the `ansible` automation user.
2. Keep only the minimal baseline needed for remote management (Kickstart-installed Python + SSH).
3. Stay disposable—if a node drifts, reimage it.

### Provisioning Flow

1. Set BIOS/UEFI to PXE first, NVMe second. Ensure NIC MACs are recorded in
   `config/nodes.yml`.
2. After Kickstart completes, run `make compute`. The `compute_common` role:
   - Creates the `cluster` group (system) and `ansible` user.
   - Installs the controller’s public key and passwordless sudo drop-in.
   - Verifies `python3` is still present (Kickstart installs it; the role fails fast if it is missing).

> Future scheduler or application roles will be layered on top later on. For now, compute nodes are barebones by design.

### Runtime Expectations

- Nodes remain stateless; no firewalld or scheduler config is applied yet.
- Reapply `make compute` after firmware updates or reimages to keep credentials in sync.
