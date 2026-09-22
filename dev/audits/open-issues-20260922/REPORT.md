# Open-issue implementation and proving-ground comparison

Branch: `feat/resolve-open-issues`. Starting commit: `84125df`.
The original `main` branch and the previous proving-ground package were retained.
No merge or production service operation was performed.

## Scope and ownership

Live issue bodies and comments were fetched before implementation. #4 was excluded.
The latest #34 hook-ownership decision governed #32 and #40. Hooks own their
transformations and validation; generated checks validate declared public inputs
before hooks. No mandatory post-hook contract or fallback request was introduced.
Closed #29 remains unsupported.

The 25 pre-existing audit/reporting files are listed with starting SHA-256 hashes
in [pre-existing-files.json](pre-existing-files.json). All remained byte-identical.
They were not included in implementation commits. Independent agents owned public
validation/hooks, fixture/parser diagnostics, portability, and contract review;
shared generator changes were coordinated by function/region.

## Verification

All 52 standalone R test scripts pass, including focused reruns after correcting
two synthetic fixtures that supplied values outside their declared enums and
reinstalling the final nullable-enum fix. [Test record](test-results.json).
The toolkit was built with all six vignettes and passed
`R CMD check --no-manual --no-vignettes --no-tests` with zero errors, warnings or
notes. Tests ran separately. [Toolkit check](specmill-check.log).

Two six-operation generated packages, with and without authentication scaffolding,
were built, installed into isolated libraries, checked for generation freshness,
and passed R CMD check with zero errors, warnings or notes. This independently
checks the formerly masked undefined `api_auth` NOTE. Their installed functions
passed eight exact received-wire scenarios, ten invalid-input zero-request checks,
two hook-exception zero-request checks, and skip/post-state checks.
Methods, paths/query, content types and JSON/form bytes were asserted, including
colons, slashes, NBSP, half/degree signs and non-BMP Unicode. Intentional hook
transformations reached the helper and post-response processing preserved state.
[Results](localhost-results.json), [anonymous check](anonymous-client-check.log),
[authenticated check](authenticated-client-check.log).

A separate package retaining a public name longer than 140 characters passed the
portable-filename and non-ASCII source gates. Filenames shorten deterministically;
public names and runtime strings remain intact. All 935 corpus exports also
match the baseline. [Check](portable-client-check.log).

## Corpus comparison

The archived baseline was reproduced using its own installed specmill and frozen
audit script. All 986 operation rows match the recorded baseline, including stage
and reason. The baseline has 42 schemas, 933 wrappers, 925 default fixture/request
passes and eight fixture failures. Its two explicit Envirofacts overrides provide
two additional constructions, for 927 distinct wrappers. Baseline package checking
reported one portable-path ERROR and one non-ASCII source WARNING.

The [machine-readable comparison](comparison-summary.json) and
[986 stable-key rows](operation-comparison.csv) record the before/after results.
[Installed mode outcomes](installed-outcomes.csv) keep all omissions and failures
visible. The after run preserves the same [42 input hashes](schema-hashes.csv) and
[reviewed project/API configuration](configuration-comparison.csv),
CHET naming override and 933-operation test-only allowlist. No schema was repaired
and no unsupported operation was forced through generation. Comparisons use
original schema file plus method/path keys, independently of generated names.

The completed parser/fixture audit has 933 rendered wrappers and 53 parser blockers.
Default successes change from 925 to 902: two Envirofacts gains and 25 newly visible
invalid selected examples. The latter are 24 scalar JSON-media examples against
array schemas and one numeric path example against a string schema. Baseline
parsing discarded those examples and synthesized different values. This is the
agreed #38 visibility change, not 25 newly unsupported operations.
[Individual findings](FIXTURE-FINDINGS.md), [source evidence](fixture-findings.csv).
Six additional default failures remain EPA numeric-type/string-enum contradictions,
with [exact source pointers](source-contradictions.csv).
They concern optional inputs; they do not establish that the whole operation is
uncallable. Default, explicit-override and minimal-input results are kept separate.

| Measure | Baseline | After |
| --- | ---: | ---: |
| Schemas / declared operations | 42 / 986 | 42 / 986 |
| Rendered wrappers | 933 | 933 |
| Parser blockers | 53 | 53 |
| Default fixture/request passes | 925 | 902 |
| Default fixture failures | 8 | 31 |
| Explicit Envirofacts override passes | 2 | 2 |
| Explicit minimal-input passes | Not available | 906 |
| Minimal-input fixture failures | Not available | 27 |
| Installed invocation failures | 0 | 0 |

The two after-run override successes already pass in default mode; they are not
two additional covered operations. Minimal mode passes all six EPA cases through
optional omission, retains the 25 invalid required examples, and introduces two
visible empty-multipart fixture failures for CHET `POST /chemicals/newchemfile`
and `POST /reaction/newreactfile`. Their fields are optional but the multipart
body is required; omitting every field leaves no encodable form. No fallback
fields or overrides were invented to make this mode pass.

