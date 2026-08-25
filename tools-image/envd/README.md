# AgentENV envd

`envd` is the guest daemon that implements the E2B-compatible process,
filesystem, and initialization APIs inside an AgentENV sandbox. AgentENV keeps
this source in-tree so guest behavior and the tools drive can be changed and
released atomically.

This directory was initially imported from E2B. See [UPSTREAM.md](UPSTREAM.md)
for the exact tag, commit, copied dependency closure, module-path decision, and
license provenance.

## Development

Build a static Linux binary (defaults to `amd64`):

```bash
make build
make build BUILD_ARCH=arm64
```

Run the envd and imported shared-package test suites:

```bash
make test
make fmt-check
make vet
```

The binary is written to `bin/envd`. The parent tools drive build compiles this
same source directly; see `../README.md`.

### Versioning

The envd version in `pkg/version.go` must be bumped on every change that affects
the compiled binary, including behavior and dependency changes. Pure
documentation changes do not require a version bump.

### AgentENV process policy

By default, the imported envd behavior remains compatible with E2B. AgentENV's
guest bootstrap starts envd with:

```bash
/agentenv/envd -disable-bash-login-shell
```

With that opt-in flag, only the exact SDK wrapper shape
`/bin/bash -l -c <command>` is normalized to `/bin/bash -c <command>`. Other
commands and explicit shell forms are unchanged. This preserves OCI `PATH`
values that a guest `/etc/profile` would otherwise replace for login shells,
without changing the E2B SDK API.

### Generating API server stubs

After changing the API specs in `./spec/` run the following command to generate the server stubs:

```bash
make generate
```

Generated files remain machine-managed; do not edit them by hand.
