# API intermediate representation, version 1

Contract for [#228](https://github.com/seanthimons/specmill/issues/228). It also
settles the type model asked for in
[#232](https://github.com/seanthimons/specmill/issues/232), as the IR needs one
to be format-neutral. The internal `importer_openapi(files)` now emits this IR.
Generation consumes the IR compatibility projection introduced in
[#229](https://github.com/seanthimons/specmill/issues/229). The registry is introduced
in [#230](https://github.com/seanthimons/specmill/issues/230); its internal
contract is documented in [importer-registry.md](importer-registry.md).

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

`read_operations()` now prepares policy, resolves native review settings, builds a
reviewed IR view and adapts its neutral fields into the established R records.
Selection, name resolution and per-operation review lookup live in
`R/operation_policy.R`. The native reader receives a review context rather than
YAML policy. Its setting resolver is lazy: exclusions, route/name decisions,
body/media/path corrections and serialization reviews are evaluated at the same
points as before. Excluded malformed operations therefore remain unvalidated and
earlier failures retain their precedence.

The policy-free `importer_openapi()` uses empty reviews and bypasses client
namespace collision checks. Distinct route keys can have the same default R name
in IR; the public reader still requires reviewed names or selection before
client generation. Reviewed corrections are applied in an explicit native view
before IR projection; the source document and its raw validation report remain
unchanged. The importer accepts no policy argument.

`ir_compatibility_records()` projects neutral operation/parameter names,
identities, bindings, servers, security, source provenance and body controls.
An opaque compatibility sidecar retains JSON Schema fragments, derived parser
columns, policy provenance, character diagnostics and R representation details
until #279. The adapter never reads native format bags or JSON Schema keywords.
This preserves full R records, including NULL fields, empty-list distinctions
and schema attributes, rather than relying on a lossy type round trip.

Request records, named types and provenance use the same cached source snapshot;
the IR projection does not re-read documents after native normalization. Invalid
unused metadata and broken response/header references produce explicit lossy
projection nodes, while legacy request behavior and separate source validation
remain intact. A malformed unused authentication kind stays opaque as `custom`.
No request validation is bypassed by these metadata fallbacks.

Native configuration, catalogue, server, report and compatibility readers now
live in the importer. Their callers receive source metadata or compatible records
through importer accessors; source validation and loading remain explicit
exceptions. JSON Schema fragment consumers remain tracked in #279. The
411-artifact output baseline and 102 referenced-contract provenance digests
protect this boundary. The importer and registry remain internal while the public extension contract settles.

`Rscript tests/ir-compatibility.R` verifies exact R-record parity, neutral-field
projection, lazy reviews, source snapshots and invalid unused metadata.
`Rscript tests/importer-accessors.R` additionally checks metadata callback order,
cached snapshots, deferred server inspection and explicit client parser context.

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
  contracts match (`openapi_merge_duplicate_records()` in the importer)
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
(protobuf, XSD, EDM and recursion) and `graphql.json`. The OpenAPI mappings and ArcGIS field mappings are read by importers today;
the other rows remain the contract their importers must meet. ArcGIS import
and supplied-case evidence are documented in
[the ArcGIS audit](../audits/arcgis/README.md).

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
  `read_operations()` path (`endpoint_records()` in the importer stubs the
  spec-side detector),
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

### Native document boundary

`R/importer_openapi.R` owns OpenAPI and Swagger interpretation. Reviewed
operation records pass through the IR and its compatibility projection before
downstream generation. The compatibility sidecar retains JSON Schema fragments
until [#279](https://github.com/seanthimons/specmill/issues/279) converts the
post-import consumers to the type tree.

| Reader | Ownership |
|---|---|
| Operation parsing, body/parameter normalization, auth and server selection | Importer implementation |
| Configuration proposals | Importer emits operation metadata through a callback; configuration applies naming and grouping policy |
| Catalogue and initialization | Importer source metadata and lazy server accessors |
| Schema reports, endpoint inventory, deferral fingerprints | Source-backed importer accessors |
| Response validation and referenced-contract provenance | Native accessor in importer; provenance digests frozen separately |
| Legacy `bind_tools()` schema/parser and diff functions | Public names retained; native implementations live in importer |
| Formal schema validation | `R/schema_validation.R` deliberately validates the native document |
| File loading and local reference resolution | `R/schema_document.R` and `R/schema_references.R` are source-loading infrastructure |
| Fixtures, body checks, parameter defaults and documentation | JSON Schema fragment consumers deferred to #279 |

Source `dev/check_importer_boundary.R` and call `check_importer_boundary()` to
check native root-field access and document-loader calls. The source validator
and loader infrastructure are explicit exemptions. The registry may load an
unresolved document for detectors but cannot interpret native OpenAPI fields. The only `definitions` field
exception is the unrelated `loaded$definitions` R function table.

The public legacy `openapi_to_spec()` name is retained for explicit client parser
contexts; its implementation is importer-owned. Version-gate consolidation is
preserved for legacy compatibility: those helpers accept broader 2.x/3.x
versions than the current registered generation and catalogue entry points.

## Not decided here

- Keys for non-REST paradigms (#231).
- Auth injection and `generateToken` handling (#251).
- Pagination semantics (#254).
- One IR per service versus one per directory. The ArcGIS importer will emit one IR
  per service, and a catalogue of services is a registry question (#230).
- `binding` details beyond `rest` and the ArcGIS-shaped REST usage are provisional.
