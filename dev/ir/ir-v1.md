# API intermediate representation, version 1

Contract for [#228](https://github.com/seanthimons/specmill/issues/228). It also
settles the type model asked for in
[#232](https://github.com/seanthimons/specmill/issues/232), as the IR needs one
to be format-neutral. The internal `importer_openapi(files)` now emits this IR.
Generation still consumes compatibility records while
[#229](https://github.com/seanthimons/specmill/issues/229) migrates the remaining
readers. The registry follows in [#230](https://github.com/seanthimons/specmill/issues/230).

| Artifact | Path |
|---|---|
| Schema (JSON Schema 2020-12) | `inst/ir/ir-v1.schema.json` |
| Field ledger | `inst/ir/field-ledger.csv` |
| Examples (GraphQL, ArcGIS, type mappings) | `inst/ir/examples/` |
| Validator | `validate_ir()` in `R/ir.R` (internal) |
| Checks | `tests/ir.R` |

## OpenAPI importer migration

`importer_openapi(files)` accepts distinct local OpenAPI 3.0/3.1 or Swagger 2
files and no policy argument. It emits source-scoped types, authentication,
servers and normalized operation metadata. Identical duplicate operations merge
using the existing contract checks. Unsupported request operations retain their
transport diagnostics. Native source loading retains the existing version/path
checks; independent source validation remains with `validate_schema()`. Server
diagnostics remain separate from transport blockers.

`read_operations()` now orchestrates policy preparation, native request reading,
and policy finalization. Selection and name resolution live in
`R/operation_policy.R`; native document/request reading and duplicate-response
contract comparison live in `R/importer_openapi.R`. Selection still occurs before
request validation, so excluded malformed operations and excluded invalid name
overrides do not become import failures. Unknown-override handling, collision
messages, supported/unsupported separation and inventory classifications retain
the compatibility reader's behavior.

The policy-free importer calls native normalization directly, without the
client namespace collision check. Distinct route keys can therefore have the
same default R name in IR; `read_operations()` still requires reviewed names or
selection before generating wrappers. This removes the importer's dependency on
the public compatibility entry point.

The policy split is incomplete: reviewed schema corrections and transport
settings still enter the native compatibility view. Making `read_operations()`
an adapter over IR, separating those remaining reviews, and migrating raw-document
access from the other downstream modules remain in #229. The 411-artifact
baseline must keep matching through those changes. The importer remains internal
until the registry and policy split land.

The type mapper traverses structural slots only and preserves source spelling
under `native.schema`. It emits named refs, recursive records, scalars, enums,
lists, maps, unions and intersections. Unrepresented assertions are marked
`lossy`, including unsupported keywords, boolean false schemas and unresolved
references. Those markers describe representational limits; they do not make an
operation supported by the existing renderer. `int64_precision` retains the IR's
warning about the later R representation. Defaults, examples and explicit null
values remain data. The current scalar mapping preserves bounds, width,
nullability and binary encoding where represented in the v1 contract.

`Rscript tests/importer-openapi.R` checks the installed package, including the
shipped corpus, YAML/JSON inputs, recursion, source-scoped duplicate merging,
transport diagnostics and literal data that resembles schema keywords. The
standalone generation golden gate is documented in
[`dev/audits/ir-golden/README.md`](../audits/ir-golden/README.md).

## Shape

```text
ir
  ir_version  "1"
  paradigm    rest | graphql | soap | jsonrpc | grpc | event | mixed
  service     {id, title, description, version}
  sources[]   {id, format, format_version, importer_version, file, hash{algorithm,value},
               servers[], auth_schemes{id -> scheme}, types{name -> type}, native}
  operations[]
              {key, id, name, native_name, summary, description, deprecated, tags,
               paradigm, source, binding, server, parameters[], body, responses[],
               errors[], security[], pagination, transport_diagnostics[],
               source_location, native}
  diagnostics[]
```

Decisions behind the shape:

- **Several sources per service.** `read_operations()` takes a list of files
  (`R/operations.R:98`). Hash, format version, auth schemes and types belong to a
  file, and two files can reuse a scheme id with different meaning. Operations name
  their source, and a reference resolves inside it.
- **Paradigm.** Every operation carries its own. The top-level value is a summary,
  or `mixed`. `binding` holds the wire coordinates: `method` and `path` for REST,
  `operation_type` and `field` for GraphQL, and so on. Only `rest` is exercised by
  an importer today; the others set the shape their issues must keep or amend.
- **Identity.** `key` is opaque to consumers. REST keeps `METHOD /path`, which is
  what policy files use. [#231](https://github.com/seanthimons/specmill/issues/231)
  decides keys for other paradigms.
- **Raw data stays out of the way.** `native` holds format-specific data for
  lossless round trips. Generators must not read it. `source_operation` is the one
  OpenAPI-only field on today's records, and it maps to `native`.
- **Corrections are not IR.** Reviewed corrections and policy settings sit on top of
  importer output. The ledger classes them `policy`.
- **Identity across sources.** `id` and `key` are unique across the whole IR. Today
  `read_operations()` merges the same operation found in several files when their
  contracts match (`R/operations.R:1093-1158`), and the importer must do the same
  and name the chosen file in `source`. A key that differs between files is an
  importer error, not two IR operations.
- **Hashes.** `source_hash` is md5 today and validation reports use sha256, so
  `hash.algorithm` is explicit.

### Serialization

The IR is JSON-shaped data in R lists. A named list is an object and an unnamed
list is an array. An empty object is `setNames(list(), character())`. A
length-one vector is a scalar, so a one-element array must be `list(x)`.
`validate_ir()` serializes with `jsonlite::toJSON(auto_unbox = TRUE, null = 'null',
na = 'null')` and also accepts a path to an IR JSON file.

### Validation

`validate_ir()` returns a character vector of problems, empty when valid. The
JSON Schema checks structure, including per-paradigm `binding` keys and the
`api_key` location rule. R then checks what a schema cannot: source ids are
unique, operation `key` and `id` are unique across sources, an operation's source exists, security
requirements name declared schemes, every `ref` type, `implements` name and discriminator mapping target resolves in its source, and
operation paradigms agree with a non-`mixed` document.

## Types

Types are a tagged union on `kind`. Any node can carry `title`, `description`,
`nullable`, `default`, `const`, `example`, `examples`, `deprecated`, `read_only`, `write_only`,
`native_type` (the source spelling), `native_format`, `lossy` (codes for what the
mapping dropped) and `source_location`. A parameter's default lives on its type.

| kind | Fields | Purpose |
|---|---|---|
| `any` | | Unconstrained value |
| `scalar` | `name`, `bits`, `signed`, `precision`, `scale`, `encoding`, `media_type`, `minimum`, `maximum`, `exclusive_minimum`, `exclusive_maximum`, `multiple_of`, `min_length`, `max_length`, `pattern` | `string`, `boolean`, `integer`, `float`, `decimal`, `bytes`, `date`, `time`, `datetime`, `duration`, `uuid`, `uri`, `null` |
| `enum` | `base`, `values[{value,name,description,deprecated}]` | Named or literal choices |
| `list` | `items`, `min_items`, `max_items`, `unique` | Ordered collection |
| `map` | `key`, `value`, `min_properties`, `max_properties` | Open string-keyed or typed-key dictionary |
| `record` | `fields[]`, `additional`, `pattern_properties`, `abstract`, `implements` | Object, message, input object, complex type |
| `union` | `mode`, `variants[]`, `discriminator` | `oneOf` / `anyOf`, GraphQL union, protobuf `oneof`, XSD `choice` |
| `intersection` | `members[]` | `allOf` |
| `ref` | `name` | Named type in the declaring source; recursion allowed |

Nullability is a flag on any node, so the OpenAPI 3.0 `nullable`, the 3.1 `null`
type, a GraphQL nullable field, and protobuf `optional` all land on one spelling.

### Mapping tables

The mappings below are fixture-covered by `inst/ir/examples/type-mappings.json`
(protobuf, XSD, EDM and recursion) and `graphql.json`. Only the OpenAPI row is
read by an importer today; the others are the contract their importers must meet.

| Source construct | IR | Notes / `lossy` code |
|---|---|---|
| JSON Schema `string`, `format: date-time` | `scalar datetime` | `native_format` keeps the original |
| JSON Schema `integer`, `format: int64` | `scalar integer, bits 64` | `int64_precision` |
| JSON Schema `number` | `scalar float` | |
| JSON Schema `string`, `format: byte` / `binary` | `scalar bytes` (`base64` / `raw`) | |
| JSON Schema `enum` | `enum` | |
| JSON Schema `type` array with `null`, or `nullable: true` | `nullable: true` | |
| JSON Schema `oneOf` / `anyOf` / `allOf` | `union` / `union` / `intersection` | `discriminator` carries over |
| JSON Schema `additionalProperties: <schema>` without `properties` | `map` | Both present: `record.additional` |
| JSON Schema `const`, `examples` | `const`, `examples` annotations | |
| JSON Schema `not`, `prefixItems`, `if` / `then` | `any` | `unsupported_keyword` |
| protobuf `int64` / `uint64` | `scalar integer, bits 64` | `int64_precision` |
| protobuf `int32`, `uint32`, `sint32` | `scalar integer, bits 32, signed` as declared | |
| protobuf `float` / `double` | `scalar float, bits 32 / 64` | |
| protobuf `bytes` | `scalar bytes, base64` | |
| protobuf `enum` | `enum, base integer` | Values keep `name` and number |
| protobuf `oneof` | `union one_of` | |
| protobuf `map<K,V>` | `map` | |
| protobuf `repeated` | `list` | |
| protobuf `optional` | `nullable: true` | |
| protobuf well-known `Timestamp` / `Duration` | `datetime` / `duration` | |
| GraphQL `Int` / `Float` / `String` / `Boolean` / `ID` | `integer 32` / `float` / `string` / `boolean` / `string` | `native_type: ID` |
| GraphQL custom scalar | `scalar` by documented meaning, else `any` | `custom_scalar` |
| GraphQL object, input object | `record` | |
| GraphQL interface | `record, abstract` + `implements` on implementers | |
| GraphQL union | `union one_of`, discriminator `__typename` | |
| GraphQL enum | `enum, base string` | |
| GraphQL non-null `T!` | field `required`, no `nullable` | |
| XSD `xs:string` and facets | `scalar string` with `min_length`, `max_length`, `pattern` | |
| XSD `xs:decimal` | `scalar decimal` with `precision`, `scale` | |
| XSD `xs:int`, `xs:long`, `xs:integer` | `integer` with `bits` 32 / 64 / none | |
| XSD `xs:dateTime`, `xs:date`, `xs:time`, `xs:duration` | `datetime`, `date`, `time`, `duration` | |
| XSD `xs:base64Binary` / `xs:hexBinary` | `bytes` with `encoding` | |
| XSD `xs:choice` | `union one_of` | |
| XSD restriction with `xs:enumeration` | `enum` | |
| XSD `xs:complexType` / `xs:extension` | `record` / `intersection` | |
| XSD `minOccurs=0` | field `required: false` | |
| XSD `maxOccurs>1` or `unbounded` | `list` | |
| EDM `Edm.String`, `Edm.Boolean`, `Edm.Int32`, `Edm.Int64`, `Edm.Double`, `Edm.Decimal` | `string`, `boolean`, `integer 32`, `integer 64`, `float 64`, `decimal` | `int64_precision` for `Edm.Int64` |
| EDM `Edm.Guid`, `Edm.Date`, `Edm.DateTimeOffset`, `Edm.TimeOfDay`, `Edm.Duration` | `uuid`, `date`, `datetime`, `time`, `duration` | |
| EDM `Edm.Binary` | `bytes, base64url` | |
| EDM complex type / entity type | `record` | Navigation properties stay in `native` |
| EDM enum type | `enum` | |
| EDM `Collection(T)` | `list` | |
| EDM geography / geometry | `any` | `geography_type` |

### R-side representation (proposal, not implemented)

The IR records what the API says. How R values look is a generator concern, and
the choices below are the default each format's importer issue should follow.
Dependency questions (`bit64`, `hms`) belong to
[#253](https://github.com/seanthimons/specmill/issues/253).

| IR | R value |
|---|---|
| `integer`, 32 bits or fewer, signed | `integer` |
| `integer`, 64 bits or unsigned 32 | `numeric`; `character` input keeps full precision beyond 2^53 |
| `decimal` | `numeric`; `character` when scale or precision exceeds a double |
| `bytes` | `raw` vector; encoding happens at the wire |
| `date` / `datetime` | `Date` / `POSIXct` in UTC |
| `time`, `duration`, `uuid`, `uri` | `character` |
| `enum` | `character` of the name; integer enums also take the number |
| `list` | vector for scalars, `list` otherwise |
| `record`, `map` | named `list` |
| `union` | tagged `list(tag = '<variant>', value = ...)` |
| `any` | the parsed value |

## Auth, errors, pagination

- **Auth schemes** use neutral kinds (`api_key`, `http_basic`, `http_bearer`,
  `oauth2`, `openid_connect`, `mutual_tls`, `session_token`, `custom`). The ArcGIS
  `token` flow is `session_token`. Per-transport injection stays with
  [#251](https://github.com/seanthimons/specmill/issues/251).
- **Errors** are rules. A status-only rule is an ordinary HTTP error. A `body_path`
  rule covers APIs that fail with a success status, such as the ArcGIS `error`
  object or the GraphQL `errors` array.
- **Pagination** is a hint. Today pagination comes only from policy on the
  `read_operations()` path (`R/endpoint_records.R:64` stubs the spec-side detector),
  and the IR hint changes nothing until
  [#254](https://github.com/seanthimons/specmill/issues/254) settles semantics.
  `more_path` plus `more_when` expresses the ArcGIS `exceededTransferLimit` rule.

## Field ledger

`inst/ir/field-ledger.csv` classifies each field of the operation record,
parameter record, policy additions, return list and diagnostics as `neutral`,
`openapi_only`, `derived`, `policy`, `diagnostic` or `call_context`, with its IR
path. `tests/ir.R` fails when a real record carries a field the ledger lacks, or
when a ledger path does not exist in the schema.

| Class | Meaning |
|---|---|
| `neutral` | Moves to the IR under `ir_path` |
| `openapi_only` | Importer-internal (`source_operation`); lives under `native` |
| `derived` | Recomputed on demand (compatibility columns from `openapi_to_spec()`) |
| `policy` | Reviewed settings layered over importer output; not IR |
| `diagnostic` | Becomes a diagnostic |
| `call_context` | Comes from configuration (service id), not the description |

### Raw-document readers

These read OpenAPI keys outside `read_operations()` and need an IR home before
[#229](https://github.com/seanthimons/specmill/issues/229) can finish.

| Module | Reads | IR home |
|---|---|---|
| `R/configuration-scaffold.R:82-102,332-341` | `paths`, methods, `securitySchemes`, `securityDefinitions`, `security` | `operations`, `auth_schemes`, `security` |
| `R/configuration.R:78-92` | `host`, `basePath`, `servers` | `sources[].servers` |
| `R/schema_reports.R:49-85`, `R/schema_changes.R:3-21` | `paths`, `parameters` | `operations` keys and `parameters` |
| `R/endpoint_records.R:68-111` | `paths`, `parameters` | Dissolves once the importer owns the operation shape |
| `R/response_corrections.R:79-115` | `paths[[path]][[method]]` | `operations[].responses` |
| `R/deferral.R:10-13` | `paths` | `operations` |
| `R/schema_validation.R:15-46` | `paths`, `parameters`, `requestBody` refs | Stays OpenAPI-only: validates the source document |
| `R/test_proposals.R:455-464` | `openapi`, `components$schemas`, `definitions` | `sources[].types` |
| `R/api-catalogue.R:255,272` | `info.title`, server | `service.title`, `sources[].servers` |
| `R/input_schema.R:28,91`, `R/context.R:180`, `R/body_shapes.R:113` | `openapi` version checks | `sources[].format_version` or the type tree |
| `R/parser.R:329`, `R/diff.R` | whole document (`openapi_to_spec()`) | A second ingestion path used by diff and endpoint records; the importer should replace it |

## Findings along the way

- Version gates disagree. The catalogue gate (`R/api-catalogue.R:241-244`) and
  `read_operations()` (`R/operations.R:182-185`) accept only 2.0, 3.0 and 3.1, while
  `detect_schema_version()` (`R/schema.R:368-380`) accepts any 2.x or 3.x. #230
  should leave one gate.
- `openapi_to_spec()` is a second ingestion path (`R/parser.R:329`), consumed by diff
  and endpoint records. #229 should retire it.

## Not decided here

- Keys for non-REST paradigms (#231).
- Auth injection and `generateToken` handling (#251).
- Pagination semantics (#254).
- One IR per service versus one per directory. The ArcGIS importer will emit one IR
  per service, and a catalogue of services is a registry question (#230).
- `binding` details beyond `rest` and the ArcGIS-shaped REST usage are provisional.
