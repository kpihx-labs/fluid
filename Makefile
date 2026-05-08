# 🌊 Fluid Meta-Orchestrator Makefile
# 0 Trust · 100% Control | 0 Magic · 100% Transparency

FLUID  := ./fluid.sh
BRANCH := $(shell git branch --show-current 2>/dev/null || echo main)
M      ?= chore(meta): sovereign state sync $$(date +'%Y-%m-%d %H:%M:%S')

.PHONY: help status fluid-status git-status audit check sync clean purge link backup validate-restore
.DEFAULT_GOAL := help

# --- [ General ] ---

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

status: git-status fluid-status ## Check both Fluid and Git status (Overview)

# --- [ Fluid Operations ] ---

fluid-status: ## Show current Fluid cluster/node status
	@echo "--- FLUID STATUS ---"
	@$(FLUID) status
	@echo ""

audit: ## Run security and consistency audit on meta-state
	@$(FLUID) audit

check: audit ## Comprehensive check (audit + status-json + access-render)
	@$(FLUID) status --json
	@$(FLUID) access render

link: ## Ensure local environment links and dependencies are correct
	@$(FLUID) link

backup: ## Create a point-in-time backup of the meta-state
	@$(FLUID) backup

validate-restore: ## Validate meta-state restoration from backup
	@$(FLUID) validate-restore

clean: ## Clean local render artifacts
	@rm -rf render/access render/continuity render/projects
	@mkdir -p render
	@touch render/.gitkeep

purge: clean ## Clean everything including local state (CAUTION)
	@./purge.sh

# --- [ Deployment & Sovereignty ] ---

git-status: ## Show current git repository status
	@echo "--- GIT STATUS ---"
	@git status -s
	@echo ""

sync: ## Commit and push to both GitLab and GitHub (use M="message")
	@echo "--- PREPARING SYNC ---"
	@git add .
	@git commit -m "$(M)" || echo "No changes to commit"
	@echo "--- SYNCING TO GITLAB ---"
	@git push gitlab $(BRANCH)
	@echo "--- SYNCING TO GITHUB ---"
	@git push github $(BRANCH)