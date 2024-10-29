SHELL         := /bin/bash
MAKEFLAGS     += --warn-undefined-variables
.SHELLFLAGS   := -euo pipefail -c

HELM_DIR    ?= chisel
OUTPUT_DIR  ?= .

SED 		?= gsed

# check if there are any existing `git tag` values
ifeq ($(shell git tag),)
# no tags found - default to initial tag `v0.0.0`
export VERSION := $(shell echo "0.0.0-$$(git rev-list HEAD --count)-g$$(git describe --dirty --always)" | sed 's/-/./2' | sed 's/-/./2')
else
# use tags
export VERSION := $(shell git describe --dirty --always --tags --exclude 'helm*' | sed 's/-/./2' | sed 's/-/./2')
endif


# ====================================================================================
# Colors

BLUE         := $(shell printf "\033[34m")
YELLOW       := $(shell printf "\033[33m")
RED          := $(shell printf "\033[31m")
GREEN        := $(shell printf "\033[32m")
CNone        := $(shell printf "\033[0m")

# ====================================================================================
# Logger

TIME_LONG	= `date +%Y-%m-%d' '%H:%M:%S`
TIME_SHORT	= `date +%H:%M:%S`
TIME		= $(TIME_SHORT)

INFO	= echo ${TIME} ${BLUE}[ .. ]${CNone}
WARN	= echo ${TIME} ${YELLOW}[WARN]${CNone}
ERR		= echo ${TIME} ${RED}[FAIL]${CNone}
OK		= echo ${TIME} ${GREEN}[ OK ]${CNone}
FAIL	= (echo ${TIME} ${RED}[FAIL]${CNone} && false)


# ====================================================================================
# Helm Chart

helm.docs: ## Generate helm docs
	@cd $(HELM_DIR); \
	docker run --rm -v $(shell pwd)/$(HELM_DIR):/helm-docs -u $(shell id -u) jnorwood/helm-docs:v1.7.0

HELM_VERSION ?= $(shell helm show chart $(HELM_DIR) | grep 'version:' | sed 's/version: //g')

helm.build: ## Build helm chart
	@$(INFO) helm package
	@helm package $(HELM_DIR) --dependency-update --destination $(OUTPUT_DIR)/chart
	@cp $(OUTPUT_DIR)/chart/chisel-$(HELM_VERSION).tgz $(OUTPUT_DIR)/chart/chisel.tgz
	@$(OK) helm package

helm.test:
	@helm unittest --file tests/*.yaml chisel

helm.test.update: helm.generate
	@helm unittest -u --file tests/*.yaml chisel

helm.update.appversion:
	@chartversion=$$(yq .version $(HELM_DIR)/Chart.yaml) ; \
	chartappversion=$$(yq .appVersion $(HELM_DIR)/Chart.yaml) ; \
	chartname=$$(yq .name $(HELM_DIR)/Chart.yaml) ; \
	$(INFO) Update chartname and chartversion string in test snapshots.; \
	$(SED) -s -i "s/^\([[:space:]]\+helm\.sh\/chart:\).*/\1 $${chartname}-$${chartversion}/" $(HELM_DIR)/tests/__snapshot__/*.yaml.snap ; \
	$(SED) -s -i "s/^\([[:space:]]\+app\.kubernetes\.io\/version:\).*/\1 $${chartappversion}/" $(HELM_DIR)/tests/__snapshot__/*.yaml.snap ; \
	$(SED) -s -i "s/^\([[:space:]]\+image: ghcr\.io\/chisel-helm\/chisel-helm:\).*/\1$${chartappversion}/" $(HELM_DIR)/tests/__snapshot__/*.yaml.snap ; \
	$(OK) "Version strings updated"

# ====================================================================================
# Help

.PHONY: help
# only comments after make target name are shown as help text
help: ## Displays this help message
	@echo -e "$$(grep -hE '^\S+:.*##' $(MAKEFILE_LIST) | sed -e 's/:.*##\s*/|/' -e 's/^\(.\+\):\(.*\)/\\x1b[36m\1\\x1b[m:\2/' | column -c2 -t -s'|' | sort)"


.PHONY: clean
clean:  ## Clean bins
	@$(INFO) clean
	@rm -f $(OUTPUT_DIR)/chisel-helm-linux-*
	@$(OK) go build $*
