# AMOS path-schema diagnostics

Reviewed 2026-09-23 on `dev/amos-path-diagnostics`, based on specmill main
`13b14b8`. Work is isolated in a separate worktree. The original specmill
checkout's uncommitted audit files were left in place. ComptoxR remains clean
on `feat/specmill-migration-pilot` at `6e7b02a3`, following `1444ca5f`.
No merge, schema rewrite, client edit, or production request was performed.

ComptoxR pins specmill `f41eeb9bae628eeb1f0fee16227f5ee8373a7ae2`.
Its path-validation logic matches the starting main implementation. The only
intervening change in `R/operations.R` uses exact security-field lookup.
The migration pin was not changed.

## Existing defenses and entry points

- `read_operations(files, policy)` reads local schemas without writing a client.
  It returns supported operations, structurally usable unsupported operations,
  diagnostics, fixture diagnostics, server diagnostics, and an operation inventory.
  Malformed AMOS path metadata already rejects this route, rather than producing
  a wrapper with guessed inputs. It is not a full OpenAPI conformance validator.
- `configure_client(..., mode = 'plan')` proposes configuration and propagates
  parser findings. `load_project()` validates configuration.
  `generate_client(..., mode = 'plan')` reports selected-route problems and
  previews supported output. Check and apply reject unresolved selected
  operations before applying files. A supported exact-key selection can generate
  independently. Existing ownership and atomic-apply checks remain in force.
- `generation_command()` supplies sourceable command orchestration, check modes,
  and CI summaries. Core APIs return data or errors; an Rscript caller chooses
  the process gate. No separate validator command or framework is needed.
- `schema_diff()` and `compare_operations()` support change review. They do not
  establish handler semantics. `operation_fixtures()` and `check_requests()`
  inspect fixture/request construction; successful construction is not evidence
  of a successful live request.

The configuration and existing-client guides already provide public-input and
request mappings, parameter customization, body-media policy, callbacks, hooks,
and `implementation: existing`. Complete mappings can handle certain capability
gaps with usable metadata. They do not make this malformed route natively
renderable. Retained implementations require an explicit name, full inputs and
request mapping, and matching source formals. They preserve client code rather
than validate the upstream handler.

There is no declarative schema correction/overlay facility in the inspected
configuration. This case supplies no verified replacement contract to apply.
An overlay would not resolve that absence, so none was added. One existing
reporting limit remains: retained-unsupported summaries use inventory records
and therefore show the first finding. Use the raw reader diagnostics for the
complete path-name findings, even when retaining a client implementation.

## Defect and change

Source: `ComptoxR/schema/chemi-amos-prod.json`, SHA-256
`1d0ef1fbd813e2381a1e6e841d69e5070ee438e588a01dc3298b984ba7ca5f35`.
This hash identifies the inspected file; it is distinct from the archived audit
snapshot's hash. Stable key:
`GET /api/amos/get_similar_structures/{identifier_type}/{identifier}`.

The reader previously threw on the first unmatched name before comparing all
missing placeholders. It now collects both name differences and emits one
ordinary diagnostic per contradiction before rejecting the operation:

| Code | Reason | Source location |
| --- | --- | --- |
| `unmatched_path_parameter` | Unmatched path parameter: dtxsid | `#/paths/~1api~1amos~1get_similar_structures~1{identifier_type}~1{identifier}/get/parameters/0` |
| `missing_path_parameter` | Missing path parameter: identifier_type | `#/paths/~1api~1amos~1get_similar_structures~1{identifier_type}~1{identifier}` |
| `missing_path_parameter` | Missing path parameter: identifier | `#/paths/~1api~1amos~1get_similar_structures~1{identifier_type}~1{identifier}` |

Missing declarations have no parameter object to point at; the JSON Pointer
identifies the path item containing the placeholders. All diagnostics retain
`source`, stable `key`, service-qualified `id`, `status = unsupported`, and
`classification = schema_defect`. Codes, message wording, and the first diagnostic
remain compatible. Consumers must allow multiple diagnostics per operation ID;
diagnostic counts are not blocked-route counts. Inventory still contains one
row per operation and summarizes its first diagnostic.

This is a focused improvement to path-name consistency checks, not exhaustive
multi-error validation. Earlier reference, parameter, or body-media errors can
still prevent those checks from running. No schema values or transport behavior
are inferred or repaired.

## Publication gate and verification

The [maintenance guide](../../../vignettes/maintenance.Rmd) includes an
Rscript example: call `read_operations()` on each candidate file, print diagnostics,
and assert that the diagnostics list is empty. Run it before publication, without
client exclusions. Parse errors and assertion failures exit unsuccessfully.
This strict gate also rejects capability gaps; a publisher must distinguish
unsupported features from schema defects rather than calling every finding
invalid OpenAPI. Fixture and origin policy need separate gates when required.

The new offline `tests/path-diagnostics.R` failed before the fix and passes after
it. It covers all three AMOS contradictions, multiple unmatched declarations,
inherited/referenced parameters, operation overrides, OpenAPI 3 parity, a valid
route, read-only mixed planning, check/apply rejection with byte-identical files,
supported-only generation, and rejection after output already exists.

Installed the candidate in `/tmp/specmill-amos-library` and ran these seven
standalone scripts with `R_LIBS=/tmp/specmill-amos-library Rscript tests/<name>.R`:
`path-diagnostics`, `diagnostics`, `parameter-diagnostics`, `mapped-schemas`,
`media-types`, `reconciliation`, and `local-references`. All passed. Reference-page
validation, extraction/parsing of maintenance vignette R code, and
`git diff --check` also passed. A full package check was not run.

An offline comparison against the original main reader on the actual AMOS file
keeps all 45 supported and 32 blocked routes unchanged. Operation records,
inventory, fixture diagnostics, server diagnostics, and unrelated diagnostics
are identical. Parser diagnostics increase from 32 to 34. The documented Rscript
gate exits 1 on AMOS and 0 on `inst/catalogue/schema.json`.

## What still needs upstream confirmation

The snapshot is classified as production. ComptoxR's default Chemi base URL is
`https://hcd.rtpnc.epa.gov/api`, but this Swagger file has no host metadata.
That client default does not supply schema provenance or confirm the route's
handler contract. The user reports that the endpoint is live and suspects the
defect spans instances. Neither claim was tested here.

The existing `chemi_amos_get_similar_structures(identifier_type, identifier = NULL)`
implementation and its example passing a DTXSID as `identifier_type` are unchanged.
The example does not establish accepted identifier-type values or prove the
omitted identifier is supported by the handler. Upstream must confirm the actual
path and required inputs, accepted values and serialization, and publish metadata
consistent with that contract. A verified successful request remains absent.

Ambiguous body media remain blocked. Issues #26/#27/#28/#31 still depend on
upstream contracts, #29 remains unsupported, and OAuth #4 is outside this work.
No fallback request, guessed correction, or new contract was introduced.
