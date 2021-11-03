BUILD_FILES = $(shell go list -f '{{range .GoFiles}}{{$$.Dir}}/{{.}}\
{{end}}' ./...)
VERSION := $(shell git describe --tags $(shell git rev-list --tags --max-count=1))
DATE_FMT = +%Y-%m-%d
ifdef SOURCE_DATE_EPOCH
    BUILD_DATE ?= $(shell date -u -d "@$(SOURCE_DATE_EPOCH)" "$(DATE_FMT)" 2>/dev/null || date -u -r "$(SOURCE_DATE_EPOCH)" "$(DATE_FMT)" 2>/dev/null || date -u "$(DATE_FMT)")
else
    BUILD_DATE ?= $(shell date "$(DATE_FMT)")
endif

REVISION := $(shell git rev-parse --short HEAD)

ifndef CGO_CPPFLAGS
    export CGO_CPPFLAGS := $(CPPFLAGS)
endif
ifndef CGO_CFLAGS
    export CGO_CFLAGS := $(CFLAGS)
endif
ifndef CGO_LDFLAGS
    export CGO_LDFLAGS := $(LDFLAGS)
endif

GO_LDFLAGS := -X github.com/kmdkuk/mcing-agent/version.Revision=$(REVISION) $(GO_LDFLAGS)
GO_LDFLAGS := -X github.com/kmdkuk/mcing-agent/version.BuildDate=$(BUILD_DATE) $(GO_LDFLAGS)
DEV_LDFLAGS := $(GO_LDFLAGS)
GO_LDFLAGS := -X github.com/kmdkuk/mcing-agent/version.Version=$(VERSION) $(GO_LDFLAGS)

PROTOC := PATH=$(PWD)/bin $(PWD)/bin/protoc -I=$(PWD)/include:.
PROTOC_BIN := $(PWD)/bin/protoc
PROTOC_GEN_GO := $(PWD)/bin/protoc-gen-go
PROTOC_GEN_GO_GRPC := $(PWD)/bin/protoc-gen-go-grpc
PROTOC_GEN_DOC := $(PWD)/bin/protoc-gen-doc
PROTOC_VERSION := 3.14.0
PROTOC_GEN_GO_VERSION := $(shell awk '/google.golang.org\/protobuf/ {print substr($$2, 2)}' go.mod)
PROTOC_GEN_GO_GRPC_VERSON=1.0.1
PROTOC_GEN_DOC_VERSION=1.4.1

.PHONY: validate
validate: setup
	test -z "$$(gofmt -s -l . | tee /dev/stderr)"
	staticcheck ./...
	nilerr ./...
	test -z "$$(custom-checker -restrictpkg.packages=html/template,log $$(go list -tags='$(GOTAGS)' ./... ) 2>&1 | tee /dev/stderr)"
	go build ./...
	go vet ./...

.PHONY: check-generate
check-generate:
	$(MAKE) proto
	git diff --exit-code --name-only

.PHONY: proto
proto: proto/agentrpc.pb.go proto/agentrpc_grpc.pb.go docs/agentrpc.md

proto/agentrpc.pb.go: proto/agentrpc.proto $(PROTOC_BIN) $(PROTOC_GEN_GO) $(PROTOC_GEN_GO_GRPC)
	$(PROTOC) --go_out=module=github.com/kmdkuk/mcing-agent:. $<

proto/agentrpc_grpc.pb.go: proto/agentrpc.proto $(PROTOC_BIN) $(PROTOC_GEN_GO) $(PROTOC_GEN_GO_GRPC)
	$(PROTOC) --go-grpc_out=module=github.com/kmdkuk/mcing-agent:. $<

docs/agentrpc.md: proto/agentrpc.proto $(PROTOC_BIN) $(PROTOC_GEN_DOC)
	$(PROTOC) --doc_out=docs --doc_opt=markdown,$@ $<

$(PROTOC_BIN):
	mkdir -p bin
	curl -sfL -o protoc.zip https://github.com/protocolbuffers/protobuf/releases/download/v$(PROTOC_VERSION)/protoc-$(PROTOC_VERSION)-linux-x86_64.zip
	unzip -o protoc.zip bin/protoc 'include/*'
	rm -f protoc.zip

$(PROTOC_GEN_GO):
	mkdir -p bin
	GOBIN=$(PWD)/bin go install google.golang.org/protobuf/cmd/protoc-gen-go@v$(PROTOC_GEN_GO_VERSION)

$(PROTOC_GEN_GO_GRPC):
	mkdir -p bin
	GOBIN=$(PWD)/bin go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v$(PROTOC_GEN_GO_GRPC_VERSON)

$(PROTOC_GEN_DOC):
	mkdir -p bin
	GOBIN=$(PWD)/bin go install github.com/pseudomuto/protoc-gen-doc/cmd/protoc-gen-doc@v$(PROTOC_GEN_DOC_VERSION)

bin/mcing-agent: $(BUILD_FILES)
	go build -trimpath -ldflags "$(GO_LDFLAGS)" -o "$@" .

dev: $(BUILD_FILES)
	go build -trimpath -ldflags "$(DEV_LDFLAGS)" -o "bin/mcing-agent-dev" .

test:
	go test ./...
.PHONY: test

.PHONY: setup
setup: custom-checker staticcheck nilerr $(PROTOC_BIN) $(PROTOC_GEN_GO) $(PROTOC_GEN_GO_GRPC) $(PROTOC_GEN_DOC)

.PHONY: custom-checker
custom-checker:
	if ! which custom-checker >/dev/null; then \
		env GOFLAGS= go install github.com/cybozu/neco-containers/golang/analyzer/cmd/custom-checker@latest; \
	fi

.PHONY: staticcheck
staticcheck:
	if ! which staticcheck >/dev/null; then \
		env GOFLAGS= go install honnef.co/go/tools/cmd/staticcheck@latest; \
	fi

.PHONY: nilerr
nilerr:
	if ! which nilerr >/dev/null; then \
		env GOFLAGS= go install github.com/gostaticanalysis/nilerr/cmd/nilerr@latest; \
	fi

.PHONY: clean
clean:
	rm -rf build
