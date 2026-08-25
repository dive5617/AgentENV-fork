#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dockerfile="$repo_root/tools-image/Dockerfile"
post_pivot_init="$repo_root/tools-image/pivot-init"
tools_makefile="$repo_root/tools-image/Makefile"
publish_workflow="$repo_root/.github/workflows/publish-tools-image.yml"

fail() {
  echo "envd tools-image contract failed: $*" >&2
  exit 1
}

grep -Fxq '# syntax=docker/dockerfile:1.7' "$dockerfile" \
  || fail "tools drive must use the public Dockerfile frontend"
if grep -Eq 'daocloud|mirrors[.]aliyun|goproxy[.]cn|xaminim[.]com' "$dockerfile" "$tools_makefile" "$publish_workflow"; then
  fail "tools drive must not depend on an internal or regional mirror"
fi

for local_source in Dockerfile init pivot-init; do
  grep -Fxq "!${local_source}" "$repo_root/tools-image/.dockerignore" \
    || fail "tools drive build context excludes required local source ${local_source}"
done
grep -Fq '!envd/**' "$repo_root/tools-image/.dockerignore" \
  || fail "tools-image Docker context must include the in-tree envd source"

[[ -f "$repo_root/tools-image/envd/go.mod" ]] \
  || fail "tools-image/envd must own the repository-maintained envd source"
[[ ! -e "$repo_root/envd" ]] \
  || fail "the migrated envd source must not remain at the repository root"
grep -Fq 'ARG ENVD_COMMIT=unknown' "$dockerfile" \
  || fail "tools drive build must accept the AgentENV source revision"
grep -Fq 'COPY envd/go.mod envd/go.sum ./' "$dockerfile" \
  || fail "tools drive build must cache dependencies from the in-tree envd source"
grep -Fq 'COPY envd/ ./' "$dockerfile" \
  || fail "tools drive build must compile the in-tree envd source"
if grep -Fq 'git fetch --depth 1 origin "$ENVD_REF"' "$dockerfile"; then
  fail "tools drive build must not fetch envd source from a remote ref"
fi
if grep -Fq 'ENVD_REF' "$tools_makefile" || grep -Fq 'envd_ref:' "$publish_workflow"; then
  fail "tools drive entrypoints must not expose the removed remote envd ref"
fi

grep -Fq 'exec /agentenv/envd -disable-bash-login-shell' "$post_pivot_init" \
  || fail "AgentENV envd must preserve OCI runtime environment values"
grep -Fq 'ENVD_COMMIT=$(ENVD_COMMIT)' "$tools_makefile" \
  || fail "local tools drive builds must record the AgentENV source commit"
grep -Fq 'ENVD_COMMIT=${{ github.sha }}' "$publish_workflow" \
  || fail "published tools drives must record the checked-out AgentENV commit"
grep -Fq 'context: tools-image' "$publish_workflow" \
  || fail "published tools drives must use the self-contained tools-image context"

echo "envd tools-image contract passed"
