SHELL := /bin/bash

.PHONY: help validate drift sync sync-dry deploy link release

help:
	@echo "validate   frontmatter, catalog description cap, cited paths"
	@echo "drift      compare the installed skills with this checkout (exit 1 on drift)"
	@echo "sync       pull edits from the installed copy into this checkout (dry run: sync-dry)"
	@echo "deploy     copy this checkout into the installed copy"
	@echo "link       replace the installed copies with symlinks to this checkout (one-time)"
	@echo "release    tag, push and publish: make release VERSION=1.1.0"

validate:
	python3 tools/validate-skills.py

drift:
	bash tools/drift.sh

sync:
	bash tools/sync-from-global.sh

sync-dry:
	bash tools/sync-from-global.sh --dry-run

deploy:
	bash tools/deploy.sh

link:
	bash tools/link.sh

release:
	@if [ -z "$(VERSION)" ]; then echo "usage: make release VERSION=1.1.0" >&2; exit 1; fi
	bash tools/release.sh "$(VERSION)"
