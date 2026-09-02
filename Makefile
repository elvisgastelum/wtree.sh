SHELL := /bin/sh

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
LOCAL_BIN := $(HOME)/.local/bin
CLAUDE_SKILL := $(HOME)/.claude/skills/wtree
CLAUDE_COMMAND := $(HOME)/.claude/commands/wtree.md
OPENCODE_SKILL := $(HOME)/.config/opencode/skills/wtree
OPENCODE_COMMAND := $(HOME)/.config/opencode/command/wtree.md

.PHONY: install uninstall test

install:
	./install.sh

uninstall:
	@owned_link() { target="$$(readlink "$$1")" || return 1; [ -L "$$1" ] && [ "$$(CDPATH= cd -- "$$(dirname "$$target")" && pwd -P)/$$(basename "$$target")" = "$$2" ]; }; \
	if owned_link "$(LOCAL_BIN)/wtree" "$(ROOT_DIR)/scripts/wtree"; then rm "$(LOCAL_BIN)/wtree"; fi; \
	if owned_link "$(CLAUDE_SKILL)" "$(ROOT_DIR)/skills/wtree"; then rm "$(CLAUDE_SKILL)"; fi; \
	if owned_link "$(CLAUDE_COMMAND)" "$(ROOT_DIR)/commands/wtree.md"; then rm "$(CLAUDE_COMMAND)"; fi; \
	if owned_link "$(OPENCODE_SKILL)" "$(ROOT_DIR)/skills/wtree"; then rm "$(OPENCODE_SKILL)"; fi; \
	if owned_link "$(OPENCODE_COMMAND)" "$(ROOT_DIR)/commands/wtree.md"; then rm "$(OPENCODE_COMMAND)"; fi; \
	printf 'Removed wtree links owned by %s\n' "$(ROOT_DIR)"

test:
	bash tests/wtree_test.sh
	bash tests/install_test.sh
