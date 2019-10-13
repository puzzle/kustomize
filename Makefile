# This Makefile is (and must be) used by
# travis/pre-commit.sh to qualify pull requests.
#
# That script generates all the code that needs
# to be generated, and runs all the tests.
#
# Functionality in that script, expressed in bash, is
# gradually being moved here.

MYGOBIN := $(shell go env GOPATH)/bin

.DEFAULT_GOAL := all

export GO111MODULE=on

.PHONY: all
all:
	./travis/pre-commit.sh

$(MYGOBIN)/golangci-lint:
	cd hack/tools; go install github.com/golangci/golangci-lint/cmd/golangci-lint

$(MYGOBIN)/mdrip:
	cd hack/tools; go install github.com/monopole/mdrip

# TODO: need a new release of the API, followed by a new pluginator.
# pluginator v1.1.0 is too old for the code currently needed in the API.
# Can release a new one at any time, just haven't done so.
# When one has been released,
#  - uncomment the pluginator line in './api/internal/tools/tools.go'
#  - pin the version tag in './api/go.mod' to match the new release
#  - change the following to 'cd api; go install sigs.k8s.io/kustomize/pluginator'
$(MYGOBIN)/pluginator:
	cd pluginator; go install .

$(MYGOBIN)/stringer:
	cd hack/tools; go install golang.org/x/tools/cmd/stringer

# Specific version tags for these utilities are pinned in ./api/go.mod
# which seems to be as good a place as any to do so.
# That's the reason for all the occurances of 'cd api;' in the
# dependencies; 'go install' uses the local 'go.mod' to get the version.
install-tools: $(MYGOBIN)/golangci-lint \
	$(MYGOBIN)/mdrip \
	$(MYGOBIN)/pluginator \
	$(MYGOBIN)/stringer

.PHONY: lint
lint: install-tools
	cd api; $(MYGOBIN)/golangci-lint run ./...
	cd kustomize; $(MYGOBIN)/golangci-lint run ./...
	cd pluginator; $(MYGOBIN)/golangci-lint run ./...

.PHONY: unit-test-api
unit-test-api:
	cd api; go test ./...

.PHONY: unit-test-plugins
unit-test-plugins:
	# Looks upstream is fixing this makefile little by little
	# cd plugin/builtin/prefixsuffixtransformer && go test -v ./...
	# cd plugin/builtin/replicacounttransformer && go test -v ./...
	# cd plugin/builtin/patchstrategicmergetransformer && go test -v ./...
	# cd plugin/builtin/imagetagtransformer && go test -v ./...
	# cd plugin/builtin/namespacetransformer && go test -v ./...
	# cd plugin/builtin/labeltransformer && go test -v ./...
	# cd plugin/builtin/legacyordertransformer && go test -v ./...
	# cd plugin/builtin/patchtransformer && go test -v ./...
	# cd plugin/builtin/configmapgenerator && go test -v ./...
	# cd plugin/builtin/inventorytransformer && go test -v ./...
	# cd plugin/builtin/annotationstransformer && go test -v ./...
	# cd plugin/builtin/secretgenerator && go test -v ./...
	# cd plugin/builtin/patchjson6902transformer && go test -v ./...
	# cd plugin/builtin/hashtransformer && go test -v ./...
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
	cd api && go tool cover -html=$(COVER_FILE)

.PHONY: unit-tests
unit-tests: unit-tests-api unit-tests-kustomize unit-tests-plugins

# linux only.
$(MYGOBIN)/kubeval:
	d=$(shell mktemp -d); cd $$d; \
	wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz; \
	tar xf kubeval-linux-amd64.tar.gz; \
	mv kubeval $(MYGOBIN); \
	rm -rf $$d

# linux only.
$(MYGOBIN)/helm:
	d=$(shell mktemp -d); cd $$d; \
	wget https://storage.googleapis.com/kubernetes-helm/helm-v2.16.0-linux-amd64.tar.gz; \
	tar -xvzf helm-v2.16.0-linux-amd64.tar.gz; \
	mv linux-amd64/helm $(MYGOBIN); \
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
	# Looks upstream is fixing this makefile little by little
	# cd api && go mod tidy
	# cd kustomize && go mod tidy
	# cd pluginator && go mod tidy
	# cd plugin/builtin/prefixsuffixtransformer && go mod tidy
	# cd plugin/builtin/replicacounttransformer && go mod tidy
	# cd plugin/builtin/patchstrategicmergetransformer && go mod tidy
	# cd plugin/builtin/imagetagtransformer && go mod tidy
	# cd plugin/builtin/namespacetransformer && go mod tidy
	# cd plugin/builtin/labeltransformer && go mod tidy
	# cd plugin/builtin/legacyordertransformer && go mod tidy
	# cd plugin/builtin/patchtransformer && go mod tidy
	# cd plugin/builtin/configmapgenerator && go mod tidy
	# cd plugin/builtin/inventorytransformer && go mod tidy
	# cd plugin/builtin/annotationstransformer && go mod tidy
	# cd plugin/builtin/secretgenerator && go mod tidy
	# cd plugin/builtin/patchjson6902transformer && go mod tidy
	# cd plugin/builtin/hashtransformer && go mod tidy
	# cd hack/tools && go mod tidy
	./hack/doGoMod.sh tidy


.PHONY: generate-code
generate-code: $(PLUGINATOR)
	./api/internal/plugins/builtinhelpers/generateBuiltins.sh $(GOPATH)

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
	cd pluginator && go install $(PWD)/pluginator
	cd kustomize && go install $(PWD)/kustomize

.PHONY: clean
clean:
	cd kustomize && go clean && rm -f $(KUSTOMIZE_NAME)
	rm -f $(COVER_FILE)


