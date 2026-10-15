#!/usr/bin/env bash
set -euo pipefail

recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
config=${1:?Usage: verify-config.sh CONFIG}

while IFS= read -r setting; do
    if [[ "$setting" == *=n ]]; then
        if grep -Eq "^${setting%=n}=(y|m)$" "$config"; then
            printf 'Unexpected enabled kernel setting: %s\n' "${setting%=n}" >&2
            exit 1
        fi
        continue
    fi
    if ! grep -Fxq "$setting" "$config"; then
        printf 'Missing kernel setting: %s\n' "$setting" >&2
        exit 1
    fi
done < "$recipe_dir/nested-qemu.config"

printf 'Nested QEMU kernel configuration passed\n'
