# Optional nested-QEMU guest kernel

This opt-in x86_64 kernel lets an Intel AgentENV guest act as a KVM host for
QEMU. It does not replace the default kernel, change Firecracker, or change
the tools drive. Existing deployments continue to use their current assets.

The recipe uses the Amazon Linux 6.1.175 source and Firecracker guest config
fragments pinned by commit and archive SHA-256 in `sources.env`. The overlay
enables built-in `CONFIG_VIRTUALIZATION`, `CONFIG_KVM`, `CONFIG_KVM_INTEL`, and
`CONFIG_TUN`. `CONFIG_KVM_GUEST` alone is not a KVM host driver.

Legacy virtio-MMIO command-line discovery and `CONFIG_X86_MPPARSE` remain
enabled for AgentENV's default `pci=off` boot. Virtio block, network, vsock,
ext4, and container networking options are checked after Kconfig resolves
dependencies. This is not a PCI-only kernel.

## Build

From the repository root, with Docker Buildx:

```bash
make -C tools-image/kernel test
make -C tools-image/kernel build BUILD_JOBS=8
```

The compiler runs as `nobody`, not root. `APT_MIRROR_BASE` optionally selects
an Ubuntu package mirror. Sources always have to match the pinned checksums.

Alternatively, on Linux x86_64, install `bc bison build-essential
ca-certificates curl flex libelf-dev libssl-dev`, then run as a non-root user:

```bash
make -C tools-image/kernel build-local BUILD_JOBS=8
```

`SOURCE_CACHE` may point at a directory containing the checksum-matching
`linux.tar.gz` and `firecracker.tar.gz`. `CONFIG_ONLY=1` writes `resolved.config`
without compiling or replacing existing artifacts. Artifacts are written to `out/`:
`vmlinux.bin`, `config`, `sources.env`, `kernel-release`, and `SHA256SUMS`.
Source identities and build timestamps are fixed; toolchain/package versions
are not pinned, so builds with different toolchains need not be byte-identical.

## Enable explicitly

Copy the artifact to the AENV host and select it using the existing config:

```toml
[kernel]
image_path = "/opt/agentenv/kernels/6.1.175-aenv-nested-qemu/vmlinux.bin"
```

For a Docker-hosted server, bind-mount that file read-only at the same
container path and use the custom config through `AENV_CONFIG_PATH`. Leave
the existing Firecracker boot arguments unchanged. The override is global
to that server, not per sandbox; validate on a separate server/state directory
before rolling it out. Removing the override selects the original kernel.

The physical host must have working nested Intel KVM and expose VMX to the
AENV guest. Kernel configuration cannot supply missing CPU virtualization.
Inside the sandbox, verify `/dev/kvm`, KVM API version 12, `KVM_CREATE_VM`,
and `/dev/net/tun` with `TUNSETIFF`, then boot a guest with `qemu-system-x86_64
-accel kvm`. The QEMU user needs read/write access to `/dev/kvm`; TAP setup
needs `CAP_NET_ADMIN`. Grant access only to the intended user, not world-wide.
QEMU's user-mode networking does not require TAP.

## Validation boundaries

Before rollout, check normal cold boot, envd commands, virtio networking and
vsock, file I/O, container networking, and ordinary capture/restore with no
inner VM running. Then test KVM/TUN and a real QEMU guest boot separately.
An enabled config or a successful `KVM_CREATE_VM` is not an OSWorld smoke.

Only the Intel x86_64 KVM path is targeted; AMD, ARM, and PVM are not covered.
Capturing, pausing, or restoring an AENV sandbox while an inner KVM VM is live
is not supported by this change. Shut down QEMU before those operations and
use a cold boot when changing kernels; do not reuse snapshots from another
kernel. Full OSWorld desktop/task validation is a separate integration step.
