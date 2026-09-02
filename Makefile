SHELL := /bin/sh

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
LOCAL_BIN := $(HOME)/.local/bin
CLAUDE_SKILL := $(HOME)/.claude/skills/wtree
CLAUDE_COMMAND := $(HOME)/.claude/commands/wtree.md
OPENCODE_COMMAND := $(HOME)/.config/opencode/command/wtree.md

.PHONY: install uninstall test

install:
	./install.sh

uninstall:
	@if [ -L "$(LOCAL_BIN)/wtree" ] && [ "$$(readlink "$(LOCAL_BIN)/wtree")" = "$(ROOT_DIR)/scripts/wtree" ]; then rm "$(LOCAL_BIN)/wtree"; fi
	@if [ -L "$(CLAUDE_SKILL)" ] && [ "$$(readlink "$(CLAUDE_SKILL)")" = "$(ROOT_DIR)/skills/wtree" ]; then rm "$(CLAUDE_SKILL)"; fi
	@if [ -L "$(CLAUDE_COMMAND)" ] && [ "$$(readlink "$(CLAUDE_COMMAND)")" = "$(ROOT_DIR)/commands/wtree.md" ]; then rm "$(CLAUDE_COMMAND)"; fi
	@if [ -L "$(OPENCODE_COMMAND)" ] && [ "$$(readlink "$(OPENCODE_COMMAND)")" = "$(ROOT_DIR)/commands/wtree.md" ]; then rm "$(OPENCODE_COMMAND)"; fi
	@printf 'Removed wtree links owned by %s\n' "$(ROOT_DIR)"

test:
	bash tests/wtree_test.sh
