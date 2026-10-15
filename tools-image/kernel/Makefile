SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := build

DOCKER ?= docker
OUTPUT_DIR ?= out
BUILD_JOBS ?= 8
APT_MIRROR_BASE ?=

.PHONY: build build-local test

build:
	"$(DOCKER)" buildx build --platform linux/amd64 --target artifact \
		--build-arg "BUILD_JOBS=$(BUILD_JOBS)" \
		--build-arg "APT_MIRROR_BASE=$(APT_MIRROR_BASE)" \
		--output "type=local,dest=$(OUTPUT_DIR)" .

build-local:
	BUILD_JOBS="$(BUILD_JOBS)" bash ./build.sh "$(OUTPUT_DIR)"

test:
	bash ./tests/verify-config.sh
