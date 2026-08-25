SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := build

GO ?= go
REPO_ROOT := ../..
BUILD_COMMIT ?= $(shell git -C "$(REPO_ROOT)" rev-parse HEAD)
BUILD_ARCH ?= amd64
LDFLAGS := -ldflags "-X=main.commitSHA=$(BUILD_COMMIT)"

.PHONY: build test fmt fmt-check vet generate

build:
	mkdir -p bin
	CGO_ENABLED=0 GOOS=linux GOARCH=$(BUILD_ARCH) $(GO) build -trimpath -buildvcs=false -o bin/envd $(LDFLAGS) .

test:
	$(GO) test -race ./...
	cd shared && $(GO) test -race ./...

fmt:
	$(GO) fmt ./...
	cd shared && $(GO) fmt ./...

fmt-check:
	@test -z "$$(gofmt -l $$(find . -name '*.go' -not -path './bin/*'))" || { \
		echo "envd Go files require gofmt:" >&2; \
		gofmt -l $$(find . -name '*.go' -not -path './bin/*') >&2; \
		exit 1; \
	}

vet:
	$(GO) vet ./...
	cd shared && $(GO) vet ./...

generate:
	$(GO) generate ./...