Minimal mode deliberately reduces optional-input coverage and cannot repair
invalid required examples or declarations. Omitting an argument may activate its
public default, so omission is not automatically omission on the wire. The
installed outcome table records omitted inputs separately. The rebuilt corpus passes `R CMD check --no-manual` with **0 errors, 0 warnings
and 0 notes**, compared with baseline **1 error, 1 warning and 0 notes**.
[Corpus check](corpus-check.log). Both runs used the same package-check gate.

Generated R source grows from 7,533,310 to 13,089,611 bytes as wrappers gain public
schema validation. Both packages have 361 R files. The maximum R relative path
shrinks from 115 to 86 bytes. This source-size increase is a cost of the added
validation; no new client runtime dependency is introduced.
[Source-size measurements](source-size-comparison.json).

## Remaining contract dependencies

#26, #27, #28 and #31 remain open. Their ledger covers all requested operation sets,
including the five masked AMOS upload defects and eleven binary/nested overlaps.
The 68 issue/defect rows describe 52 distinct blocked operations. Each needs the
specific service-owned media, file representation, path/parameter correction or
nested query encoding identified in [CONTRACTS.md](CONTRACTS.md) and
[contract-dispositions.csv](contract-dispositions.csv). Scoped development-service
JSON evidence does not establish all archived production contracts.

The 53 parser blockers comprise 26 missing-media decisions, 18 binary-query
contracts, four invalid types, two nested-query contracts, two path mismatches
and the resolver GET-body declaration. They remain distinct from source
contradictions, invalid fixture examples and installed invocation failures. The resolver GET-body operation from
closed #29 remains blocked. The 375 server-origin diagnostics are unchanged. Offline origin overrides do not
establish production server configuration. Neither dry-run requests nor localhost byte captures prove
live EPA semantics or service compatibility. No live behavior was verified.

## Reproduce

Keep the baseline directory and use fresh output/toolkit directories. Commands run
from the repository root and never invoke production operations:

```sh
mkdir -p artifacts/review-toolkit-library
R CMD INSTALL --library=artifacts/review-toolkit-library .
R_LIBS=artifacts/review-toolkit-library Rscript dev/rebuild_hardened_proving_ground.R \
  artifacts/proving-ground-20260921T213801Z artifacts/review-proving-ground
Rscript dev/compare_hardened_proving_ground.R \
  artifacts/proving-ground-20260921T213801Z artifacts/review-proving-ground \
  artifacts/review-comparison
R_LIBS=artifacts/review-toolkit-library Rscript dev/verify_hardened_clients.R \
  artifacts/review-installed-clients
R_LIBS=artifacts/review-toolkit-library Rscript dev/verify_open_contracts.R
```

`dev/rebuild_hardened_proving_ground.R` reuses the archived audit/setup workflow,
records the installed toolkit location/version/code hash, creates fresh helpers,
preserves reviewed configuration, generates, checks freshness, builds, checks and
installs the client, then exercises separate fixture modes. Explicit Envirofacts
arguments come from the baseline override artifact. The comparison checks input
and configuration byte equality before reporting differences. Bulky package trees,
archives and disposable logs remain under ignored `artifacts/`. The completed
after run is `artifacts/proving-ground-hardened-20260922/`; its archive was
installed into that run's `library/provingground`. The independent sweep of the
R CMD check installation and final archive installation produced identical rows.
[Toolkit version and code hash](toolkit-provenance.json) identify the installation
used for generation. Two setup-script errors were corrected without rebuilding
inputs: the completed audit/full plan was retained, configuration byte equality
was checked, and the build resumed from that plan. The checked-in fresh-run script
contains those corrections; both logs and the continuation remain in the run.

For a baseline audit rerun, prepend the archived `library` to `.libPaths()`, source
its `audit_testing_specs.R`, and call `audit_testing_specs()` with the archived
`inputs/specmill-testing`, a fresh output directory and the same CHET policy from
the rebuild script. The completed rerun is retained under
`artifacts/proving-ground-baseline-recheck-20260922/`.

## Implementation commits

| Work | Commits |
| --- | --- |
| Public validation and hook ownership, #33/#34 | `085e5da`, `919d248` |
| Portable names and Unicode literals, #36/#37 | `a9e923a` |
| Fixture evidence, diagnostics and minimal mode, #35/#38 | `ec11e96`, `cc5b61c`, `d9e1558` |
| Helper provenance, manual adoption and source protection, #39 | `2a9720a`, `727850b`, `6b470ad`, `ab32802` |
| Installed localhost gates, #40 | `b053cda`, `9122950` |
| Correct valid synthetic transport fixtures | `b411630` |
| Unresolved contracts and newly visible fixture evidence | `2fb077e`, `0a6ba35` |
| Rebuild and stable-key comparison scripts | `4521a33` |

#32–#40 meet their implementation and integration acceptance criteria. #26–#28
and #31 retain the unresolved dependencies above; #4 was not changed.

#25 and #30 reuse the existing `c30e66f` implementation. Their acceptance criteria
were reverified before implementation and they were closed with that evidence.
