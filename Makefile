# 🌊 Fluid Meta-Orchestrator Makefile
# 0 Trust · 100% Control | 0 Magic · 100% Transparency

FLUID  := ./fluid.sh
BRANCH := $(shell git branch --show-current 2>/dev/null || echo main)

.PHONY: help status fluid-status git-status audit check sync github gitlab clean purge link backup validate-restore
.DEFAULT_GOAL := help

# --- [ General ] ---

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

status: git-status fluid-status ## Check both Fluid and Git status

git-status: ## Show current git repository status
	@echo "--- GIT STATUS ---"
	@git status -s
	@echo ""

fluid-status: ## Show current Fluid cluster/node status
	@echo "--- FLUID STATUS ---"
	@$(FLUID) status
	@echo ""

# --- [ Fluid Operations ] ---

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

sync: gitlab github ## Commit and push to both GitLab and GitHub
	@echo "--- PREPARING SYNC ---"
	@git add .
	@git commit -m "chore(meta): sovereign state sync $$(date +'%Y-%m-%d %H:%M:%S')" || echo "No changes to commit"
	@echo "--- SYNCING TO GITLAB ---"
	@git push gitlab $(BRANCH)
	@echo "--- SYNCING TO GITHUB ---"
	@git push github $(BRANCH)

gitlab: ## Ensure GitLab remote is configured
	@git remote add gitlab git@gitlab.com:kpihx-labs/fluid.git 2>/dev/null || git remote set-url gitlab git@gitlab.com:kpihx-labs/fluid.git

github: ## Ensure GitHub remote is configured
	@git remote add github git@github.com:kpihx-labs/fluid.git 2>/dev/null || git remote set-url github git@github.com:kpihx-labs/fluid.git
