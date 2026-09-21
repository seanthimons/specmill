# GET-body source-contract review

Reviewed 2026-09-12 for #16. All ten historical declarations remain unresolved.
No service operation was invoked. Exact snapshot SHA-256 hashes and operation
pointers are recorded in [operations.csv](operations.csv); append `/requestBody`
to each pointer for the declaration reviewed here.

| API | GET path | Declared body |
| --- | --- | --- |
| chet | `/admin/errorreport` | Optional JSON open object |
| chet | `/admin/login` | Optional JSON open object |
| chet | `/admin/register` | Optional JSON open object |
| chet | `/admin/resolve` | Optional JSON open object |
| chet | `/auth/login` | Optional form-urlencoded open object |
| chet | `/auth/register` | Optional form-urlencoded open object |
| chet | `/auth/report` | Optional form-urlencoded open object |
| chet | `/chemicals/chemdelete` | Optional JSON open object |
| chet | `/chemicals/chemical_DL` | Optional JSON open object |
| resolver | `/api/resolver/ghs-list-count` | JSON object with values that are arrays of arrays of strings; required omitted |

The [EPA CheT guide](https://www.epa.gov/comptox-tools/chemical-transformations-database-chet-user-guide)
documents a browser interface, including administrative tools and chemical-list
exports. It does not establish the HTTP methods or body encodings of these nine
routes. Names such as `login`, `chemdelete`, and `chemical_DL` do not establish
safe request semantics or justify converting GET to POST.

The adjacent ComptoxR `apis/chemi-resolver.yml` maps the resolver GET to a
generated client with empty inputs and separately maps a POST at the same path.
That is downstream configuration, not controller evidence: it cannot establish
that dropping the GET body is correct or that callers should use POST instead.
No service-owned controller or independently documented request was found in
the scoped local and public-source review.

The [OpenAPI 3.0 Operation Object](https://spec.openapis.org/oas/v3.0.3.html#operation-object)
limits requestBody support to methods with defined body semantics. This is a
standards constraint, not evidence of what these particular services accept.
These documents must not be repaired by guessing a verb, moving inputs to query
parameters, or treating an HTTP 200 as acceptance of the body.

For every row, the missing evidence is a service-owned controller signature or
published request example specifying method, media type, accepted fields,
requiredness, and whether the body is consumed. The intended wire shape remains
unknown. Route any verified parameter correction to #8 and any new body encoding
to #9, with a minimal offline transport assertion using #7 infrastructure.

At the time of the original review, parsing could accept these declarations after the JSON/form work. That is
not source-contract acceptance. The ledger retains an explicit review diagnostic
even where the parser reports `selected`. No source override is justified by
the evidence gathered here.

## Resolver follow-up for #29

Reviewed 2026-09-21. Final disposition: unsupported as declared; review complete.
Retain the `request_body_method` diagnostic for
`GET /api/resolver/ghs-list-count`. Provide no operation-level media override
or replacement method. The service's body semantics remain unresolved.

The user reports that Swagger UI refuses to execute this request because a
GET/HEAD method cannot have a body. This matches the
[browser Fetch rule](https://fetch.spec.whatwg.org/#dom-request), which throws
a TypeError before sending a GET or HEAD request with a body. It establishes
a browser interoperability failure, not a server rejection. This observation
was user-reported rather than independently reproduced during this review.
[OpenAPI 3.1](https://spec.openapis.org/oas/v3.1.0.html#operation-object)
permits these declarations while advising against them, so the disposition
is unsupported rather than invalid OpenAPI.

The [current development schema](https://cim-dev.sciencedataexperts.com/api/resolver/api-docs)
declares OpenAPI 3.1.0. Both operations at this path are structurally identical
to the committed transfer ZIP. The schema hashes are:

| Source | SHA-256 |
| --- | --- |
| Archived `resolver.json` | `dc1e9c3cef8a55250ac4dd28d4a0b48c0192a11535472e7c8e6eb550f9023694` |
| Development schema fetched 2026-09-21 | `7e32f9078aee69f1d471f506d80ab98b735f1000f8b3cab765b270ac81fa4004` |

GET operation `ghsListCountGet` declares an optional `application/json` object
whose arbitrary keys contain arrays of arrays of strings. It supplies no
summary, description, request example, or named keys explaining their meaning.
The POST declaration has the same body shape, but that does not establish
equivalent behavior or authorize replacing GET. A focused public search for
the route did not locate a service-owned implementation or request example.
Only the schema URL was requested; neither service operation was invoked.

Since #24, OAS 3.1 GET bodies require an explicit operation media review.
Loading the current working source with `pkgload::load_all()` confirmed that
both archived and development schemas retain the expected review diagnostic.
The existing `tests/capability-audit.R` and `tests/native-transport.R`
acceptance checks passed. They cover method/version guards and generic GET
JSON serialization, but do not establish this endpoint's contract or verify
a resolver policy through configuration reload.

Before approving a policy, obtain service-owned evidence specifying accepted
keys, nested-array meaning, omitted/empty-body behavior, and actual GET body
consumption. Then persist the operation-specific override through the existing
configuration mechanism and assert the method, media type, and exact nested
JSON bytes at localhost after reload. Keep unreviewed operations guarded.

Localhost coverage cannot establish compatibility with deployed proxies or
caches. [RFC 9110 section 9.3.1](https://www.rfc-editor.org/rfc/rfc9110.html#section-9.3.1)
describes GET content as having no generally defined semantics and warns that
implementations can reject it. Origin support alone does not establish
intermediary support. Close #29 as a completed review under its explicit
unresolved-endpoint acceptance option. Policy reload and endpoint-specific
wire checks are not applicable because no policy is implemented. Revisit only
if the service owner supplies a corrected contract or documents an intentional
GET-body interface. No runtime, schema, or client policy changes were made by
this review.
