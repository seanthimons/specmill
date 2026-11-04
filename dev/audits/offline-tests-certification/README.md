# Offline test workflow certification (#262, parent #256)

Branch `feat/issue-256-offline-tests-coverage`. Every test named here is a
standalone script run with `Rscript tests/<name>.R` after `R CMD INSTALL .`.

## #262 acceptance

| Item | Evidence |
|---|---|
| Swagger 2, OpenAPI 3 and YAML inputs | `offline-certification.R` (Swagger 2 written as YAML); `scenario-replay.R` (OpenAPI 3 JSON); `scenario-inputs.R` and `testing-proposals.R` (Swagger 2 input resolution) |
| Path, query and header encoding | `offline-certification.R`: path value with a space and slash, csv array query, header parameter, all recorded and replayed |
| Authentication | Query API key (`offline-certification.R`, `scenario-replay.R`), header API key (`scenario-replay.R`), env-bound argument (`parameter-env.R`, `scenario-replay.R`) |
| JSON, form and binary bodies | `offline-certification.R`: JSON request body, urlencoded form body, `application/octet-stream` response |
| Multipart bodies | Not recordable: vcr stores httr2 multipart parts as raw `curl::form_data` objects that YAML cannot encode. Declaring such a scenario is now an error that points to `unrecorded` plus a contract (`scenario-inputs.R`, `offline-certification.R`). Wire behavior stays covered by `form-transport.R` |
| Empty responses | `offline-certification.R`: DELETE returning 204 |
| Error responses | Not expressible as scenarios by design: a recording whose test fails is deleted, and expectations describe results. Covered by hook chain error cases (`hook-cases.R`) and transport tests (`response-handling.R`, `typed-errors.R`) |
| Pagination and batching | `offline-certification.R`: a page-mode wrapper records three requests in one cassette, and a fan-out batch records two |
| Hooks | `offline-certification.R`: a real `pre_request` hook runs during a recorded scenario and under `R CMD check`; `hook-cases.R` covers cases and integrations |
| Localhost transport tests retained | `native-transport.R`, `form-transport.R`, `bracket-transport.R` and the other transport scripts are unchanged and pass |
| Build, install and check generated clients | `offline-certification.R` stops the server, then runs `R CMD build` and `R CMD check --no-manual` on the client with credentials unset and `CI=true`, failing on any ERROR or WARNING |
| Offline replay, no credentials, no specmill | `offline-certification.R` and `scenario-replay.R`: replay with credentials unset, leak scans of client files, no `specmill` in DESCRIPTION dependencies or code; `scenario-replay.R` also asserts specmill is not loaded during replay |
| Unchanged second generation | `offline-certification.R` and `scenario-replay.R` compare md5 sums of every client file |
| Docs | `vignettes/testing.Rmd` (coverage selection, reviewed expectations, hook cases, opt-in recording, filtering, a new failure-diagnosis table, cassette refresh); `vignettes/maintenance.Rmd` (new "Maintain recorded tests"); `vignettes/troubleshooting.Rmd` (pointer) |
| #182 | specmill has no renderer that emits the `endpoint`/`operation` assertion (no such text in `R/` or `inst/`). It comes from ComptoxR `dev/generate_tests.R`. The issue stays open for the ComptoxR owner and blocks closing the milestone, not this certification |

## #256 exit criteria

| Criterion | Evidence |
|---|---|
| All eight subissues pass their acceptance checks | #257 to #261, #272 and #273 are implemented on this branch with targeted tests; this file covers #262 |
| A fresh generated client installs and runs offline with real hooks and request helpers | `offline-certification.R` |
| Missing or unmatched cassettes fail without contacting upstream or recording | `scenario-replay.R` (request counter unchanged, no cassette written, CI refusal) |
| Replay works with dummy credentials and reviewed, scrubbed fixtures | `scenario-replay.R`, `offline-certification.R`, and the live AQS trial below |
| Contracts, scenarios, hook cases, gaps and execution reported separately | `testing-report.R` |
| Existing helper contracts and client-owned tests remain supported; a second generation changes no files | The full `tests/*.R` suite passes; md5 checks above |
| Targeted tests and full package checks pass, including generated-client checks | Full suite and `rcmdcheck(args = '--no-manual')` on a clean copy; generated-client `R CMD check` in `offline-certification.R` |

## Live trial: AQS client

On draft PR seanthimons/aqsclient#1, 8 scenarios across the list, meta_data
and available services were recorded live from the AQS API, with the required
email bound to `AQS_EMAIL`:

- With `AQS_EMAIL` and `AQS_KEY` unset, all 8 replayed offline and specmill was
  not loaded.
- `review_recordings()` found 7 responses that agree with the response schema.
  `/serviceAvailable` is unchecked because it does not return JSON.
- A scan of every client file, including decoded gzip bodies, found neither
  the real email nor the key.

## Findings fixed during certification

- **Multipart scenarios:** these failed at record time with a YAML emitter
  error. They are now refused when declared, with guidance.
- **Hooked clients listed `yaml` twice:** new clients list `yaml` in `Suggests`,
  and hooks need it in `Imports`, so `R CMD check` raised a NOTE. Hook setup and
  its docs now say to move `yaml` to `Imports`.
- **Empty 204 on httpuv:** an empty 204 from httpuv broke the next response on
  the reused connection. This affects only the test server, and it now closes
  the connection.

## Follow-up

The client request helper reports every error from `httr2::req_perform()` as
"HTTP request failed before a response was received". That includes vcr
refusals and serialization errors, so replay mismatches look like transport
failures. The diagnosis table documents the `preserve_errors` workaround. The
helper fix changes generated output and every recording's provenance, so it is
tracked separately in #275.
