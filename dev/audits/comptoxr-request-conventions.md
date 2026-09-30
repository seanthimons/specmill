# ComptoxR request conventions for specmill

Reviewed on 2026-09-30. [ComptoxR #331](https://github.com/seanthimons/ComptoxR/issues/331) names five upstream ports, specmill #63 through #67, and downstream adoption in ComptoxR #342. The existing 1,106-case comparison retained the old helpers. It proves a migration baseline, not completion of these ports.

Source inspection used the local ComptoxR checkout at `5bab21b5b1390ac6cba1cef992a1b1a8ef6e05d8`. That checkout contains unrelated working changes. Its `R/z_generic_request.R` is unchanged locally and has the same Git blob, `699c0da3dee9dcbad7313c2f2ed334556a02fad6`, as GitHub main at `4fd720b97fb2f7f2abf131925e9270b0c11b057a`. Links below pin that public revision. No production requests were sent.

## Actual callers

Parsing every top-level function in local `R/` and finding references in function bodies gives the following counts. Counts include generated and manual wrappers; they are functions that reference a helper, not call-expression counts.

| Helper | Callers | Migration implication |
| --- | ---: | --- |
| `generic_request()` | 288 | Preserve its exported facade downstream, while routing its transport through specmill's generated helper. |
| `generic_chemi_request()` | 58 | Preserve the exported chemical facade; its payload conventions need explicit schema mappings or client hooks. |
| `generic_search_request()` | 0 | No new search-specific upstream transport is needed. Record retention or removal downstream. |
| `generic_pubchem_request()` | 3 | `pubchem_properties`, `pubchem_search`, and `pubchem_synonyms` share service policy that stays in ComptoxR. |

All four definitions and four supporting functions share [one runtime file](https://github.com/seanthimons/ComptoxR/blob/4fd720b97fb2f7f2abf131925e9270b0c11b057a/R/z_generic_request.R). Removing that file before assigning every definition an owner would break retained clients.

## What belongs upstream

| Convention | Appropriate specmill behavior | ComptoxR compatibility decision |
| --- | --- | --- |
| JSON, text, bytes, CSV/TSV decoding | Keep lossless JSON/text/bytes defaults. Offer explicit delimited parsing with base `utils::read.table()`. | Review differences between requested-content-type decoding and actual-header decoding. #331 explicitly calls for actual-header decoding to fix the image bug; do not preserve that bug for parity. |
| Response observation and status policy | Allow a client callback to inspect the raw response before HTTP failure handling or decoding. Keep failure behavior explicit. | Route the existing observer through it; retain the ComptoxR registry. |
| Batching | Emit one reusable sequential batching companion, preserving order and bounded batch sizes. Let callers choose collection and error policy. | Preserve current normalization, partial success, warnings, and output through the facade or shared client policy. |
| Pagination | Emit the existing reusable bounded strategies with explicit parameter locations, extraction paths, completion policy, and error policy. | Configure AMOS path offsets, CTX page numbers, Spring metadata, and Chemi body offsets. Avoid hardcoding those names in native transport. |
| Plain-text request bodies | Select media through schema parsing, mapping validation, rendering, and transport. Distinguish already-encoded text from a vector of lines. | Newline-join chemical search identifiers explicitly. Do not newline-join every text body. |
| Retry predicates | Preserve an explicitly selected client function in generated controls; use httr2's existing retry machinery. | General helpers use three attempts with 429 or any status at least 500. PubChem uses four attempts and a different status set. Keep replayable POST retries opt-in upstream. |

The delimited parser preserves column names and quoted separators, disables comments, and rejects ragged rows. This is useful reusable decoding without another dependency. See [parser and retry predicate](https://github.com/seanthimons/ComptoxR/blob/4fd720b97fb2f7f2abf131925e9270b0c11b057a/R/z_generic_request.R#L113-L147).

## Behaviors that should not become universal defaults

`generic_request()` normalizes inputs with `unique()`, removes missing and empty values, and flattens lists. An API may require duplicate values, positional correspondence, nested inputs, an empty string, or a JSON null. Schema validation should reject invalid input rather than silently rewrite valid input. Its static-endpoint sentinel, environment-variable batch defaults, positional path parameters, unnamed ellipsis path arguments, and automatic flattening of `options` are compatibility conventions. The native helper already has named transport arguments and schema serialization. See [normalization and request construction](https://github.com/seanthimons/ComptoxR/blob/4fd720b97fb2f7f2abf131925e9270b0c11b057a/R/z_generic_request.R#L248-L443).

The same construction treats every non-POST method as GET and ties path/query placement to `batch_limit`. That cannot generalize to arbitrary API schemas. Retain schema-selected verbs and parameter locations upstream. The explicit-body path may also send the same body once per query batch if both are supplied. Do not make that coupling a native batching rule.

`unwrap_collection_envelope()` guesses that a sole field named `results`, `records`, `data`, or `content` is a collection. Those can be legitimate business fields. Use a schema-derived or explicitly selected extraction path; preserve the guess only in compatibility code. See [envelope helper](https://github.com/seanthimons/ComptoxR/blob/4fd720b97fb2f7f2abf131925e9270b0c11b057a/R/z_generic_request.R#L149-L161).

`safe_tidy_bind()` turns nested values into semicolon-delimited strings and applies `type.convert()` to character columns. It loses nested structure, can convert identifiers such as `"001"` to numbers, and cannot distinguish original types after coercion. The `tidy = FALSE` path still changes NULL fields to NA and may unwrap envelopes. Keep these behaviors as named client formatting policies. A generic response should preserve data; end users can select a reusable table formatter when they want it. See [tidying](https://github.com/seanthimons/ComptoxR/blob/4fd720b97fb2f7f2abf131925e9270b0c11b057a/R/z_generic_request.R#L14-L111) and [JSON processing](https://github.com/seanthimons/ComptoxR/blob/4fd720b97fb2f7f2abf131925e9270b0c11b057a/R/z_generic_request.R#L726-L803).

Query attribution is conditional on a singleton batch and list response, despite its comment describing path GETs. Chemi adds a `dtxsid` column when row count happens to match query length, and keyed results become `query_id`. These are useful client output conventions, not evidence that any API preserves input/output order. Keep attribution explicit and client-owned.

Image output changes class when `magick` happens to be installed. Return bytes consistently upstream and allow an explicit client formatter. EPA server aliases, `ct_api_key()`, chemical resolution and `{chemicals, options}` synthesis, PubChem Fault envelopes, its throttle and User-Agent, and the probe registry also stay client-owned. See [Chemi synthesis](https://github.com/seanthimons/ComptoxR/blob/4fd720b97fb2f7f2abf131925e9270b0c11b057a/R/z_generic_request.R#L877-L929), [Chemi attribution](https://github.com/seanthimons/ComptoxR/blob/4fd720b97fb2f7f2abf131925e9270b0c11b057a/R/z_generic_request.R#L1068-L1079), and [PubChem service policy](https://github.com/seanthimons/ComptoxR/blob/4fd720b97fb2f7f2abf131925e9270b0c11b057a/R/z_generic_request.R#L1244-L1315).

## Error and pagination traps

Single non-paginated generic and Chemi requests use ordinary `req_perform()`. HTTP failures can throw before their custom status checks and observer calls. Multi-batch generic requests use `on_error = "continue"`, then warn and discard HTTP failures; transport failures without a response become NULL without a per-batch warning. Pagination returns only successes after `on_error = "return"`, so a failed later page can leave partial data without the same batch warning. Preserve those differences only where downstream compatibility requires them. Native default failures should be visible and partial collection explicitly selected.

`generic_request()` paginates only `req_list[[1]]`. It does not paginate every batch. This is a migration quirk to document, not an upstream feature. Page-size extraction recognizes `content`; other collection extraction recognizes `results` and `records`. Offset stopping also recognizes `data`, but the collection path does not extract it consistently. Generic cursor lookup guesses several response field names and writes a top-level `cursor`. Explicit nested paths are safer for arbitrary schemas. The max-pages warning fires whenever successful page count reaches the cap, even if the last fetched page exhausted the API. See [generic pagination](https://github.com/seanthimons/ComptoxR/blob/4fd720b97fb2f7f2abf131925e9270b0c11b057a/R/z_generic_request.R#L453-L658).

Chemi's pagination branch applies the same body-offset algorithm to any selected non-`none` strategy. It assumes `totalRecordsCount`, `recordsCount`, `offset`, and `records`; missing total defaults to zero and stops immediately. That is service policy. Preserve response-selected increments when configured, not these field names or fallback values. See [Chemi pagination](https://github.com/seanthimons/ComptoxR/blob/4fd720b97fb2f7f2abf131925e9270b0c11b057a/R/z_generic_request.R#L971-L1032).

## Hooks without extra work for wrapper authors

Existing specmill `post_response` hooks receive decoded `result` and public `params`; they run after the helper returns. They fit record extraction, client table formatting, and query attribution. Image conversion fits there only when the selected media is already known; actual-header dispatch needs raw-response policy. They cannot observe failed HTTP responses or decide status handling before the helper throws. Add raw-response access in the shared transport policy, not a requirement that every endpoint implement its own error hook.

Use one package-wide policy or shared formatter and allow endpoint overrides only when the schema or service requires them. Generated wrappers should select ordinary batching, pagination, media, and retry behavior from schema/configuration. Asking end users to write those loops in hooks defeats specmill's purpose. Keep chemical synthesis in existing pre-request hooks when the schema cannot express it. Do not add a second search transport or reproduce transport logic inside hooks.

Downstream adoption must separately verify signatures, exact request bytes, response classes, warnings/errors, observer behavior, and partial results. The upstream helper should remain generated into the client with no specmill runtime dependency. Updating ComptoxR's toolkit pin alone does not replace retained client-owned helpers.
