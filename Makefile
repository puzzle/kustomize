# Copyright 2019 The Kubernetes Authors.
# SPDX-License-Identifier: Apache-2.0
#
# Makefile for kustomize CLI and API.

MYGOBIN := $(shell go env GOPATH)/bin
TOOLSBIN := $(PWD)/hack/tools/bin
PATH := $(TOOLSBIN):$(MYGOBIN):$(PATH)
SHELL := /bin/bash

.DEFAULT_GOAL := all

export GO111MODULE=on

.PHONY: all
all: verify-kustomize

.PHONY: verify-kustomize
verify-kustomize: \
	lint-kustomize \
	test-unit-kustomize-all \
	test-examples-kustomize-against-HEAD \
	test-examples-kustomize-against-latest

# Other builds in this repo might want a different linter version.
# Without one Makefile to rule them all, the different makes
# cannot assume that golanci-lint is at the version they want
# since everything uses the same implicit GOPATH.
# This installs in a temp dir to avoid overwriting someone else's
# linter, then installs in MYGOBIN with a new name.
# Version pinned by hack/tools/go.mod
$(TOOLSBIN)/golangci-lint-kustomize:
	( \
		set -e; \
		cd hack/tools; \
		GO111MODULE=on GOBIN=$(TOOLSBIN) go install github.com/golangci/golangci-lint/cmd/golangci-lint; \
		mv $(TOOLSBIN)/golangci-lint $(TOOLSBIN)/golangci-lint-kustomize \
	)

# Version pinned by hack/tools/go.mod
$(TOOLSBIN)/mdrip:
	cd hack/tools; \
	GOBIN=$(TOOLSBIN) go install github.com/monopole/mdrip

# Version pinned by hack/tools/go.mod
$(TOOLSBIN)/stringer:
	cd hack/tools; \
	GOBIN=$(TOOLSBIN) go install golang.org/x/tools/cmd/stringer

# Version pinned by hack/tools/go.mod
$(TOOLSBIN)/goimports:
	cd hack/tools; \
	GOBIN=$(TOOLSBIN) go install golang.org/x/tools/cmd/goimports

# Version pinned by hack/tools/go.mod
$(TOOLSBIN)/pluginator:
	cd hack/tools; \
	GOBIN=$(TOOLSBIN) go install sigs.k8s.io/kustomize/pluginator/v2

# Install kustomize from whatever is checked out.
$(MYGOBIN)/kustomize:
	cd kustomize; \
	GOBIN=$(TOOLSBIN) go install .

.PHONY: install-tools
install-tools: \
	$(TOOLSBIN)/goimports \
	$(TOOLSBIN)/golangci-lint-kustomize \
	$(TOOLSBIN)/mdrip \
	$(TOOLSBIN)/pluginator \
	$(TOOLSBIN)/stringer

# Builtin plugins are generated code.
# Add new items here to create new builtins.
builtinplugins = \
	api/builtins/annotationstransformer.go \
	api/builtins/configmapgenerator.go \
	api/builtins/hashtransformer.go \
	api/builtins/imagetagtransformer.go \
	api/builtins/inventorytransformer.go \
	api/builtins/labeltransformer.go \
	api/builtins/legacyordertransformer.go \
	api/builtins/namespacetransformer.go \
	api/builtins/patchjson6902transformer.go \
	api/builtins/patchstrategicmergetransformer.go \
	api/builtins/patchtransformer.go \
	api/builtins/prefixsuffixtransformer.go \
	api/builtins/replicacounttransformer.go \
	api/builtins/secretgenerator.go

.PHONY: lint-kustomize
lint-kustomize: install-tools $(builtinplugins)
	cd api; \
	$(TOOLSBIN)/golangci-lint-kustomize -c ../.golangci-kustomize.yml run ./...
	cd kustomize; \
	$(TOOLSBIN)/golangci-lint-kustomize -c ../.golangci-kustomize.yml run ./...
	cd pluginator; \
	$(TOOLSBIN)/golangci-lint-kustomize -c ../.golangci-kustomize.yml run ./...

# TODO: modify rule to trigger on source material.  E.g. editting
#   plugin/builtin/namespacetransformer/NamespaceTransformer.go
# should trigger regeneration of
#   api/builtins/namespacetransformer.go
# To faciliate a simple rule, rename the name of the generated
# file to CamelCase format like the source material.
api/builtins/%.go: $(TOOLSBIN)/pluginator $(TOOLSBIN)/goimports
	@echo "generating $*"
	( \
		set -e; \
		cd plugin/builtin/$*; \
		go generate .; \
		cd ../../../api/builtins; \
		$(TOOLSBIN)/goimports -w $*.go \
	)

.PHONY: generate
generate: $(builtinplugins)

.PHONY: test-unit-kustomize-api
test-unit-kustomize-api: $(builtinplugins)
	cd api; go test ./...

.PHONY: test-unit-kustomize-plugins
test-unit-kustomize-plugins:
	./hack/testUnitKustomizePlugins.sh

.PHONY: test-unit-kustomize-cli
test-unit-kustomize-cli:
	cd kustomize; go test ./...

