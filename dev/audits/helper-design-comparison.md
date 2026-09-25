# Generic request helper comparison

Source inspection on 2026-09-22. Examples below explain the designs; no live API calls were made.

## apipkgen

Inspected commit `d93294f134307d651b99fabfbfcaf4c662f2b43e`.

`generate_pkg()` writes `R/http-helpers.R` separately from endpoint functions in `R/http-fxns.R`. It selects either a crul or httr template. This gives the client its own editable transport implementation. Generated packages depend on the chosen HTTP library, jsonlite, and glue, rather than calling apipkgen for transport. See [generation](https://github.com/sckott/apipkgen/blob/d93294f134307d651b99fabfbfcaf4c662f2b43e/R/generate_pkg.R#L23-L36) and [package dependencies](https://github.com/sckott/apipkgen/blob/d93294f134307d651b99fabfbfcaf4c662f2b43e/R/create_pkg.R).

Each verb helper delegates to `xVERB()`. The httr version sends the request, checks HTTP status, and returns UTF-8 response text. Endpoint wrappers pass `...` through, so callers can supply HTTP-library options. A client maintainer can edit the copied helper to add authentication or change response handling across endpoints. See the [httr helper template](https://github.com/sckott/apipkgen/blob/d93294f134307d651b99fabfbfcaf4c662f2b43e/inst/examples/http-functions-httr.R) and [crul variant](https://github.com/sckott/apipkgen/blob/d93294f134307d651b99fabfbfcaf4c662f2b43e/inst/examples/http-functions-crul.R).

Illustrative use of the httr helper:

```r
xGET(url, httr::timeout(60))
```

For a permanent API-wide timeout, the maintainer can put that option in their copied `xVERB()` instead. This is the baseline-helper model the user described.

This is not an upgrade-management precedent. `write_http_funs()` appends template content to the target file; it does not reconcile local modifications. The source also has rough edges, including Swagger generation hardcoding GET behavior despite iterating over method names. Borrow the separation of endpoint wrappers and editable helper, not an assumption of safe regeneration. See [helper writing](https://github.com/sckott/apipkgen/blob/d93294f134307d651b99fabfbfcaf4c662f2b43e/R/write_fxns.R#L73-L80) and [Swagger generation](https://github.com/sckott/apipkgen/blob/d93294f134307d651b99fabfbfcaf4c662f2b43e/R/write_fxns_swagger.R).

## beekeeper

Inspected beekeeper commit `05e9d25304fc406b1d91104e4f8c69195fad9f80` and its runtime dependency nectar at `d27c4cbd03f3b8c72e0beb577bfd49aca2881524`.

Beekeeper generates a package-specific request-preparation function, such as `guru_req_prepare()`, that calls `nectar::req_prepare()` with a fixed base URL and exposes path, query, body, header, cookie, method, and response-tidying policy. For authenticated APIs, the template applies a separate generated authentication helper. It returns a request object before network execution. See the [preparation template](https://github.com/api2r/beekeeper/blob/05e9d25304fc406b1d91104e4f8c69195fad9f80/inst/templates/010-prepare.R) and [generated APIs.guru helper](https://github.com/api2r/beekeeper/blob/05e9d25304fc406b1d91104e4f8c69195fad9f80/tests/testthat/_fixtures/guru/R/010-prepare.R).

Its generated APIs.guru endpoint separates three responsibilities:

1. `req_get_provider(provider)` validates the argument and prepares an httr2 request through `guru_req_prepare()`.
2. `get_provider(provider, max_reqs, max_tries_per_req)` prepares and sends that request with `nectar::req_perform_opinionated()`, then parses the responses.
3. `tidy_policy_get_provider()` selects JSON response parsing behavior.

The request constructor is exported. The combined execution wrapper is initially internal. This lets a package user modify a prepared request before sending it. See the [generated endpoint](https://github.com/api2r/beekeeper/blob/05e9d25304fc406b1d91104e4f8c69195fad9f80/tests/testthat/_fixtures/guru/R/paths-apis-get_provider.R).

Illustrative composition using that generated request constructor:

```r
req_get_provider("googleapis.com") %>%
  httr2::req_timeout(60) %>%
  nectar::req_perform_opinionated() %>%
  nectar::resp_parse()
```

The maintainer could instead put `httr2::req_timeout(req, 60)` before the return in `guru_req_prepare()` to make it apply to every endpoint.

Nectar supplies the actual generic request machinery at runtime. `req_prepare()` initializes the base request, applies path/query/body/method/header/cookie settings, then authentication and optional pagination/tidying policies. `req_modify()` uses httr2 modifiers, discards NULL query/cookie entries, and chooses JSON or multipart body handling. It retains the `httr2_request` class while adding `nectar_request`. See [nectar preparation](https://github.com/api2r/nectar/blob/d27c4cbd03f3b8c72e0beb577bfd49aca2881524/R/req_prepare.R), [initialization](https://github.com/api2r/nectar/blob/d27c4cbd03f3b8c72e0beb577bfd49aca2881524/R/req_init.R), and [modification](https://github.com/api2r/nectar/blob/d27c4cbd03f3b8c72e0beb577bfd49aca2881524/R/req_modify.R).

Generated clients import nectar and suggest beekeeper. Therefore a nectar update can change generic request behavior without regenerating the client's preparation function. This differs from copying a fully self-contained helper. See [dependency setup](https://github.com/api2r/beekeeper/blob/05e9d25304fc406b1d91104e4f8c69195fad9f80/R/generate_pkg-setup.R#L127-L146).

Beekeeper's current template writer deletes an existing target before writing its replacement. A TODO acknowledges the need for prompting. The inspected path offers no merge that preserves manual changes. Its request-object design is useful evidence for customization; its regeneration behavior should not be adopted for specmill's client-owned helpers. See [template writer](https://github.com/api2r/beekeeper/blob/05e9d25304fc406b1d91104e4f8c69195fad9f80/R/generate_pkg-template.R#L27-L42).


## ComptoxR

Inspected the clean local checkout at `2208f4341e33cc05e954c3a536826677c3cfb71b`. ComptoxR owns two shared transport functions, `generic_request()` and `generic_chemi_request()`, with different conventions. The former covers batching, authentication, multiple pagination strategies, JSON and newline-delimited text bodies, and response conversion. The latter builds chemical payloads and also accepts an explicit body that bypasses its normal payload synthesis. See [shared helpers](https://github.com/seanthimons/ComptoxR/blob/2208f4341e33cc05e954c3a536826677c3cfb71b/R/z_generic_request.R).

Three concrete customization examples:

- `ct_chemical_search_equal_bulk()` requests `body_type = "raw_text"`. The shared helper joins identifiers with newlines and sends `text/plain`, rather than a JSON array. See [wrapper](https://github.com/seanthimons/ComptoxR/blob/2208f4341e33cc05e954c3a536826677c3cfb71b/R/ct_chemical_search_equal.R) and the helper's POST body branch.
- `chemi_search_pre_request()` resolves search input to MOL, assembles a search body and options under `data$request`; `chemi_search()` passes these to `generic_chemi_request()`. Hook-specific validation remains in the client. See [search hooks](https://github.com/seanthimons/ComptoxR/blob/2208f4341e33cc05e954c3a536826677c3cfb71b/R/hooks_search.R) and [search wrapper](https://github.com/seanthimons/ComptoxR/blob/2208f4341e33cc05e954c3a536826677c3cfb71b/R/chemi_search.R).
- `descriptor_refresh_request()` chooses method, endpoint, server, content type, and payload shape for aggregate versus dedicated descriptor routes. For bulk aggregate calls it includes chemical identifier type, format, and engine; dedicated bulk requests use their own shape. See [descriptor hooks](https://github.com/seanthimons/ComptoxR/blob/2208f4341e33cc05e954c3a536826677c3cfb71b/R/hooks_descriptors.R#L424-L491) and [RDKit wrapper](https://github.com/seanthimons/ComptoxR/blob/2208f4341e33cc05e954c3a536826677c3cfb71b/R/chemi_rdkit.R).

These are source-inspected client adaptations, not live-service verification. They establish why a client must retain control over both hook shaping and its shared helper. They do not establish that these helpers originated from a specmill template.

## Specmill and proposed direction for issue 39

At `071267df1118aa71ef68e6f68f1043887742c464`, initialization reads the request template and substitutes client settings into `R/api_request.R`. Multi-API initialization creates individually named helpers. Normal generation preserves client ownership. See [initialization](https://github.com/seanthimons/specmill/blob/071267df1118aa71ef68e6f68f1043887742c464/R/initialization.R), [multi-API initialization](https://github.com/seanthimons/specmill/blob/071267df1118aa71ef68e6f68f1043887742c464/R/multi-api.R), and [upgrade guidance](https://github.com/seanthimons/specmill/blob/071267df1118aa71ef68e6f68f1043887742c464/README.md).

The current default helper builds, performs, and parses in one function. Its dry-run environment flag returns the prepared httr2 request, but this is not the same public request-constructor interface that beekeeper generates. See [template](https://github.com/seanthimons/specmill/blob/071267df1118aa71ef68e6f68f1043887742c464/inst/templates/request.R).

Recommendation, pending user agreement: retain an editable client-owned baseline helper, preserve custom helpers and hook mappings, and make issue 39 an advisory comparison workflow. For a known scaffold baseline, distinguish local customization from upstream template changes. For an independently authored helper, report no known scaffold baseline and provide reference material without implying an upgrade is required. Template divergence is not itself a defect. Keep application of changes manual; accepting an argument does not prove its behavior.

Illustrative upgrade scenario: a client has added newline-delimited text handling while a newer template fixes timeout handling. Show the timeout change and preserve the client's body branch; do not propose replacing the entire helper as the default resolution. Record baseline provenance for new scaffolded helpers, with enough baseline content or recoverable identity to make the comparison meaningful.

Separating request construction from execution is a distinct possible improvement inspired by beekeeper. It would enable ordinary httr2 modifiers before execution, but is not required to implement provenance or comparison. No new hook stage, runtime dependency, automatic merger, or helper rewrite is proposed by this research alone.
