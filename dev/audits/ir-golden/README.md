# OpenAPI importer golden baseline

Phase 0 of [#229](https://github.com/seanthimons/specmill/issues/229). The
reference package source is commit `20be658` (the #228 IR contract on top of
`83969c3`). No importer or generation behavior has changed in this phase.

`manifest.csv` records 411 SHA-256 hashes across seven fixture variants:
all four API documents shipped under `inst/`, a synthetic Swagger 2 YAML
fixture, its JSON equivalent, and a YAML equivalent of the catalogue fixture.
Origin metadata, validation metaschemas and IR examples are not API documents.
The harness checks coverage of shipped documents and verifies that conversion
preserves both equivalent documents, including booleans and singleton arrays.

The baseline includes operation records, unsupported-operation and transport
metadata, validation reports, schema/operation comparisons, unfiltered generation
diagnostics and inventory, and generated client files. Client files include
wrappers, help, exports, configuration, helpers, schemas and ownership metadata.
Each fixture uses a fresh client; generation sends no HTTP requests. No request
contracts are configured, so this baseline does not certify generated contract
tests. A separate referenced-contract provenance baseline protects the raw
reference digests retained for [#279](https://github.com/seanthimons/specmill/issues/279).

## Reproduce

Run from an interactive R session at the repository root:

```r
source('dev/golden_output.R')
changes <- golden_compare(keep = 'artifacts/golden-current')
stopifnot(nrow(changes) == 0L)

source('dev/check_golden_output.R')
check_golden_output()
```

`pkgload::load_all()` loads this checkout, so an older installed package cannot
silently supply the reference behavior. The check takes two fresh snapshots,
compares them with the baseline and each other, then verifies changed, removed,
added and duplicate artifact detection. Full normalized artifacts can be kept
with `golden_snapshot(keep = 'artifacts/golden-current')` for inspection. Use a
fresh output directory, since retained artifacts are not automatically cleaned.
`golden_compare()` returns differing keys and expected/actual hashes; callers
must assert that the result is empty when using it as a failing gate.

Only regenerate the baseline on an explicitly reviewed reference revision:

```r
source('dev/golden_output.R')
golden_write_baseline()
```

Baseline environment: Linux, R 4.6.1, jsonlite 2.0.0, yaml12 0.2.0,
roxygen2 8.1.0, jsonvalidate 1.5.0 and pkgload 1.5.3. Differences after dependency
updates need inspection before accepting a new baseline.

## Existing blockers

Raw parsing and generation plans are captured without filtering. Applying the
client configuration uses these exact exclusions; newly failing operations
cause generation to fail instead of silently shrinking the generated client:

- Classifier: `POST /v1/sandbox/classify`, `POST /v1/classify`,
  `POST /v1/classify/batch`, and `POST /` use unsupported `propertyNames`.
- Natural products: `GET /chem/tanimoto` has string defaults for integer query
  parameters `nBits` and `radius`; `GET /depict/2D_enhanced` has an empty query
  default for `arrow` that the transport rejects.

Generation uses `validation = FALSE` so source-validation failures do not prevent
capturing the generator's existing behavior. Separate, unfiltered validation
reports are still part of the manifest. These exclusions are harness policy,
not changes to the shipped schemas or automatic fixes for their contracts.

## Normalization

Client text is hashed as bytes, preserving whitespace, line endings and final
newlines. Temporary roots and fixture source paths become stable placeholders.
Only the manifest's toolkit version, the LICENSE copyright year and its derived
ownership/input hashes, and the validation report's validator version are
masked. Source hashes and schema values remain covered. Binary files are hashed
through a lossless hexadecimal representation. The manifest holds hashes only;
keep full artifacts to inspect a mismatch.

The harness is development tooling under `dev/`, excluded from package builds.
It complements the full package check required for the later importer refactor.

## Referenced-contract provenance

`provenance.csv` freezes 102 operation reference digests from commit `182b34b`,
before the native reference accessors moved into the importer. It covers the
same seven fixtures, including unsupported operations. Do not regenerate it
after a reader migration merely to accept a mismatch.

```r
source('dev/check_ir_provenance.R')
check_ir_provenance()
```

This protects the referenced-schema portion of cassette provenance. The ordinary
package tests continue to cover recorded request and response review.
