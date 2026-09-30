# Generalize the generated request helper

Reviewed 2026-09-30 on branch `feat/generalize-request-policies`, starting from specmill commit `62d7f6059ee828d600706786e9e68907e3fa1845`.

This is a source review and implementation plan. No runtime port or downstream adoption is implemented by this document. The requested range, #63 through #67, contains five open issues. [ComptoxR #331](https://github.com/seanthimons/ComptoxR/issues/331) owns the migration; its linked #342 owns downstream adoption and verification.

## Recommendation

Extend specmill's existing request template. Keep one ordinary request function, reusable batching and pagination companions, and optional client policies. Specmill owns their source and generation; each generated package owns its emitted runtime and needs no specmill dependency. Normal regeneration must preserve customized helpers.

Generalizable means the transport has no EPA, chemical, PubChem, or response-envelope assumptions. It does not mean that incomplete API schemas reveal pagination, collection shape, or safe write replay. Use schema declarations where they describe the contract, and explicit reusable policy where they do not. Existing schema capability diagnostics still apply; these five ports cannot make every possible API schema supported.

Do not copy ComptoxR's large helper wholesale. Its domain defaults would make other clients less predictable. Keep its exported signatures in a ComptoxR compatibility facade over generated transport. A package user should continue calling an ordinary endpoint function; maintainers should select common policy once at package/service level and override only exceptional operations.

## Issue review

