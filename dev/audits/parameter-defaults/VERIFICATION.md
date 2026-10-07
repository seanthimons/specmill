# Effective parameter default checks

The default check runs after service/operation overrides and preparation
callbacks, before emitting native wrappers. Direct `render_operation()` calls
also reject invalid API parameter defaults.

The check uses the same default materialization as emitted R formals and the
same supported schema validator as supplied arguments. Raw containers are
validated before conversion to R vectors, so nested arrays and null elements
cannot disappear through flattening. Native transport checks reuse the encoder
from the shipped request template. Generation never executes a client request
helper or makes an HTTP call to validate a default.

Plan diagnostics distinguish `parameter_default_schema` and
`parameter_default_transport`. Each diagnostic includes operation identity,
parameter and location, effective value, schema/configuration origin, source
location, reason and configuration guidance. Both codes are `review_required`.
An incompatible OpenAPI 3.1 default annotation does not establish a schema
validation failure. Configuration-origin diagnostics identify the parameter
schema and the default setting to edit.

Invalid defaults block apply/check without writing output. Their operations
remain visible in inventory, and existing wrappers are protected from proposed
rename/removal. Valid configuration defaults replace source annotations;
explicit NULL means optional omission. Required arguments, excluded parameters,
client-only inputs, custom renderers and retained implementations keep their
existing contracts. Complete request mappings own transport encoding while
retaining the generated wrapper's schema-value and empty-query checks.

## Checks

`tests/parameter-defaults.R` covers ordinary and nullable scalar defaults,
branch/sibling constraints, enums, bounds, patterns, numeric R representation,
empty queries and arrays, header newlines, whitespace delimiter ambiguity,
nested/null array elements, invalid configuration overrides, explicit NULL,
required and excluded arguments, atomic generation, preservation of existing
wrappers, preparation callback overrides, freshness, and offline requests
using generated defaults.

`tests/schema-stress.R` verifies the unchanged natural-products input:
43 parseable operations, three unconfigured default diagnostics, no writes on
failed apply, successful full generation after explicit configuration fixes,
and seven local HTTP contracts. Tanimoto and enhanced depiction now work with
their corrected defaults without per-call overrides.

The existing mappings, parameter transport, composition transport and nullable
query checks also passed. The existing fixture-evidence regression now checks
that an empty source default blocks rendering and an explicit NULL override
enables omission; its focused rerun passed.

Final verification on 2026-10-07: all 66 package test files passed in
`R CMD check --no-manual --no-stop-on-test-error`, with zero errors,
warnings, or notes. This run includes the final raw-array validation,
wrapper-preservation guard, preparation-callback regression, and updated
fixture-evidence contract. Results are saved in
`/tmp/specmill-defaults-final-check/result.rds`; the full check log is
`/tmp/specmill-defaults-final-check.log`.
