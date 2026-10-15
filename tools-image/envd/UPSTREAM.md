# envd upstream provenance

AgentENV maintains this copy of `envd` in-tree so guest runtime behavior and
the tools drive can evolve atomically in one repository.

The initial source was imported from:

- Repository: <https://github.com/e2b-dev/infra>
- Tag: `2026.17`
- Commit: `9c3b7c5dbd181ba819084276b8228f70936e911e`
- Imported component: `packages/envd`

The minimal source closure needed from `packages/shared` is kept under
`tools-image/envd/shared`: `filesystem`, `id`, `keys`, `smap`, and the pointer
helper used by tests. The original Go module paths are intentionally retained
to avoid rewriting generated protobuf metadata and internal imports during the
initial migration.

The imported source remains available under the Apache License 2.0 in
`tools-image/envd/LICENSE`. Subsequent AgentENV-specific changes are maintained
in this repository and must preserve the upstream license and this provenance
record.
