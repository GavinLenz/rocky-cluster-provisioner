#!/bin/bash
# Bootstrap the controller's runtime virtualenv. Run this on the controller host.

set -euo pipefail

log() { printf '[controller-venv] %s\n' "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

PYTHON_BIN="${PYTHON:-/usr/bin/python3}"
command -v "${PYTHON_BIN}" >/dev/null 2>&1 || die "Python binary ${PYTHON_BIN} not found"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENVDIR="${REPO_ROOT}/.venv"
EXPECTED_ANSIBLE="2.15.8"

log "Creating virtualenv at ${VENVDIR}"
"${PYTHON_BIN}" -m venv "${VENVDIR}"

PIP="${VENVDIR}/bin/pip"
PYTHON_VENV="${VENVDIR}/bin/python"
GALAXY="${VENVDIR}/bin/ansible-galaxy"
ANSIBLE_BIN="${VENVDIR}/bin/ansible"

log "Upgrading pip/setuptools/wheel"
"${PYTHON_VENV}" -m pip install --upgrade pip setuptools wheel

log "Installing controller Python requirements"
"${PIP}" install -r "${REPO_ROOT}/requirements/controller.txt"

log "Installing required Ansible collections"
"${GALAXY}" collection install -r "${REPO_ROOT}/requirements/requirements.yml"

if "${ANSIBLE_BIN}" --version | grep -Fq "core ${EXPECTED_ANSIBLE}"; then
  log "Ansible core ${EXPECTED_ANSIBLE} present in virtualenv"
else
  log "WARNING: expected ansible-core ${EXPECTED_ANSIBLE}; check ${ANSIBLE_BIN} --version"
fi

log "Controller virtualenv ready. Activate with:"
log "  source ${VENVDIR}/bin/activate"
