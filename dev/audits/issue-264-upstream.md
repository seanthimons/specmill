# Issue #264 upstream findings

Research date: 2026-10-29. Checkout: `13c08af2d576c27fee614162b73028e764b3a2aa`.
Read-only investigation except this file. No implementation, installations, credentials, live API calls, or commits. Read `AGENTS.md`, `README.md`, `HANDOFF.md`, `dev/WORKFLOWS.md`, relevant vignettes, authentication generation and request templates. Firecrawl CLI was absent; used available web extraction without setup.

## Recommendation

Consider a narrow, explicit environment binding for sensitive ordinary query parameters. Environment lookup alone provides no query-redaction guarantee. Avoid secret-file loading, credential-name inference, and a second general authentication framework. First investigate whether existing reviewed security corrections solve the missing-metadata case. Issue context: [#264](https://github.com/seanthimons/specmill/issues/264), [#251](https://github.com/seanthimons/specmill/issues/251). The AQS account in #264 is reported evidence, not independently verified here.

## Specification semantics

OpenAPI 3.1.1 separates reusable security schemes from effective requirements. A component definition alone has no effect. Operations inherit root security when omitted; an operation declaration replaces it, and `security: []` removes it. An empty requirement object permits anonymous access. Alternatives are OR; schemes within one requirement are AND. Parameter identity is name plus location; path-level parameters can be overridden at operation level but not removed there. A required ordinary query parameter remains a parameter contract independently of security. Neither `key` as a name nor `format: password` establishes an environment source or universal redaction contract. See [components](https://spec.openapis.org/oas/v3.1.1.html#components-object), [operations](https://spec.openapis.org/oas/v3.1.1.html#operation-object), [parameters](https://spec.openapis.org/oas/v3.1.1.html#parameter-object), [requirements](https://spec.openapis.org/oas/v3.1.1.html#security-requirement-object), and [formats](https://spec.openapis.org/oas/v3.1.1.html#data-type-format).

Swagger 2 likewise separates `securityDefinitions`, root/operation requirements, and ordinary parameters. Operation security overrides root security; an empty array removes it. Required query arguments do not disappear because no requirement names a scheme. See the [official Swagger 2 specification](https://swagger.io/specification/v2/).

## Installed httr2 behavior and exact limits

Inspected actual installed function bodies with `get(..., asNamespace('httr2'))`. Versions: R 4.5.0, httr2 1.3.0, curl 7.1.0, httpuv 1.6.17, libcurl 8.14.1. These observations are version-specific.

- `req_url_query()` modifies the real URL and has no query-redaction argument. `print.httr2_request()` prints `x$url` directly. Header redaction does not hide query values. See [URL API](https://httr2.r-lib.org/reference/req_url.html).
- `req_headers(..., .redact = ...)` tracks header names and includes Authorization by default. This protects supported console presentations, not outgoing transmission or unrestricted object access. Display redaction can be disabled. See [header API](https://httr2.r-lib.org/reference/req_headers.html).
- `req_dry_run()` uses a local echo server, not the target API. In this installed combination, curl returns `path` and `query` separately; httr2 prints and returns only `path`. Query omission is not deliberate secret redaction. Direct inspection of installed `curl::curl_echo()` showed separate `QUERY_STRING` capture, and direct echo returned the fake query. See [dry-run docs](https://httr2.r-lib.org/reference/req_dry_run.html) and [versioned source](https://raw.githubusercontent.com/r-lib/httr2/v1.3.0/R/req-dry-run.R).
- `req_verbose()` passes non-header lines through unchanged. `req_dry_run(req_verbose(req), quiet = TRUE)` printed the fake secret in the outgoing request line. Quiet dry-run presentation does not suppress the curl debug callback. Body and informational diagnostics are separate concerns. See [verbose API and linked source](https://httr2.r-lib.org/reference/req_verbose.html).
- A mocked HTTP 400 had the clean message `HTTP 400 Bad Request.` but retained request and response objects in its condition. URLs and the fake reflected response body remained accessible. Installed `resp_failure_cnd()` attaches `request` and `resp`; `curl_cnd()` retains the transport error as parent. Error-body callbacks and Bearer challenge diagnostics can add response text to displayed errors. See [error API](https://httr2.r-lib.org/reference/req_error.html), [status/challenge source](https://raw.githubusercontent.com/r-lib/httr2/v1.3.0/R/resp-status.R), and [perform source](https://raw.githubusercontent.com/r-lib/httr2/v1.3.0/R/req-perform.R).

No universal protection was established for object inspection, serialization, arbitrary logs, recordings, custom hooks, reflected responses, proxies, or server logs. The outgoing query must retain its actual value. A clean message is not a sanitized condition.

## Reproducible fake-secret experiment

Run through standard input with `Rscript --vanilla -`. Dry runs use local echo only; the error uses a mock. No target connection or real credential is needed.

```r
secret <- 'FAKE_264_SECRET'
req <- httr2::req_url_query(
  httr2::request('http://example.invalid/probe'), key = secret
)
req <- httr2::req_headers(req, Authorization = paste('Bearer', secret),
  Private = secret, .redact = 'Private')
print(req)
x <- httr2::req_dry_run(req)
cat(grepl(secret, x$path, fixed = TRUE), '\n')
httr2::req_dry_run(httr2::req_verbose(req), quiet = TRUE)
resp <- httr2::response(req$url, status_code = 400,
  headers = list('content-type' = 'text/plain'), body = charToRaw(secret))
e <- tryCatch(httr2::req_perform(req, mock = function(req) resp), error = identity)
conditionMessage(e)
grepl(secret, e$request$url, fixed = TRUE)
grepl(secret, e$resp$url, fixed = TRUE)
grepl(secret, rawToChar(e$resp$body), fixed = TRUE)
```

Observed request printing exposed the query and hid both selected headers. Ordinary dry-run path was `/probe`; its boolean was FALSE. Verbose dry-run printed `GET /probe?key=FAKE_264_SECRET HTTP/1.1`. The condition message omitted the secret; retained response URL/body checks were TRUE. Installed source confirms the request field also retains the request. Direct echo returned `?key=FAKE_264_SECRET` separately from path. Thus the dry-run omission cannot establish a query-redaction guarantee.

## Environment lookup versus file loading

R processes site then user environment files at startup unless disabled. `R_ENVIRON_USER` selects a user file; otherwise R searches current-directory `.Renviron` before home `.Renviron`. These are alternatives, not an automatic merge. `--vanilla` includes `--no-environ`. Editing a file does not refresh an existing process; restarting or explicitly reading it does. See [R startup](https://stat.ethz.ch/R-manual/R-devel/library/base/html/Startup.html). `readRenviron(path)` explicitly reads R environment-file syntax into the process environment. See [base API](https://stat.ethz.ch/R-manual/R-devel/library/base/html/readRenviron.html).

R startup does not automatically discover `.env`. Applications can explicitly call `dotenv::load_dot_env(file = '/chosen/path/.env')`. However, dotenv's `.onLoad()` loads a current-directory `.env` if present. Adding it as an automatically loaded dependency would undermine a promise of no implicit loading. Its parser includes the beginning of an invalid line in errors. Do not promise safe diagnostics for arbitrary loader failures or interchangeable dotenv/Renviron syntax. See [first-party dotenv source](https://raw.githubusercontent.com/gaborcsardi/dotenv/main/R/dotenv-package.r). Source was inspected; no dotenv file-loading experiment was performed.

Recommendation: clients call `Sys.getenv()` against the already-set process environment on every request. Users choose R startup, explicit file loading, shell exports, or CI injection. This needs no specmill file discovery, new file writer, or dotenv dependency.

## Current repo implications and objections to broad configuration

Local evidence at the recorded checkout:

- `R/authentication.R::operation_authentication()` and `inst/templates/authentication.R::api_auth()` already model requirements and environment mappings. `api_token()` reads at runtime. Query authentication calls `req_url_query()` without query redaction.
- `R/operations.R` distinguishes omitted operation security from root/operation declarations.
- `R/mappings.R` and `vignettes/configuration.Rmd` already support per-operation `security_correction`, with an explicit reason and requirements naming declared schemes. The archived schema remains unchanged. Existing reviewed parameter exclusions can remove redundant wrapper arguments. Investigate that combination for the declared AQS scheme before inventing another mechanism. It is not proof of complete AQS handling; exclusions must not discard unrelated business inputs. Corrections do not handle independent ordinary sensitive values and do not fix query printing.
- `inst/templates/request.R` returns a real httr2 request on specmill dry run, unlike httr2's dry-run display. Default verbose messages omit URLs and default transport/status errors use restricted messages. But `preserve_errors = TRUE` rethrows transport errors and invokes httr2 status conditions for non-401 responses. Response policies receive raw responses and can receive query attribution. These paths and client-owned helper edits rule out a blanket diagnostic guarantee. Regeneration does not overwrite existing client-owned request helpers.

If a binding is approved, keep exact API/service and operation scope, wire identity `query` plus exact name, and one environment-variable name. Resolve before ordinary required-value validation and serialization on every call. Reject unknown identities and incompatible shapes during generation. Treat email independently. These are design recommendations, not settled policy syntax.

Prefer one fixed collision rule over configurable precedence modes: require the configured source, reject conflicting explicit arguments, and reject inconsistent overlapping auth mappings. Identical overlap may share one value and emit one wire parameter. Required missing/empty sources should fail before HTTP without echoing values. Optional-source behavior and acceptance of identical explicit arguments still need a decision. Test final serialization after auth injection, including duplicate names and already-encoded tokens.

A provider registry, inferred names, secret-file paths, per-field precedence switches, another setter, or another inheritance tree adds maintenance without upstream necessity. If protected printing is required, enumerate the specmill-owned presentations and conditions covered, and test each. Returning an unrestricted httr2 object while promising all downstream displays are safe is unsupported by this evidence.

## Relationship to #251 and remaining work

[#251](https://github.com/seanthimons/specmill/issues/251) concerns shared authentication meaning and per-transport injection. [#264](https://github.com/seanthimons/specmill/issues/264) can bind an ordinary parameter without claiming the schema declared authentication. Reuse lookup and sensitivity metadata where useful, while retaining provenance for schema requirements, reviewed corrections, and ordinary bindings. HTTP query configuration should not become the format-neutral auth model or require every future transport first.

Before implementation, settle overrides, overlap, optional values, and exact protection boundaries. Then verify generated wrappers without security declarations, changed environment values between calls, missing/conflicting values, final wire encoding, print/dry-run/condition behavior, and runtime independence from specmill. Recorder integrations need their own evidence.

Validation: installed-source inspection, fake-secret local echo and mocked-condition probes, primary web docs, and final scope/whitespace checks. No package tests or full check ran because no package code changed. No conclusion about live AQS authentication correctness or comprehensive redaction is claimed.
