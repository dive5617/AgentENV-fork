#!/usr/bin/env bash
set -euo pipefail

recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$recipe_dir/sources.env"

if [[ "$(uname -s)/$(uname -m)" != Linux/x86_64 ]]; then
    echo 'Build on Linux x86_64, or use the Docker build target.' >&2
    exit 1
fi
if [[ "$(id -u)" == 0 ]]; then
    echo 'Run the kernel build as a non-root user.' >&2
    exit 1
fi
build_jobs=${BUILD_JOBS:-$(nproc)}
if [[ ! "$build_jobs" =~ ^[1-9][0-9]*$ ]]; then
    echo 'BUILD_JOBS must be a positive integer.' >&2
    exit 1
fi

output_dir=${1:-$recipe_dir/out}
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd)
source_cache=${SOURCE_CACHE:-$output_dir/source-cache}
mkdir -p "$source_cache"
work_dir=$(mktemp -d "$output_dir/.build.XXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT

fetch() {
    local name=$1 url=$2 checksum=$3 archive
    archive="$source_cache/$name.tar.gz"
    if [[ ! -f "$archive" ]]; then
        curl --fail --location --retry 3 --connect-timeout 30 \
            "$url" --output "$archive.part"
        mv "$archive.part" "$archive"
    fi
    printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check --status
    mkdir "$work_dir/$name"
    tar -xzf "$archive" --strip-components=1 -C "$work_dir/$name"
}

fetch linux "https://github.com/amazonlinux/linux/archive/$LINUX_COMMIT.tar.gz" "$LINUX_SHA256"
fetch firecracker "https://github.com/kvcache-ai/firecracker/archive/$FIRECRACKER_COMMIT.tar.gz" "$FIRECRACKER_SHA256"

export SOURCE_DATE_EPOCH=1726531200
export KBUILD_BUILD_USER=agentenv
export KBUILD_BUILD_HOST=kernel-builder
export KBUILD_BUILD_TIMESTAMP='Tue Sep 17 00:00:00 UTC 2024'
export KCONFIG_NOTIMESTAMP=1

cd "$work_dir/linux"
config_root="$work_dir/firecracker/resources/guest_configs"
for fragment in microvm-kernel-ci-x86_64-6.1.config ci.config pcie.config virtio-pmem.config virtio-mem.config vmclock.config; do
    cat "$config_root/$fragment" >> .config
done
scripts/kconfig/merge_config.sh -m .config "$recipe_dir/nested-qemu.config"
make olddefconfig
bash "$recipe_dir/verify-config.sh" .config
actual_release=$(make -s kernelrelease)
if [[ "$actual_release" != "$KERNEL_RELEASE" ]]; then
    printf 'Unexpected kernel release: %s\n' "$actual_release" >&2
    exit 1
fi

if [[ "${CONFIG_ONLY:-0}" == 1 ]]; then
    cp .config "$output_dir/resolved.config"
    exit 0
fi

make -j"$build_jobs" vmlinux
objcopy --strip-debug vmlinux "$output_dir/vmlinux.bin"
cp .config "$output_dir/config"
cp "$recipe_dir/sources.env" "$output_dir/sources.env"
printf '%s\n' "$actual_release" > "$output_dir/kernel-release"
(
    cd "$output_dir"
    sha256sum vmlinux.bin config sources.env kernel-release > SHA256SUMS
)
printf 'Kernel artifact: %s/vmlinux.bin\n' "$output_dir"
