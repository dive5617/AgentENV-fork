# AgentENV envd Tools Drive

This directory contains the source for the envd tools drive attached to every
Firecracker guest as `/dev/vda`.

This source is here so contributors can inspect and reproduce the tools drive
that AgentENV consumes as a prebuilt runtime asset. Normal `make start-server`
does not rebuild this image; server startup continues to download the configured
tools drive from `config/deps_manifest.toml` unless `tools.drive_path` points at
a local ext4 file.

The build is intentionally self-contained:

1. Compile the repository-owned source from `./envd`.
2. Assemble the guest tools rootfs with BusyBox, `/init`, `/agentenv/pivot-init`,
   and `/agentenv/envd`.
3. Create `/tools.ext4`.

Requirements:

- Docker with the Buildx plugin available (`docker buildx version`).
- The Dockerfile's `GO_VERSION` must remain compatible with `./envd/go.mod`.
- The in-tree envd must support `-disable-bash-login-shell`. AgentENV enables
  this opt-in policy at guest startup, and the build contract rejects a source
  tree that no longer provides it.

The initial envd import and license provenance are recorded in
[`envd/UPSTREAM.md`](envd/UPSTREAM.md). Tools-image builds do not fetch
envd source from another repository.

## Local Build

From this directory:

```bash
make
```

From the repository root:

```bash
make -C tools-image
```

The output is written to:

```text
tools-image/out/tools-<TOOLS_VERSION>-<ARCH>.ext4
```

## Versioning

`TOOLS_VERSION` is the SemVer release of the complete drive, including envd,
BusyBox, and the init scripts. Published versions are immutable: any byte-level
change requires a new version. `ENVD_COMMIT` records the AgentENV source commit
used for the build and is not the semantic version reported by the binary.

Official releases use normal versions such as `0.1.0`. Custom distributions use
a prerelease identifier that is unique within the AgentENV deployment, such as
`0.1.0-custom.1`. Do not publish different drive contents under the same
version.

AgentENV's runtime config records the expected in-guest envd version:

```toml
[envd]
version = "..."
```

After building a tools drive, use the build log to find the value printed by:

```bash
/out/envd -version
```

That is the value that should match `[envd].version`. For cross-architecture
builds, the Dockerfile skips executing the target binary in the builder; mount
the generated ext4 on a matching Linux host and run `/agentenv/envd -version`
there instead. The build also prints, for native builds:

```bash
/out/envd -commit
```

which identifies the AgentENV commit baked into the binary.

## Configuration

The build accepts these Make variables:

| Variable                       | Default                                             | Description                                                                                  |
| ------------------------------ | --------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `TOOLS_VERSION`                | `0.1.0`                                             | Immutable SemVer release of the complete tools drive                                         |
| `ENVD_COMMIT`                  | current AgentENV Git commit                         | Source revision embedded in `envd -commit`                                                   |
| `ARCH`                         | host architecture, normalized to `amd64` or `arm64` | Target architecture                                                                          |
| `PUBLISH_PLATFORMS`            | `linux/amd64,linux/arm64`                           | Platforms included in the published OCI image                                                |
| `OUTPUT_DIR`                   | `out`                                               | Directory for exported tools drive images                                                    |
| `OUTPUT_NAME`                  | `tools-${TOOLS_VERSION}-${ARCH}.ext4`               | Versioned tools drive filename                                                               |
| `IMAGE`                        | `agentenv-tools:${TOOLS_VERSION}`                   | Local or remote image tag                                                                    |
| `OBSERVABILITY_ARTIFACT_IMAGE` | `agentenv-observability-guest:feat-ob`              | Architecture-matched Guest observer artifact image consumed while assembling the tools drive |
| `DOCKER_LIBRARY_REGISTRY`      | `docker.m.daocloud.io/library`                      | Reachable Docker Official Images mirror used for BusyBox, Go, and Debian build stages        |
| `APT_MIRROR_BASE`              | `http://mirrors.aliyun.com`                         | Debian package mirror base used by the envd and ext4 builder stages                          |
| `GOPROXY`                      | `https://goproxy.cn,direct`                         | Go module proxy used while compiling envd                                                    |
| `DOCKER`                       | `docker`                                            | Docker CLI command                                                                           |

Examples:

```bash
make TOOLS_VERSION=0.1.0 ARCH=amd64

make TOOLS_VERSION=0.1.0 ENVD_COMMIT="$(git rev-parse HEAD)" ARCH=amd64
```

## Publish

The `publish` target builds a multi-platform artifact and pushes it to `IMAGE`.
It accepts SemVer releases and prereleases without build metadata, requires the
image tag to match that version, and refuses to overwrite a tag found by its
preflight check. That check is not atomic: the registry must enforce immutable
tags to prevent concurrent or external publishers from replacing a release.

```bash
make publish \
  TOOLS_VERSION=0.1.0 \
  IMAGE=ghcr.io/kvcache-ai/agentenv-tools:0.1.0

make publish \
  TOOLS_VERSION=0.1.0-custom.1 \
  ENVD_REF=2026.17 \
  OBSERVABILITY_ARTIFACT_IMAGE=registry.example.com/custom/agentenv-observability-guest:0.1.0-custom.1 \
  IMAGE=registry.example.com/custom/agentenv-tools:0.1.0-custom.1
```

After validation, update `[tools].version` in `config/deps_manifest.toml` to
the newly published version. Git revisions and OCI digests remain release
provenance; snapshots persist only `TOOLS_VERSION`.

## Local Verification

To test a locally built tools drive, point AgentENV at the generated ext4:

```toml
[tools]
version = "0.1.0"
drive_path = "tools-image/out/tools-0.1.0-amd64.ext4"
```

The path is resolved relative to the server process working directory, not
relative to this README. Setup imports the file into the immutable versioned
directory under `deps_path`; changing its contents requires a new version.

Root filesystem resizing is performed by the host-side `overlaybd-resize`
binary installed from the OverlayBD package under `deps_path`; it is not part
of this guest tools drive.