.PHONY: test-unit-kustomize-all
test-unit-kustomize-all: \
	test-unit-kustomize-api \
	test-unit-kustomize-cli \
	test-unit-kustomize-plugins

COVER_FILE=coverage.out

.PHONY: cover
cover:
	# The plugin directory eludes coverage, and is therefore omitted
	cd api && go test ./... -coverprofile=$(COVER_FILE) && \
	go tool cover -html=$(COVER_FILE)

.PHONY:
test-examples-kustomize-against-HEAD: $(MYGOBIN)/kustomize $(TOOLSBIN)/mdrip
	./hack/testExamplesAgainstKustomize.sh HEAD

.PHONY:
test-examples-kustomize-against-latest: $(TOOLSBIN)/mdrip
	( \
		set -e; \
		/bin/rm -f $(TOOLSBIN)/kustomize; \
		echo "Installing kustomize from latest."; \
		GO111MODULE=on GOBIN=$(TOOLSBIN) go install sigs.k8s.io/kustomize/kustomize/v3; \
		./hack/testExamplesAgainstKustomize.sh latest; \
		echo "Reinstalling kustomize from HEAD."; \
		/bin/rm -f $(TOOLSBIN)/kustomize; \
		cd kustomize; GOBIN=$(MYGOBIN) go install .; \
	)

# linux only.
# This is for testing an example plugin that
# uses kubeval for validation.
# Don't want to add a hard dependence in go.mod file
# to github.com/instrumenta/kubeval.
# Instead, download the binary.
$(TOOLSBIN)/kubeval:
	( \
		set -e; \
		d=$(shell mktemp -d); cd $$d; \
		wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz; \
		tar xf kubeval-linux-amd64.tar.gz; \
		mv kubeval $(TOOLSBIN); \
		rm -rf $$d; \
	)

# linux only.
# This is for testing an example plugin that
# uses helm to inflate a chart for subsequent kustomization.
# Don't want to add a hard dependence in go.mod file
# to helm.
# Instead, download the binary.
$(TOOLSBIN)/helm:
	( \
		set -e; \
		d=$(shell mktemp -d); cd $$d; \
		wget https://storage.googleapis.com/kubernetes-helm/helm-v2.16.0-linux-amd64.tar.gz; \
		tar -xvzf helm-v2.16.0-linux-amd64.tar.gz; \
		mv linux-amd64/helm $(TOOLSBIN); \
		rm -rf $$d \
	)

.PHONY: fmt-api
fmt-api:
	cd api; go fmt ./...

.PHONY: fmt-kustomize
fmt-kustomize:
	cd kustomize; go fmt ./...

.PHONY: fmt-pluginator
fmt-pluginator:
	cd pluginator; go fmt ./...

.PHONY: fmt-plugins
fmt-plugins:
	cd plugin/builtin/prefixsuffixtransformer && go fmt ./...
	cd plugin/builtin/replicacounttransformer && go fmt ./...
	cd plugin/builtin/patchstrategicmergetransformer && go fmt ./...
	cd plugin/builtin/imagetagtransformer && go fmt ./...
	cd plugin/builtin/namespacetransformer && go fmt ./...
	cd plugin/builtin/labeltransformer && go fmt ./...
	cd plugin/builtin/legacyordertransformer && go fmt ./...
	cd plugin/builtin/patchtransformer && go fmt ./...
	cd plugin/builtin/configmapgenerator && go fmt ./...
	cd plugin/builtin/inventorytransformer && go fmt ./...
	cd plugin/builtin/annotationstransformer && go fmt ./...
	cd plugin/builtin/secretgenerator && go fmt ./...
	cd plugin/builtin/patchjson6902transformer && go fmt ./...
	cd plugin/builtin/hashtransformer && go fmt ./...

.PHONY: fmt
fmt: fmt-api fmt-kustomize fmt-pluginator fmt-plugins

.PHONY: modules
modules:
	./hack/doGoMod.sh tidy

## --------------------------------------
## Binaries
## --------------------------------------

.PHONY: build
build:
	cd pluginator && go build -o $(PLUGINATOR_NAME) .
	cd kustomize && go build -o $(KUSTOMIZE_NAME) ./main.go

.PHONY: install
install: generate
	cd pluginator && GOBIN=$(TOOLSBIN) go install $(PWD)/pluginator
	cd kustomize && GOBIN=$(MYGOBIN) go install $(PWD)/kustomize


.PHONY: clean
clean:
	rm -f api/$(COVER_FILE)
	rm -f $(builtinplugins)
	rm -f $(MYGOBIN)/kustomize
	rm -f $(TOOLSBIN)/goimports
	rm -f $(TOOLSBIN)/golangci-lint-kustomize
	rm -f $(TOOLSBIN)/golangci-lint
	rm -f $(TOOLSBIN)/mdrip
	rm -f $(TOOLSBIN)/pluginator
	rm -f $(TOOLSBIN)/stringer

.PHONY: nuke
nuke: clean
	sudo rm -rf $(shell go env GOPATH)/pkg/mod/sigs.k8s.io
