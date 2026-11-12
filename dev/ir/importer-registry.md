# Importer registry

The internal registry introduced for #230 is an explicit list returned by
`importer_registry()`. It has no global mutation or package-load side effects.
Third-party registration is deferred until the import and compatibility contracts
settle; downstream packages should not depend on these internal functions.

Each registered format provides `version`, `detect(path, document)` and
`import(path, policy)`. Detection receives an unresolved JSON/YAML document or
source text and returns one finite confidence in [0, 1]. The highest positive
confidence wins. Equal winners require an explicit format; zero winners produce
an error listing registered formats. An override selects a registered entry and
runs its optional source check. Import returns `list(ir, diagnostics)` and the
registry validates the IR before returning it. Importers own policy interpretation
and must retain source diagnostics; reviewed OpenAPI requests use the existing
lazy review context.

OpenAPI, Swagger, `arcgis-rest`, `google-discovery` and `graphql` are
registered. ArcGIS
uses reviewed local captures; directory discovery expands only local
service-capture paths and retains source diagnostics. Configuration and validation callbacks provide
format-specific metadata without native keys in catalogue/generation modules.

OpenAPI and Swagger are separate detected formats sharing importer version `1`
and the same normalization family. Their existing 3.0, 3.1 and 2.0 generation
limits remain, and OpenAPI 3.2 is read as 3.1 with its new constructs listed
or diagnosed. A registry entry may also provide catalogue metadata, reference
inputs, and a compatibility-record reader. Without a catalogue callback, service
title and server choices come from validated IR. Compatible readers in one family
may merge sources; unrelated families cannot be merged in one service.

`configure_apis()` discovers JSON, YAML, GraphQL, protobuf, WSDL, RAML and API
Blueprint filename extensions. Content detectors recognize OpenAPI/Swagger and
Postman collection metadata. Text signatures identify GraphQL SDL, protobuf,
WSDL namespaces, RAML headers and API Blueprint headers. Recognition does not
provide an importer: other unimplemented formats fail with their detected
name and the supported-format list. Invalid JSON/YAML remains a source parse
error. Future format issues add implementations rather than placeholders that
claim to import them.

An explicit catalogue `format:` can be supplied with the `format` column of
`choices` or maintained in `specmill-apis.yml`. Blank catalogue format means
automatic detection. The format is resolved before the review table is built and
is read-only in the interactive editor. Initialization copies a nonblank override
into API configuration. API `format:` is inherited by groups; flat services may
also set it. `read_operations(..., format = NULL)` exposes the same override.

Catalogue records include `source_format` and `importer_version`. Generation
records those fields per relative schema path under `importers` in ownership
provenance and returns the same provenance in its generation manifest. Different
explicit formats for one source file are rejected. Cassette reference digests
are unchanged.

## Verification

Install the package, then run `Rscript tests/importer-registry.R`. This covers
confidence ties, explicit selection, invalid detectors/IR, independent registry
values, known and unknown formats, catalogue persistence, API configuration and
saved generation provenance. The source-boundary gate permits the registry's
unresolved document load but still forbids native OpenAPI field access there.

`dev/check_registry_output.R` compares with the unchanged #229 baseline. Exactly
seven ownership manifests may change; removing only their added importer object
must restore the original serialized hash. All other reference artifacts must
match as bytes. `dev/check_ir_provenance.R` separately verifies 102 reference
digests. Full package checks remain required for registry changes.

## Detection references

- [OpenAPI root version field](https://spec.openapis.org/oas/v3.1.1.html#openapi-object)
- [Postman collection information](https://learning.postman.com/api-docs/api-reference/collections/create-collection)
- [GraphQL schema language](https://graphql.org/learn/schema/)
- [Protobuf syntax and services](https://protobuf.dev/programming-guides/proto3/)
- [WSDL 1.1](https://www.w3.org/TR/wsdl.html) and [WSDL 2.0](https://www.w3.org/TR/wsdl20/)
- [RAML 1.0](https://github.com/raml-org/raml-spec/blob/master/versions/raml-10/raml-10.md)
- [API Blueprint metadata](https://apiblueprint.org/documentation/specification.html)

## ArcGIS integration

`R/importer_arcgis.R` emits IR directly. `R/ir_records.R` compiles its neutral
request types to the existing request-record/schema contract without creating
OpenAPI documents. The registered ArcGIS entry supplies local directory
discovery, configuration metadata and capture/IR validation. Initialization
includes client-owned ArcGIS protocol callbacks and pagination companions.
See [supplied-case verification](../audits/arcgis/README.md) for the reviewed
service set, offline acceptance and bounded live evidence.

## Retained sources and companions

Each entry names its `artifact` stem and its `companions`. An importer retains
its source as `schema/<artifact>.<extension>`, and `importer_artifact_pattern()`
is the one pattern that single-API and multi-API setup use to find it, so the
generated `dev/init.R` works for every registered format. Protocol companions
(`arcgis`, `discovery`) add client-owned callbacks from
`inst/templates/<companion>.R`, renamed per helper in multi-API clients.

## Google API Discovery integration

`R/importer_discovery.R` reads a local `discovery#restDescription` document and
emits IR directly: methods from nested resources, path and query parameters,
named schemas as source types, an `api_key` scheme for the `key` system
parameter and an `oauth2` scheme for declared scopes. A `pageToken` query
parameter with a `nextPageToken` response member becomes a cursor paging hint,
which initialization writes as editable policy using the `discovery` companion
callback. Reported, not generated: media upload, reserved-expansion paths
without an equivalent `flatPath`, and page tokens carried in a request body.
`tests/importer-discovery.R` covers this against a synthetic document and a
localhost server.

## GraphQL integration

`R/importer_graphql.R` reads a saved introspection result and emits IR with the
`graphql` paradigm: one operation per root query and mutation field, keyed
`query <field>` or `mutation <field>`, with arguments at location `argument` and
every named type as a source type. The binding also carries `method: POST` and
the endpoint `path`, so the compatibility bridge needs no GraphQL-specific
record shape. `graphql_records()` renders each operation's query document from
the reviewed `fields` list (or uses a reviewed `query_document`) and attaches it
to the record; the wrapper renderer sends it with the arguments as variables.
Selection problems are operation diagnostics, never guesses. The `graphql`
companion supplies the response callback. Schema-language files, pagination,
authentication and testing scenarios are not covered yet; operation keys that
are not `METHOD /path` are handled where selection reads them
(`operation_key_route()`), and the wider key audit in #231 remains open.

