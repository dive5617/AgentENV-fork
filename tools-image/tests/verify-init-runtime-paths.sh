#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
pre_pivot_init="$repo_root/tools-image/init"
post_pivot_init="$repo_root/tools-image/pivot-init"
overlay_script="$repo_root/tools-image/overlay-observability.sh"
tools_makefile="$repo_root/tools-image/Makefile"
publish_workflow="$repo_root/.github/workflows/publish-tools-image.yml"

fail() {
  echo "init runtime-path contract failed: $*" >&2
  exit 1
}

grep -Fxq '# syntax=docker.m.daocloud.io/docker/dockerfile:1.7' "$repo_root/tools-image/Dockerfile" \
  || fail "tools drive build must use the reviewed reachable Dockerfile frontend"
grep -Fq 'ARG DOCKER_LIBRARY_REGISTRY=docker.m.daocloud.io/library' "$repo_root/tools-image/Dockerfile" \
  || fail "tools drive build must default Docker Official Images to the reviewed mirror"
grep -Fq -- '--build-arg "DOCKER_LIBRARY_REGISTRY=$(DOCKER_LIBRARY_REGISTRY)"' "$repo_root/tools-image/Makefile" \
  || fail "tools drive Make targets must pass the Docker Official Images registry"
grep -Fq -- '--build-arg "APT_MIRROR_BASE=$(APT_MIRROR_BASE)"' "$repo_root/tools-image/Makefile" \
  || fail "tools drive Make targets must pass the reviewed Debian package mirror"
grep -Fq -- '--build-arg "GOPROXY=$(GOPROXY)"' "$repo_root/tools-image/Makefile" \
  || fail "tools drive Make targets must pass the reviewed Go module proxy"
grep -Fq 'GOPROXY="$GOPROXY"' "$repo_root/tools-image/Dockerfile" \
  || fail "envd compilation must use the reviewed Go module proxy"
[[ "$(grep -Fc 'ARG APT_MIRROR_BASE' "$repo_root/tools-image/Dockerfile")" -eq 3 ]] \
  || fail "tools drive Debian stages must both receive the package mirror"
for local_source in Dockerfile init pivot-init prepare-ca-bundle; do
  grep -Fxq "!${local_source}" "$repo_root/tools-image/.dockerignore" \
    || fail "tools drive build context excludes required local source ${local_source}"
done

# Distro root filesystems commonly provide /var/run as an absolute symlink to
# /run. Before pivot_root, following /mnt/user/var/run would therefore escape
# the mounted user root and resolve against the tools drive. Runtime paths must
# only be prepared after the user root becomes '/'.
if grep -Eq '/mnt/user/(run|var/run)([[:space:]\\]|$)' "$pre_pivot_init"; then
  fail "pre-pivot init must not create /run or /var/run through the mounted user root"
fi

run_create_line="$(grep -nF '$BB mkdir -p /run' "$post_pivot_init" | head -n1 | cut -d: -f1)"
run_mount_line="$(grep -nF '$BB mount -n -t tmpfs -o mode=0755,nosuid,nodev tmpfs /run' "$post_pivot_init" | head -n1 | cut -d: -f1)"
var_run_line="$(grep -nF '$BB mkdir -p /var/run ' "$post_pivot_init" | head -n1 | cut -d: -f1)"

[[ -n "$run_create_line" ]] || fail "post-pivot init must create /run"
[[ -n "$run_mount_line" ]] || fail "post-pivot init must mount /run"
[[ -n "$var_run_line" ]] || fail "post-pivot init must prepare /var/run"
(( run_create_line < run_mount_line )) || fail "/run must exist before it is mounted"
(( run_mount_line < var_run_line )) || fail "/var/run must be prepared after /run is mounted"
grep -Fq 'mount -n -t tracefs' "$post_pivot_init" \
  || fail "post-pivot init must mount tracefs for AgentSight"
grep -Fq 'mount -n -t bpf' "$post_pivot_init" \
  || fail "post-pivot init must mount bpffs for AgentSight"
grep -Eq '/run/sv/cube-observer/log[[:space:]]+/run/cube([[:space:]\\]|$)' "$post_pivot_init" \
  || fail "post-pivot init must create the cube-observer bootstrap output directory"
ca_prepare_line="$(grep -nF '/agentenv/prepare-ca-bundle /' "$post_pivot_init" | head -n1 | cut -d: -f1)"
envd_start_line="$(grep -nF '/agentenv/bin/busybox runsv /run/sv/envd' "$post_pivot_init" | head -n1 | cut -d: -f1)"
[[ -n "$ca_prepare_line" && -n "$envd_start_line" ]] \
  || fail "post-pivot init must prepare the Guest CA destination before envd"
(( ca_prepare_line < envd_start_line )) \
  || fail "Guest CA destination must be prepared before envd starts"
grep -Fq 'exec /agentenv/envd -disable-bash-login-shell' "$post_pivot_init" \
  || fail "AgentENV envd must disable the E2B SDK login-shell wrapper"
[[ -f "$repo_root/tools-image/envd/go.mod" ]] \
  || fail "tools-image/envd must own the repository-maintained envd source"
[[ ! -e "$repo_root/envd" ]] \
  || fail "the migrated envd source must not remain at the repository root"
