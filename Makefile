SHELL := /bin/bash

FLUID := ./fluid.sh
BRANCH := $(shell git branch --show-current 2>/dev/null || echo main)

.PHONY: help audit status status-json access-render backup validate-restore check clean-render clean link origin push github-sync

help:
	@printf "make audit\n"
	@printf "make status\n"
	@printf "make status-json\n"
	@printf "make access-render\n"
	@printf "make backup\n"
	@printf "make validate-restore\n"
	@printf "make link\n"
	@printf "make check\n"
	@printf "make clean-render\n"
	@printf "make clean\n"
	@printf "make origin\n"
	@printf "make push\n"

audit:
	$(FLUID) audit

status:
	$(FLUID) status

status-json:
	$(FLUID) status --json

access-render:
	$(FLUID) access render

backup:
	$(FLUID) backup

validate-restore:
	$(FLUID) validate-restore

link:
	$(FLUID) link

check: audit status-json access-render

clean-render:
	rm -rf render/access render/continuity render/projects
	mkdir -p render
	touch render/.gitkeep

clean: clean-render

origin:
	git remote add origin git@gitlab.com:kpihx-labs/fluid.git 2>/dev/null || git remote set-url origin git@gitlab.com:kpihx-labs/fluid.git
	git remote -v

push: origin
	git push origin $(BRANCH)

github-sync:
	test -n "$$GITHUB_TOKEN"
	git remote add github https://x-access-token:$$GITHUB_TOKEN@github.com/kpihx-labs/fluid.git 2>/dev/null || git remote set-url github https://x-access-token:$$GITHUB_TOKEN@github.com/kpihx-labs/fluid.git
	git push github HEAD:refs/heads/main --force
