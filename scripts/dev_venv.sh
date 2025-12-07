#!/bin/bash
# Lightweight dev virtualenv bootstrap (dev workstation)

set -euo pipefail

log() { printf '[dev-venv] %s\n' "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

PYTHON_BIN="${PYTHON:-python3}"
command -v "${PYTHON_BIN}" >/dev/null 2>&1 || die "${PYTHON_BIN} not found"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENVDIR="${REPO_ROOT}/.venv"

log "Creating virtualenv at ${VENVDIR}"
"${PYTHON_BIN}" -m venv "${VENVDIR}"

PIP="${VENVDIR}/bin/pip"
PYTHON_VENV="${VENVDIR}/bin/python"

log "Upgrading pip/setuptools/wheel"
"${PYTHON_VENV}" -m pip install --upgrade pip setuptools wheel

log "Installing dev requirements"
"${PIP}" install -r "${REPO_ROOT}/requirements/dev.txt"

log "Installing Ansible collections"
"${VENVDIR}/bin/ansible-galaxy" collection install -r "${REPO_ROOT}/requirements/requirements.yml"

if [ -f "${REPO_ROOT}/.pre-commit-config.yaml" ]; then
  log "Installing pre-commit hooks"
  "${VENVDIR}/bin/pre-commit" install
fi

log "Virtualenv ready. Activate with:"
log "  source ${VENVDIR}/bin/activate"
