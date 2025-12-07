.DEFAULT_GOAL := help
SHELL := /bin/bash

PYTHON ?= $(if $(VIRTUAL_ENV),$(VIRTUAL_ENV)/bin/python3,$(if $(wildcard .venv/bin/python3),./.venv/bin/python3,python3))
PIP := $(PYTHON) -m pip
ANSIBLE_CMD ?= ANSIBLE_NOCOWS=1 ansible-playbook
ANSIBLE_ARGS ?= -vv
ASK_BECOME_PASS ?=
ANSIBLE_EXTRA_ARGS :=
ifneq ($(strip $(ASK_BECOME_PASS)),)
ANSIBLE_EXTRA_ARGS += --ask-become-pass
endif
ANSIBLE_PLAYBOOK := $(ANSIBLE_CMD) $(ANSIBLE_ARGS) $(ANSIBLE_EXTRA_ARGS)
INV_CACHE_DIR := .ansible_cache
CACHE_DIRS := $(INV_CACHE_DIR) .pytest_cache .mypy_cache .ruff_cache

RUFF := $(PYTHON) -m ruff
BLACK := $(PYTHON) -m black
YAMLLINT := $(PYTHON) -m yamllint
ANSIBLE_LINT := $(PYTHON) -m ansiblelint

INV_SCRIPT := inventory/generator.py
INV_JSON   := inventory/inventory.json
CONFIG_YAML := $(wildcard config/*.yml)

PLAYBOOK_DIR := playbooks
PLAYBOOK_CONTROLLER := $(PLAYBOOK_DIR)/controller.yml
PLAYBOOK_COMPUTE := $(PLAYBOOK_DIR)/compute.yml
PLAYBOOK_PXE := $(PLAYBOOK_DIR)/pxe.yml

.PHONY: help hashes inv inv-show inv-clean dev-venv controller-venv venv-check lint format clean controller compute pxe

help: ## Show available targets grouped by phase
	@echo "Make targets:"
	@awk -F':.*## ' '/^[a-zA-Z0-9_.-]+:.*##/ { printf "  %-22s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

clean: ## Remove caches and temporary files
	@echo "[CLEAN] Removing caches and temporary files..."
	@rm -rf $(CACHE_DIRS)
	@find . -type d -name "__pycache__" -exec rm -rf {} +
	@find . -name "*.pyc" -delete
	@find . -name "*.pyo" -delete
	@rm -f $(INV_JSON)
	@rm -rf /tmp/ansible-tmp-*
	@echo "[CLEAN] Cleanup complete."

lint: ## Run all linters (Python, YAML, Ansible)
	@$(BLACK) --check .
	@$(RUFF) check .
	@$(YAMLLINT) .
	@$(ANSIBLE_LINT)
	@echo "[OK] Lint checks complete."

format: ## Auto-format Python and YAML
	@$(BLACK) .
	@$(RUFF) check --fix .
	@echo "[OK] Formatting complete."

dev-venv: ## Create and initialize Python virtual environment (dev workstation)
	@chmod +x scripts/dev_venv.sh
	@./scripts/dev_venv.sh
	@echo "[OK] Virtual environment ready."

controller-venv: ## Create controller virtualenv (run on controller host)
	@chmod +x scripts/controller_venv.sh
	@./scripts/controller_venv.sh
	@echo "[OK] Controller virtualenv ready."controller-venv: ## Create controller virtualenv (run on controller host)
	@chmod +x scripts/controller_venv.sh
	@./scripts/controller_venv.sh
	@echo "[OK] Controller virtualenv ready."

venv-check: ## Verify Python and Ansible availability
	@command -v $(PYTHON) >/dev/null 2>&1 || { echo "Python 3 not found"; exit 1; }
	@$(PYTHON) -m ansible --version >/dev/null 2>&1 || { echo "Ansible not available"; exit 1; }
	@echo "[OK] Python and Ansible detected."

hashes: ## Generate hashes for .env
	chmod +x ./scripts/generate_hashes.py
	@$(PYTHON) ./scripts/generate_hashes.py

inv: $(INV_JSON) ## Generate and cache dynamic inventory
	@echo "[OK] Inventory cached at $(INV_JSON)"

$(INV_JSON): $(INV_SCRIPT) $(CONFIG_YAML)
	@mkdir -p $(INV_CACHE_DIR)
	@mkdir -p $(dir $(INV_JSON))
	@echo "[BUILD] Generating inventory..."
	@$(PYTHON) $(INV_SCRIPT) --list > $(INV_JSON)
	@echo "[DONE] Inventory generation complete."

inv-show: ## Print generated inventory JSON to stdout
	@$(PYTHON) $(INV_SCRIPT) --list | jq .

inv-clean: ## Remove cached inventory and Ansible fact cache
	@rm -rf $(INV_JSON) $(INV_CACHE_DIR)
	@echo "[CLEAN] Inventory cache removed."

# Playbook runners (auto-generate inventory first)
controller: inv ## Run controller playbook (controller_common + controller + pxe)
	@$(ANSIBLE_PLAYBOOK) -i $(INV_JSON) $(PLAYBOOK_CONTROLLER)

pxe: inv ## Run PXE-only playbook
	@$(ANSIBLE_PLAYBOOK) -i $(INV_JSON) $(PLAYBOOK_PXE)

compute: inv ## Run compute playbook (compute_common bootstrap)
	@$(ANSIBLE_PLAYBOOK) -i $(INV_JSON) $(PLAYBOOK_COMPUTE)
