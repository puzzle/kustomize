# This Makefile is (and must be) used by
# travis/pre-commit.sh to qualify pull requests.
#
# That script generates all the code that needs
# to be generated, and runs all the tests.
#
# Functionality in that script, expressed in bash, is
# gradually being moved here.

MYGOBIN := $(shell go env GOPATH)/bin
TOOLSBIN := $(PWD)/hack/tools/bin
PATH := $(TOOLSBIN):$(MYGOBIN):$(PATH)
SHELL := env PATH=$(PATH) /bin/bash

.DEFAULT_GOAL := all

export GO111MODULE=on

.PHONY: all
all: pre-commit

# The pre-commit.sh script generates, lints and tests.
# It uses this makefile.  For more clarity, would like
# to stop that - any scripts invoked by targets here
# shouldn't "call back" to the makefile.
.PHONY: pre-commit
pre-commit:
	./travis/pre-commit.sh

$(TOOLSBIN)/golangci-lint:
	cd hack/tools; \
	GOBIN=$(TOOLSBIN) go install github.com/golangci/golangci-lint/cmd/golangci-lint

$(TOOLSBIN)/mdrip:
	cd hack/tools; \
	GOBIN=$(TOOLSBIN) go install github.com/monopole/mdrip

# TODO: need a new release of the API, followed by a new pluginator.
# pluginator v1.1.0 is too old for the code currently needed in the API.
# Can release a new one at any time, just haven't done so.
# When one has been released,
#  - uncomment the pluginator line in './api/internal/tools/tools.go'
#  - pin the version tag in './api/go.mod' to match the new release
#  - change the following to 'cd api; GOBIN=$(MYGOBIN) go install sigs.k8s.io/kustomize/pluginator'
$(TOOLSBIN)/pluginator:
	cd pluginator; \
	GOBIN=$(TOOLSBIN) go install .

$(TOOLSBIN)/stringer:
	cd hack/tools; \
	GOBIN=$(TOOLSBIN) go install golang.org/x/tools/cmd/stringer

# Specific version tags for these utilities are pinned
# in ./api/go.mod, which seems to be as good a place as
# any to do so.  That's the reason for all the occurances
# of 'cd hack/tools;' in the dependencies; 'GOBIN=$(TOOLSBIN) go install' uses the
# local 'go.mod' to find the correct version to install.
.PHONY: install-tools
install-tools: \
	$(TOOLSBIN)/golangci-lint \
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

.PHONY: lint
lint: install-tools $(builtinplugins)
	cd api; $(TOOLSBIN)/golangci-lint run ./...
	cd kustomize; $(TOOLSBIN)/golangci-lint run ./...
	cd pluginator; $(TOOLSBIN)/golangci-lint run ./...

# pluginator consults the GOPATH env var to write generated code.
api/builtins/%.go: $(TOOLSBIN)/pluginator
	@echo "generating $*"; \
	cd plugin/builtin/$*; \
	GOPATH=$(shell pwd)/../../.. go generate ./...; \
	go fmt ./...

.PHONY: generate
generate: $(builtinplugins)

.PHONY: unit-test-api
unit-test-api: $(builtinplugins)
	cd api; go test ./...

.PHONY: unit-test-plugins
unit-test-plugins:
	./hack/runPluginUnitTests.sh

.PHONY: unit-test-kustomize
unit-test-kustomize:
	cd kustomize; go test ./...

.PHONY: unit-test-all
unit-test-all: unit-test-api unit-test-kustomize unit-test-plugins

COVER_FILE=coverage.out

.PHONY: cover
cover:
	# The plugin directory eludes coverage, and is therefore omitted
	cd api && go test ./... -coverprofile=$(COVER_FILE) && \
	go tool cover -html=$(COVER_FILE)

.PHONY: unit-tests
unit-tests: unit-tests-api unit-tests-kustomize unit-tests-plugins

# linux only.
.PHONY: $(TOOLSBIN)/kubeval
$(TOOLSBIN)/kubeval:
	d=$(shell mktemp -d); cd $$d; \
	wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz; \
	tar xf kubeval-linux-amd64.tar.gz; \
	mv kubeval $(TOOLSBIN); \
	rm -rf $$d

# linux only.
.PHONY: $(TOOLSBIN)/helm
$(TOOLSBIN)/helm:
	d=$(shell mktemp -d); cd $$d; \
	wget https://storage.googleapis.com/kubernetes-helm/helm-v2.16.0-linux-amd64.tar.gz; \
	tar -xvzf helm-v2.16.0-linux-amd64.tar.gz; \
	mv linux-amd64/helm $(TOOLSBIN); \
	rm -rf $$d

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

.PHONY: build-plugins
build-plugins:
	./plugin/buildPlugins.sh $(GOPATH)

.PHONY: build
build:
	cd pluginator && go build -o $(PLUGINATOR_NAME) .
	cd kustomize && go build -o $(KUSTOMIZE_NAME) ./main.go

.PHONY: install
install:
	cd pluginator && GOBIN=$(TOOLSBIN) go install $(PWD)/pluginator
	cd kustomize && GOBIN=$(MYGOBIN) go install $(PWD)/kustomize

.PHONY: clean
clean:
	rm -f api/$(COVER_FILE)
	rm -f $(builtinplugins)
	rm -fr $(TOOLSBIN)
