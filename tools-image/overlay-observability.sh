#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 4 ]]; then
  echo "usage: $0 BASE_TOOLS_EXT4 ARTIFACT_DIR OUTPUT_EXT4 TOOLS_VERSION" >&2
  exit 2
fi

base=$1
artifacts=$2
output=$3
tools_version=$4
mount_dir="${output}.mnt"
marker_staging="$mount_dir/agentenv/.tools-drive-version.tmp.$$"

semver_re='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(\.(0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?$'
[[ "$tools_version" =~ $semver_re ]] || {
  echo "invalid tools version: $tools_version" >&2
  exit 2
}

[[ -f "$base" ]] || { echo "base tools drive is missing" >&2; exit 1; }
for file in cube-observerd agentsight-process agentsight-process.bin LICENSE.agentsight agentsight.version; do
  [[ -f "${artifacts}/${file}" ]] || { echo "missing artifact: ${file}" >&2; exit 1; }
done
[[ -x "${artifacts}/agentsight-runtime/ld.so" ]] \
  || { echo "missing executable artifact: agentsight-runtime/ld.so" >&2; exit 1; }
[[ -n "$(find "${artifacts}/agentsight-runtime/lib" -type f -print -quit)" ]] \
  || { echo "missing AgentSight shared-library closure" >&2; exit 1; }

cp "$base" "$output"
truncate -s 64M "$output"
sudo e2fsck -fy "$output" >/dev/null
sudo resize2fs "$output" >/dev/null
mkdir -p "$mount_dir"
sudo mount -o loop "$output" "$mount_dir"
cleanup() {
  if mountpoint -q "$mount_dir"; then
    sudo rm -f "$marker_staging"
    sudo umount "$mount_dir"
  fi
}
trap cleanup EXIT

marker_path="$mount_dir/agentenv/tools-drive-version"
sudo test -f "$marker_path" && ! sudo test -L "$marker_path" \
  || { echo "base tools drive version marker is not a regular file" >&2; exit 1; }
base_tools_version="$(sudo cat "$marker_path")"
[[ "$base_tools_version" != "$tools_version" ]] \
  || { echo "output tools version must differ from the base tools version" >&2; exit 1; }
envd_help="$(sudo "$mount_dir/agentenv/envd" -h 2>&1 || true)"
[[ "$envd_help" == *'-disable-bash-login-shell'* ]] \
  || { echo "base envd does not support -disable-bash-login-shell" >&2; exit 1; }

sudo install -o root -g root -m 0755 tools-image/init "$mount_dir/init"
sudo install -o root -g root -m 0755 tools-image/pivot-init "$mount_dir/agentenv/pivot-init"
sudo install -o root -g root -m 0755 tools-image/prepare-ca-bundle "$mount_dir/agentenv/prepare-ca-bundle"
sudo install -o root -g root -m 0755 "$artifacts/cube-observerd" "$mount_dir/agentenv/cube-observerd"
sudo install -o root -g root -m 0755 "$artifacts/agentsight-process" "$mount_dir/agentenv/agentsight-process"
sudo install -o root -g root -m 0755 "$artifacts/agentsight-process.bin" "$mount_dir/agentenv/agentsight-process.bin"
sudo install -d -o root -g root -m 0755 "$mount_dir/agentenv/agentsight-runtime/lib"
sudo install -o root -g root -m 0755 "$artifacts/agentsight-runtime/ld.so" "$mount_dir/agentenv/agentsight-runtime/ld.so"
while IFS= read -r library; do
  sudo install -o root -g root -m 0644 "$library" "$mount_dir/agentenv/agentsight-runtime/lib/$(basename "$library")"
done < <(find "$artifacts/agentsight-runtime/lib" -maxdepth 1 -type f | LC_ALL=C sort)
sudo install -o root -g root -m 0644 "$artifacts/LICENSE.agentsight" "$mount_dir/agentenv/LICENSE.agentsight"
sudo install -o root -g root -m 0644 "$artifacts/agentsight.version" "$mount_dir/agentenv/agentsight.version"
printf '%s\n' "$tools_version" | sudo tee "$marker_staging" >/dev/null
sudo chown root:root "$marker_staging"
sudo chmod 0644 "$marker_staging"
sudo mv -f "$marker_staging" "$mount_dir/agentenv/tools-drive-version"
installed_tools_version="$(sudo cat "$mount_dir/agentenv/tools-drive-version")"
[[ "$installed_tools_version" == "$tools_version" ]] \
  || { echo "installed tools version marker does not match requested version" >&2; exit 1; }
sync

sudo stat -c '%U:%G %a %s %n' \
  "$mount_dir/init" \
  "$mount_dir/agentenv/pivot-init" \
  "$mount_dir/agentenv/prepare-ca-bundle" \
  "$mount_dir/agentenv/cube-observerd" \
  "$mount_dir/agentenv/agentsight-process" \
  "$mount_dir/agentenv/agentsight-process.bin" \
  "$mount_dir/agentenv/agentsight-runtime/ld.so" \
  "$mount_dir/agentenv/LICENSE.agentsight" \
  "$mount_dir/agentenv/agentsight.version" \
  "$mount_dir/agentenv/tools-drive-version" \
  "$mount_dir/agentenv/envd"
sudo file \
  "$mount_dir/agentenv/envd" \
  "$mount_dir/agentenv/cube-observerd" \
  "$mount_dir/agentenv/agentsight-process"
sudo find "$mount_dir/agentenv/agentsight-runtime" -type f -exec stat -c '%U:%G %a %s %n' {} +
sudo sha256sum \
  "$mount_dir/init" \
  "$mount_dir/agentenv/pivot-init" \
  "$mount_dir/agentenv/prepare-ca-bundle" \
  "$mount_dir/agentenv/cube-observerd" \
  "$mount_dir/agentenv/agentsight-process" \
  "$mount_dir/agentenv/agentsight-process.bin" \
  "$mount_dir/agentenv/agentsight-runtime/ld.so" \
  "$mount_dir/agentenv/LICENSE.agentsight" \
  "$mount_dir/agentenv/agentsight.version" \
  "$mount_dir/agentenv/tools-drive-version" \
  "$mount_dir/agentenv/envd"
sudo find "$mount_dir/agentenv/agentsight-runtime/lib" -type f -exec sha256sum {} +
sudo "$mount_dir/agentenv/envd" -version
sudo "$mount_dir/agentenv/envd" -commit

if sudo find "$mount_dir/agentenv" -type f \
    \( -iname '*.key' -o -iname '*.pem' -o -iname '*.p12' -o -iname '*.pfx' \
       -o -iname '*.env' -o -iname '*credential*' -o -iname '*secret*' \) \
    -print -quit | grep -q .; then
  echo "forbidden credential-like path in tools drive" >&2
  exit 1
fi

cleanup
trap - EXIT
sudo e2fsck -fn "$output"
sha256sum "$output"
