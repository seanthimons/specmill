# Finite recursive request bodies, issue #30

Audited 2026-09-21. The Standardizer schema in the working transfer ZIP matches
`d800dc2` byte for byte, SHA-256
`8c8a37d7d459a6e4d336d6a4f12ca27a8613bc2e3d8f1f5d18129e8a8e0d0916`.

| Operation | Parse/render | Default fixture | Finite parent chain and exact localhost JSON | Invalid nested enum |
|---|---|---|---|---|
| `POST /api/stdizer/protocol/export` | Pass | Pass | Pass | Rejected |
| `POST /api/stdizer/protocols` | Pass | Pass | Pass | Rejected |
| `PUT /api/stdizer/protocols/{id}` | Pass | Pass | Pass | Rejected |
| `POST /api/stdizer/protocols/{id}/export` | Pass | Pass | Pass | Rejected |

Default fixtures omit `ProtocolRecord.parent`. The localhost checks add two
parent levels, compare the received request bytes with the complete expected
JSON, and verify the HTTP method and substituted route. No live service calls
were made. Seven other Standardizer operations retain parameter diagnostics.

The supported slice is a plain local `$ref` back to an ancestor schema from an
optional object property in a JSON body. Required back-edges, reference
siblings, and back-edges through array items or typed maps remain diagnosed.
Parameters and form bodies keep their existing behavior. Unresolved and remote
references remain guarded. This is not full JSON Schema recursion support.

All supplied body content is checked before schema validation, including
unconstrained fields. Limits are 32 levels below the root, 20,000 value nodes,
and 20,000 schema visits. Environments fail explicitly; cyclic lists hit the
depth limit with a possible-cycle error. Values are never truncated.
`tests/nested-bodies.R` covers nested constraints, required recursion, limits,
an environment cycle, reference guards, request direction, and default fixtures.

Reproduce from the repository root:

```sh
R CMD INSTALL .
Rscript tests/nested-bodies.R
Rscript dev/audits/recursive-bodies/check.R
# Or audit an already extracted historical schema:
Rscript dev/audits/recursive-bodies/check.R /path/to/standardizer.json
```

The audit reuses `tests/native-transport.R` and also runs its existing transport
checks, including the 10,000-field JSON object regression.
