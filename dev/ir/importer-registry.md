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

OpenAPI and Swagger are separate detected formats sharing importer version `1`
and the same normalization family. Their existing 3.0/3.1 and 2.0 generation
limits remain. A registry entry may also provide catalogue metadata, reference
inputs, and a compatibility-record reader. Without a catalogue callback, service
title and server choices come from validated IR. Compatible readers in one family
may merge sources; unrelated families cannot be merged in one service.

`configure_apis()` discovers JSON, YAML, GraphQL, protobuf, WSDL, RAML and API
Blueprint filename extensions. Content detectors recognize OpenAPI/Swagger and
Postman collection metadata. Text signatures identify GraphQL SDL, protobuf,
WSDL namespaces, RAML headers and API Blueprint headers. Recognition does not
provide an importer: currently unimplemented formats fail with their detected
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