grep -Fq 'COPY envd/go.mod envd/go.sum ./' "$repo_root/tools-image/Dockerfile" \
  || fail "tools drive build must cache dependencies from the repository-owned envd source"
grep -Fq 'COPY envd/ ./' "$repo_root/tools-image/Dockerfile" \
  || fail "tools drive build must compile the repository-owned envd source"
grep -Fq '"$(REPO_ROOT)"' "$tools_makefile" \
  && fail "tools drive build context must remain scoped to tools-image"
grep -Fq 'context: tools-image' "$publish_workflow" \
  || fail "published tools drives must use the self-contained tools-image context"
grep -Fq '!envd/**' "$repo_root/tools-image/.dockerignore" \
  || fail "tools-image Docker context must include the in-tree envd source"
grep -Fq '!prepare-ca-bundle' "$repo_root/tools-image/.dockerignore" \
  || fail "tools-image Docker context must include the CA bootstrap helper"
if grep -Fq 'git fetch --depth 1 origin "$ENVD_REF"' "$repo_root/tools-image/Dockerfile"; then
  fail "tools drive build must not fetch envd source from a remote ref"
fi
if grep -Fq 'ENVD_REF' "$tools_makefile" || grep -Fq 'envd_ref:' "$publish_workflow"; then
  fail "tools drive entrypoints must not expose the removed remote envd ref"
fi
grep -Fq 'ENVD_COMMIT=$(ENVD_COMMIT)' "$tools_makefile" \
  || fail "local tools drive builds must record the AgentENV source commit"
grep -Fq 'ENVD_COMMIT=${{ github.sha }}' "$publish_workflow" \
  || fail "published tools drives must record the checked-out AgentENV commit"
grep -Fq 'base envd does not support -disable-bash-login-shell' "$overlay_script" \
  || fail "observer tools overlay must reject an incompatible base envd"

# The minimal-init workaround deliberately prefers the container image shell
# over distro init systems so Guest boot does not continue with asynchronous
# systemd units after envd becomes ready.
init_candidate_line="$(grep -F 'for candidate in ' "$post_pivot_init" | head -n1)"
[[ "$init_candidate_line" == 'for candidate in /bin/sh /init /sbin/init /bin/init; do' ]] \
  || fail "post-pivot init must prefer /bin/sh before distro init programs"

# The target deployment derives its observer-enabled tools drive by overlaying
# binaries onto an existing ext4. That public artifact path must replace PID 1
# as well as pivot-init, otherwise rebuilding the observer drive retains the
# broken pre-pivot init from the base artifact.
grep -Fq 'tools-image/init "$mount_dir/init"' "$overlay_script" \
  || fail "observer tools overlay must install the current pre-pivot init"
init_artifact_mentions="$(grep -Fc '"$mount_dir/init"' "$overlay_script")"
(( init_artifact_mentions >= 3 )) \
  || fail "observer tools overlay must stat and hash the installed pre-pivot init"
grep -Fq 'tools-image/prepare-ca-bundle "$mount_dir/agentenv/prepare-ca-bundle"' "$overlay_script" \
  || fail "observer tools overlay must install the Guest CA bootstrap helper"
ca_helper_mentions="$(grep -Fc '"$mount_dir/agentenv/prepare-ca-bundle"' "$overlay_script")"
(( ca_helper_mentions >= 3 )) \
  || fail "observer tools overlay must stat and hash the Guest CA bootstrap helper"
grep -Fq 'agentsight-runtime' "$overlay_script" \
  || fail "observer tools overlay must install the self-contained AgentSight runtime"
grep -Fq 'COPY --from=observability-artifacts /agentsight-runtime /tools-rootfs/agentenv/agentsight-runtime' "$repo_root/tools-image/Dockerfile" \
  || fail "tools drive build must include the self-contained AgentSight runtime"
grep -Fq -- '--build-arg "OBSERVABILITY_ARTIFACT_IMAGE=$(OBSERVABILITY_ARTIFACT_IMAGE)"' "$repo_root/tools-image/Makefile" \
  || fail "tools drive Make targets must pass the Guest observability artifact image"

overlay_usage="$(bash "$overlay_script" missing-base missing-artifacts missing-output 2>&1 || true)"
[[ "$overlay_usage" == *'BASE_TOOLS_EXT4 ARTIFACT_DIR OUTPUT_EXT4 TOOLS_VERSION'* ]] \
  || fail "observer tools overlay must require an explicit output tools version"
grep -Fq 'invalid tools version:' "$overlay_script" \
  || fail "observer tools overlay must reject a non-SemVer output version"
if invalid_version_output="$(bash "$overlay_script" missing-base missing-artifacts missing-output '0.1.0+mutable' 2>&1)"; then
  fail "observer tools overlay accepted a version with forbidden build metadata"
fi
[[ "$invalid_version_output" == *'invalid tools version: 0.1.0+mutable'* ]] \
  || fail "observer tools overlay did not reject the invalid version before filesystem work"
grep -Fq '"$marker_staging" "$mount_dir/agentenv/tools-drive-version"' "$overlay_script" \
  || fail "observer tools overlay must atomically replace the internal version marker"
grep -Fq '[[ "$installed_tools_version" == "$tools_version" ]]' "$overlay_script" \
  || fail "observer tools overlay must verify the mounted version marker exactly"

echo "init runtime-path contract passed"