| Issue | Reusable change | Boundary or concern | Work in the current source |
| --- | --- | --- | --- |
| [#63: responses](https://github.com/seanthimons/specmill/issues/63) | Access to the final HTTP response before default error/decoding policy; explicit CSV/TSV decoder; selected result formatting | Preserve default JSON/list, text/string, binary/raw, and empty/NULL results. Never guess a collection from `data`, `results`, or `content` globally. | `inst/templates/request.R` already disables httr2's automatic status error and then checks status itself. Insert policy there. `R/helper-provenance.R` records the scaffold baseline. |
| [#64: batching](https://github.com/seanthimons/specmill/issues/64) | Emit one self-contained sequential batching companion, reusing `batched()` | Keep inputs and results unchanged by default. Deduplication, dropping NA/empty inputs, singleton encoding, merging, and partial failure recovery are client choices. | `R/batching.R` is small enough to reuse directly, but calling `specmill::batched()` from an installed client violates the runtime boundary. Initialization/emission and ownership records need coverage too. |
| [#65: pagination](https://github.com/seanthimons/specmill/issues/65) | Emit bounded page/offset/cursor/link iteration with explicit extraction, advancement, stopping, and error policy | Largest port. Parameter names cannot identify Spring pagination. Preserve nested body fields. Do not introduce the toolkit's 10,000-item default cap into ComptoxR parity mode. | `R/pagination.R` uses fixed strides and empty-page termination, plus `config_string()`, `pagination_token()`, and `digest`. `R/pagination_links.R` also uses `%or%`. Emission must include or remove these dependencies deliberately. |
| [#66: plain-text bodies](https://github.com/seanthimons/specmill/issues/66) | Generate declared scalar `text/plain` bodies and explicit vector-of-lines encoding | Scalar text is opaque. Preserve embedded newlines, blank lines, duplicates, and trailing newlines. Joining lines is a separate selected input contract. | Update media selection in `R/form_bodies.R`, settings validation in `R/mappings.R`, schema compatibility in `R/operations.R`, body checks/rendering and batch gates in `R/generation.R`, and the template. Adding only a transport branch fails. |
| [#67: retry predicates](https://github.com/seanthimons/specmill/issues/67) | Allow a validated, explicitly selected predicate through existing httr2 retry construction | All-5xx retry is compatibility policy, not a universal default. Preserve `retry_writes`, native statuses, Retry-After, and two retries = three total attempts. | Extend the existing controls/policy route in `R/mappings.R` and the template. Do not accept arbitrary executable YAML or create a second retry loop. |

All five issues have sensible upstream scope. The risk is interpreting their compatibility criteria as universal default behavior. Emitting companions and selecting policies must be supported by specmill; asking every client maintainer to copy these functions manually would leave #64 and #65 unresolved.

## Where hooks help

The current flow, documented in `vignettes/hooks.Rmd` and implemented by `R/generation.R` and `inst/templates/hooks.R`, is:

```text
validate public inputs
  -> pre_request(params)
  -> helper builds, sends, checks status, decodes
  -> post_response(result, params)
  -> public result
```

`post_response` runs once around the helper call, not once per internal retry, batch, or page. It receives a decoded result and public parameters, not the HTTP response. It cannot observe a failed response, suppress a status error, select a decoder before malformed JSON aborts, or read HTTP media/headers. #63 needs a response policy inside the helper, before those defaults. No new wrapper hook stage is necessary.

Recommended minimal contract, to settle during #63 implementation: an optional response callback receives the final `httr2_response`, safe request context, and a callable default decoder. It can observe then delegate, or return a replacement result including NULL, warn, or abort. A callable decoder avoids an ambiguous NULL-means-delegate convention and avoids copying the decoder into compatibility code. Default context must not expose credentials or full URLs in diagnostics. This is a proposed interface, not an existing feature.

| Behavior | Placement |
| --- | --- |
| Observe the final response, inspect status/headers, choose warning/empty/error behavior | Helper response policy before default handling |
| CSV/TSV parsing, or alternative decoding of a documented media type | Reusable decoder selected by response policy |
| Extract a known collection, attribute a query, rename fields, clean NULLs, format a tibble | Existing post-response hook when only decoded data/params are needed |
| Read pagination totals, next cursor, `last`, or actual page size | Pagination companion before final output formatting |
| Normalize chemical identifiers or synthesize Chemi options/search payloads | ComptoxR facade/pre-request policy |
| Convert PNG to magick or choose PDF raw fallback | ComptoxR response policy with actual media type available |
| Retry statuses and safe write replay | Request controls before execution |

Do not force all result transformations into endpoint hook registrations. Reuse one service policy or named formatting function for common behavior, with existing hooks for exceptions. Preserve raw envelopes until pagination has consumed metadata. A format hook that drops totals before the paginator sees them breaks iteration.

## ComptoxR behavior to keep out of universal defaults

The companion [source review](comptoxr-request-conventions.md) records the functions and callers.

- Chemical query cleanup removes duplicates, NA, and empty strings. Other APIs may require duplicate entries or empty values. Keep cleanup selected and stable in the compatibility facade.
- Envelope guessing can discard a legitimate object's `data` or `results` field. Select the exact extractor for a service/operation.
- NULL-to-NA replacement, semicolon flattening, and type conversion alter JSON meaning and nested record structure. Preserve native lists and types; offer selected compatibility formatting with existing client dependencies.
- Warning-and-empty behavior and keeping successful chunks/pages can conceal partial results. Keep native immediate failure. Compatibility recovery must preserve warnings and have localhost failure cases.
- The documented first-batch-only pagination behavior is a historical limitation. Preserve it only where #65 requires migration parity, then fix it separately. New generic behavior must not silently lose later batches.
- A `page` plus `size` pair does not identify Spring Boot metadata or zero-based numbering. ComptoxR #331 documents broken ChET wrappers caused by that assumption. Start page, extractor, and stopping rule must be explicit. The approved downstream default correction must be recorded separately from strict signature parity.
- Decode using the response's actual Content-Type. The #331 image example fails because ComptoxR chooses a decoder from a requested list of acceptable types. Optional magick conversion remains client-owned. The comment's SVG prose and acceptance wording differ; downstream SVG output class needs an explicit decision before adoption tests are fixed.
- EPA server resolution, `ct_api_key()`, the observer registry, PubChem Fault/throttle/User-Agent policy, and chemical resolution belong to ComptoxR. A response callback should let the client preserve them without duplicating transport.
- `generic_search_request()` has no direct callers in the inspected source. Retain it during migration as required by #331, or document its later removal; do not create a search-specific specmill transport.

## Plain-text research for #66

This is a general request media capability. OpenAPI 3 describes bodies with media-keyed `content`; Swagger 2 describes media with `consumes` and a body schema. Neither defines newline joining for arbitrary arrays. Start with an explicitly declared string body; vector-of-lines conversion must be selected separately. See the [OpenAPI 3 request body specification](https://spec.openapis.org/oas/v3.0.3.html#request-body-object) and [Swagger 2 operation/body specification](https://spec.openapis.org/oas/v2.0.html#operation-object).

There is already concrete evidence in specmill's archived corpus. `inst/schema-stress/natural-products.json` declares `text/plain` string bodies for `/chem/standardize`, `/chem/all_filters`, `/chem/all_filters_detailed`, `/convert/molblock`, and `/convert/xyz`. MOL and XYZ examples include significant blank lines and embedded newlines. Use synthetic fixtures derived from these shapes; leave the archived schema unchanged. `classifier-dev.json` contains text/plain elsewhere but has no text/plain requestBody declaration in the inspected document.

Outside the chemical APIs, InfluxDB's `/api/v2/write` accepts UTF-8 text/plain line protocol. This supports adding the media capability rather than a CTX endpoint exception. It does not justify implementing InfluxDB line-protocol parsing. See [InfluxDB write API documentation](https://docs.influxdata.com/influxdb/v2/api/write/).

Specify empty versus omitted bodies, line separator and final-newline policy, and byte-limit checks before implementation. A scalar empty string should send an explicitly empty body; NULL should omit the body. Already-encoded text must not be split into records automatically, especially multiline molecular formats. Character NA must fail validation rather than become literal `NA`.

## Implementation sequence and acceptance evidence

1. Implement #63's raw-response policy and explicit delimited decoding first. Preserve native returns and error messages with no policy. Cover observers, 4xx/5xx decisions, malformed JSON/delimited data, empty bodies, heterogeneous records, and optional formatting. Use one reusable policy definition rather than per-wrapper closures.
2. Implement #67 through existing retry construction. Cover 408 excluded, 429 and 501/505 selected, permanent 4xx excluded, recovery/exhaustion at three attempts, and explicit POST replay. Runtime function references must validate before HTTP; YAML configuration must remain declarative.
3. Implement #66 end to end using the documented request contracts above. Cover OAS/Swagger declarations and reviewed media selection, scalar exact bytes, selected lines, empty/UTF-8/embedded newlines, auth/query preservation, and byte limits. Keep JSON/form/binary checks passing.
4. Implement #64 companion emission. Keep splitting, normalization, request execution, and result merging separate so existing transport handles auth/query/retries for every chunk. Test empty, boundary, N+1, stable order, exact bytes, and explicit failed-middle-chunk recovery.
5. Implement #65 companion emission and policies on top of response support. Cover page/offset/cursor/link examples, response-selected stride, nested body cursor updates, empty/short/metadata completion, missing/repeated cursors, max-page warnings, explicit partial failures, and same-origin credential protection. Preserve ordinary single-call wrappers.
6. Adopt a reviewed specmill commit in ComptoxR #342. Generate the compatibility facades, record helper provenance, rerun the focused suites and fresh installed-client localhost comparison, and remove only verified replacements. The existing 1,106-case baseline retained handwritten helpers and proves no port is complete.

For every emitted capability, test generated installed clients without specmill runtime imports, deterministic repeated emission, name collisions in multi-service packages, and preservation of edited helper files. Optional tibble formatting must use explicit client dependencies; native clients must not gain tidyverse or magick runtime dependencies.

The acceptance contract should let a maintainer select common behavior at the existing defaults/service level, keep public wrapper signatures simple, and configure exceptions per operation. Users should not have to write a callback just to send a declared plain-text string or use a provided CSV decoder. Arbitrary pagination necessarily needs explicit API knowledge when the schema omits it, but the loop, bounds, and update mechanisms should be provided.

## Verification performed for this review

Issue states, bodies, and comments were read with GitHub CLI. Source paths were inspected in this checkout. The following existing checks all passed against an isolated installation of this checkout:

```sh
Rscript tests/response-handling.R
Rscript tests/batching.R
Rscript tests/pagination.R
Rscript tests/helper-provenance.R
```

These checks establish current behavior only; no port acceptance box is complete.
