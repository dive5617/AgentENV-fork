#!/usr/bin/env bash
set -euo pipefail

recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT

sed 's/^\(CONFIG_[A-Z0-9_]*\)=n$/# \1 is not set/' \
    "$recipe_dir/nested-qemu.config" > "$test_dir/config"
bash "$recipe_dir/verify-config.sh" "$test_dir/config"

for symbol in KVM KVM_INTEL TUN X86_MPPARSE VIRTIO_MMIO_CMDLINE_DEVICES VIRTIO_BLK VIRTIO_NET VIRTIO_VSOCKETS EXT4_FS NFT_NAT; do
    sed "/^CONFIG_${symbol}=y$/d" "$test_dir/config" > "$test_dir/invalid"
    if bash "$recipe_dir/verify-config.sh" "$test_dir/invalid" > "$test_dir/result" 2>&1; then
        printf 'Verifier accepted missing CONFIG_%s\n' "$symbol" >&2
        exit 1
    fi
    grep -Fq "CONFIG_${symbol}=y" "$test_dir/result"
done

cp "$test_dir/config" "$test_dir/invalid"
printf 'CONFIG_DEBUG_INFO_BTF=y\n' >> "$test_dir/invalid"
if bash "$recipe_dir/verify-config.sh" "$test_dir/invalid" > "$test_dir/result" 2>&1; then
    echo 'Verifier accepted enabled CONFIG_DEBUG_INFO_BTF' >&2
    exit 1
fi
grep -Fq 'CONFIG_DEBUG_INFO_BTF' "$test_dir/result"

printf 'Kernel configuration regression tests passed\n'
