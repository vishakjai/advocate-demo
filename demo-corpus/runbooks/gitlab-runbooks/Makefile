SHELL := /usr/bin/env bash

# Exclude vendor and dot directories, but do include the `.gitlab` directory
VERIFY_PATH_SELECTOR := \( -not \( -path "*/vendor/*" -o -path "*/.*/*" \) -o -path "*/.gitlab/*" \)

JSONNET_FMT_FLAGS := --string-style s -n 2
JSONNET_FILES ?= $(shell find . \( -name "*.jsonnet" -o -name "*.libsonnet" \)  -type f $(VERIFY_PATH_SELECTOR) )

SHELL_FMT_FLAGS := -i 2 -ci
SHELL_FILES = $(shell find . -type f \( -perm -u=x -o -name "*.sh" \) $(VERIFY_PATH_SELECTOR) -print0|xargs -0 file -n |grep 'Bourne-Again'|cut -d: -f1)

AMTOOL = $(shell which amtool || echo "/alertmanager/amtool")
AMTOOL_PATH=$(dir $(AMTOOL))
JSONNET_COMMAND = $(shell which jsonnetfmt || (which jsonnet && echo " fmt"))

SHELLCHECK_FLAGS := -e SC1090,SC1091,SC2002

.PHONY: help
help:  ## Lists all available commands
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

.PHONY: all
all: verify

.PHONY: verify
verify: verify-shellcheck verify-fmt

.PHONY: verify-fmt
verify-fmt:
	if ! $(JSONNET_COMMAND) $(JSONNET_FMT_FLAGS) --test $(JSONNET_FILES) ; then $(JSONNET_COMMAND) $(JSONNET_FMT_FLAGS) -i $(JSONNET_FILES); git --no-pager diff; exit 1; fi
	shfmt $(SHELL_FMT_FLAGS) -l -d $(SHELL_FILES)

.PHONY: verify-shellcheck
verify-shellcheck:
	shellcheck $(SHELLCHECK_FLAGS) $(SHELL_FILES)

.PHONY: fmt
fmt: jsonnet-fmt shell-fmt
	git diff --exit-code

.PHONY: jsonnet-fmt
jsonnet-fmt:
	$(JSONNET_COMMAND) $(JSONNET_FMT_FLAGS) -i $(JSONNET_FILES)

.PHONY: shell-fmt
shell-fmt:
	shfmt $(SHELL_FMT_FLAGS) -w $(SHELL_FILES)

.PHONY: markdown-fmt
markdown-fmt:
	npm run markdownlint -- docs README.md --fix

.PHONY: generate
generate: jsonnet-bundle
	./scripts/generate.sh

alertmanager/alertmanager.yml: alertmanager/alertmanager.jsonnet
	./alertmanager/generate.sh

test-alertmanager: alertmanager/alertmanager.yml
	$(AMTOOL) check-config alertmanager/alertmanager.yml
	PATH=$(AMTOOL_PATH):$(PATH) alertmanager/test-routing.sh alertmanager/alertmanager.yml

.PHONY: test
test: validate-service-dashboards validate-service-catalog validate-prom-rules validate-kibana-urls validate-alerts validate-yaml jsonnet-bundle test-jsonnet test-shunit

.PHONY: validate-service-catalog
validate-service-catalog:
	./scripts/validate-service-catalog.rb

.PHONY: validate-service-dashboards
validate-service-dashboards:
	./scripts/validate-service-dashboards

.PHONY: validate-prom-rules
validate-prom-rules:
	./scripts/validate-recording-rule-groups

.PHONY: validate-kibana-urls
validate-kibana-urls:
	./scripts/validate_kibana_urls

.PHONY: validate-alerts
validate-alerts:
	./scripts/validate-alerts

.PHONY:validate-yaml
validate-yaml:
	@if ! command -v yamllint >/dev/null; then echo "Please install yamllint: https://yamllint.readthedocs.io/en/stable/quickstart.html#installing-yamllint"; exit 1; fi
	yamllint -f colored .

.PHONY: test-jsonnet
test-jsonnet:
	./scripts/jsonnet_test.sh

.PHONY: test-shunit
test-shunit:
	./test/custom-reference-architecture_test.sh

.PHONY: test-alert-templates
test-alert-templates:
	cd alertmanager/templates && go test -v ./...

.PHONY: jsonnet-bundle
jsonnet-bundle:
	./scripts/bundler.sh

# Checks the `make generate` doesn't modify any files, or create any new files
.PHONY: ensure-generated-content-up-to-date
ensure-generated-content-up-to-date: generate
	(git diff --exit-code && \
		[[ "$$(git ls-files -o --directory --exclude-standard | sed q | wc -l)" == "0" ]]) || \
	(echo "Please run 'make generate'" && exit 1)

.PHONY: .update-feature-categories
.update-feature-categories:
	./scripts/update_stage_groups_feature_categories.rb && ./scripts/update_stage_groups_dashboards.rb && ./scripts/update_stage_error_budget_dashboards.rb

.PHONY: generate-crossover-mappings
generate-crossover-mappings:
	./scripts/generate_crossover_stage_group_mappings.rb

.PHONY: update-feature-categories
update-feature-categories: .update-feature-categories generate-crossover-mappings generate

# In CI, we don't want to generate crossover mappings, as those depend on a git
# diff compared to the previous HEAD.
.PHONY: update-feature-categories-ci
update-feature-categories-ci: .update-feature-categories generate

.PHONY: validate-mimir-rules
validate-mimir-rules:
	@for dir in $$(find mimir-rules -mindepth 1 -maxdepth 1 -type d); do \
		tenant=$$(basename $${dir}); \
		echo "Checking rules for tenant: $${tenant}"; \
		mimirtool rules check --rule-dirs="$${dir}"; \
	done

.PHONY: generate-mixins
generate-mixins:
	./scripts/generate-mixins.sh

# Ensure that you have Graphviz and Python installed
# Instructions at https://diagrams.mingrammer.com/docs/getting-started/installation
# then install `pip install diagrams`
diagrams:
	./scripts/make-diagrams

glsh-install:
	ln -s $$PWD/glsh.sh /usr/local/bin/glsh

build-docker-image:
	docker build -t runbooks \
		$(shell awk '/^[^# ]/ { gsub("-", "_", $$1); print "--build-arg=GL_ASDF_" toupper($$1) "_VERSION=" $$2 }' .tool-versions) \
		.
