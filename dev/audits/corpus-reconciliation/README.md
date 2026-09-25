# Corpus findings reconciled, 2026-09-24

This review starts at `aa58c7b` on `fix/reconcile-corpus-findings` and compares the
older broad audit with current behavior on the same local schema bytes. The
2026-09-22 proving-ground report covers a different, smaller corpus; its resolved
issues do not establish that every broad-corpus fixture failure was fixed.

All 62 top-level inputs from `dev/audits/current-corpus` retain their recorded
SHA-256 hashes. All 2,924 files in the additional-input manifest, including local
reference targets, match their archived hashes. The available EPA manifest now
contains 15 documents, so its 13 additional documents are reported separately
from the original two-document EPA baseline. No schemas were changed, no
production requests were made, and no new fixture overrides were applied. The
existing CHET operation-name override was retained.

## Fixes

- Scalar fixture selection repeated an unguarded `schema$example` lookup after
  choosing declared evidence. R partially matched `examples`, treating the whole
  annotation array as a scalar. Removing the redundant lookup restores the
  documented singular-example/default/enum/type precedence. The 54 affected
  GitHub 3.1 operations now produce fixtures that their rendered wrappers accept.
  Plural collections remain annotations; a caller can select a member through
  an explicit override. Invalid singular examples still fail.
- Fixture generation now rejects an empty query value when `allowEmptyValue`
  is false, matching wrapper validation. It reports the operation, parameter,
  optionality and source location at fixture time. It neither replaces an
  explicit example nor removes a declared default. A regression verifies that
  minimal omission can activate an invalid default, while explicit optional
  `NULL` omits the value. The historical DigitalOcean certificates operation
  already passes before this change because #38 preserved its valid
  parameter-level example, `certificate-name`, ahead of its empty default.

## Current ledger

| Input set | Parsed/rendered | Before default passes | Final default passes | Final fixture failures | Parser blockers |
| --- | ---: | ---: | ---: | ---: | ---: |
| Canonical, 27 documents | 495 | 470 | 470 | 25 | 53 |
| EPA, 15 documents | 438 | 432 | 432 | 6 | 0 |
| Additional, 33 documents | 4,134 | 4,009 | 4,063 | 71 | 1,215 |

There are no default invocation failures in either current run. The additional
ledger has 131 findings: 54 fixed here, six already fixed before this review,
61 synthesis limits, nine invalid selected examples/defaults, and one unsupported
form contract. The historical 122 fixture failures and one invocation failure
are all accounted for; later validation exposed eight additional failures.

Minimal mode is recorded only for ledger operations. In the additional ledger
it passes 83 of 131, fails 47 during fixtures, and fails one invocation:
DigitalOcean certificates omits optional `name`, activating its empty default.
This is the documented minimal-mode/default limitation, not a default-mode
regression. Callers can explicitly pass `name = NULL` to omit that query value;
no automatic omission or schema-default rewrite was added.

The per-operation ledgers record historical, pre-fix and current outcomes,
source hashes, dispositions, supporting evidence, and separate minimal-mode
results. A default pass means fixture construction and a recording-helper
invocation succeeded. It is not evidence of a live service contract.

- [Canonical findings](base/findings.csv): the 25 incompatible selected examples
  already explained in the [later fixture review](../open-issues-20260922/FIXTURE-FINDINGS.md).
- [EPA findings](epa/findings.csv): six numeric-type/string-enum contradictions,
  including the four originally reported ECHO failures. Optional omission remains
  distinct from default fixture coverage.
- [Additional findings](additional/findings.csv): every historical fixture or
  invocation failure, plus failures exposed by later selected-example validation.
- [Parser blockers](parser-blockers.csv): operation-specific schema defects,
  unsupported capabilities and contract-review requirements, kept separate from
  fixtures. These dispositions are unchanged by this patch.
- [Document failures](document-failures.csv): unsupported OpenAPI 3.2, a
  webhook-only document and four JSON Schema test-suite arrays.

Synthesis limits do not mean the operation is unsupported. Automatic fixture
construction uses a finite candidate set; it does not solve regexes, infer
undeclared types, or search arbitrary composition intersections. The ledger
identifies these failures separately from incompatible selected examples.
The Box revoke form requires `grant_type` without declaring its type; Specmill
cannot choose a form encoding for that undeclared field. The AMOS missing media,
binary/nested-query contracts and resolver GET-body review remain blocked under
#26–#29 and #31; no new encoding is inferred from their counts.

## Verification and reproduction

All 54 standalone acceptance scripts pass. The first sweep found one stale
HTTP-method test expecting only the route export; session-control generation
now also exports the package-prefixed dry-run and verbose functions. Its exact
expectation was corrected and that full localhost test rerun successfully.
The fixture regression covers singular/plural evidence, invalid selected values,
empty-query policy and default activation. Source-diff whitespace checks pass.

The package was rebuilt with all seven vignettes and passed
`R CMD check --no-manual --no-vignettes --no-tests` with zero errors, warnings
or notes; tests ran separately above. The source archive now excludes the
repository-only `.gitleaksignore` file, which caused a package-check NOTE.
See [test outcomes](test-results.csv) and [package check](package-check.log).

The input run remains under `artifacts/corpus-2026-09-21`. The pre-fix and final
runs, isolated installed toolkits, test logs and package check are under
`artifacts/corpus-reconciliation`. `input-verification.json` records the complete
additional manifest hash check. The committed CSV ledgers contain the per-input
hashes needed to match a future run.

Install the source into an isolated library and run the existing audit against
the frozen roots, saving results to a fresh directory. For example:

```sh
mkdir -p artifacts/reconciliation-library
R CMD INSTALL --library=artifacts/reconciliation-library .
R_LIBS=artifacts/reconciliation-library Rscript - <<'RS'
source('dev/audit_testing_specs.R')
source('dev/reconcile_corpus_findings.R')
roots <- c(base = 'specmill-testing/schema',
           epa = 'specmill-testing/additional-schemas/epa',
           additional = 'additional-schemas')
policies <- list('chet.json' = list(names = list(
  'OPTIONS /reaction/batchsearch' = 'default_api_reaction_batchsearch_options'
)))
for (group in names(roots)) {
  inputs <- file.path('artifacts/corpus-2026-09-21', roots[[group]])
  output <- file.path('artifacts/reconciliation-repeat', group)
  audit_testing_specs(native_root = inputs, output = output, policies = policies)
  reconcile_corpus_findings(
    before = file.path('artifacts/corpus-reconciliation', group),
    after = output, schema_root = inputs,
    historical = file.path('dev/audits/current-corpus', group),
    output = file.path(output, 'ledger'), policies = policies
  )
}
RS
```

The reconciliation checks hash identity and reruns each ledger operation in both
fixture modes. Keep the historical and pre-fix audit directories when repeating
the comparison. For a different corpus, supply its own matching historical
results; do not compare aggregate counts across changed schemas.
