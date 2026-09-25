# Query contract review: issues #28 and #31

Reviewed 2026-09-21 against the committed transfer ZIP and installed specmill
0.1.4. All six source hashes match the historical proving-ground ledger.
All 20 distinct operations remain blocked and unresolved. No schema, client
policy, parser, or transport was changed. No service operations were called.

| Scope | Operations | Disposition |
| --- | ---: | --- |
| #28 binary-query declarations | 18 | Service-owned file representation and parameter location required |
| #31 nested-query declarations | 13 | Service-owned query encoding required |
| Shared between both issues | 11 | Both contracts must be resolved independently |
| Union | 20 | Keep both issues open |

[query-contracts.csv](query-contracts.csv) records each affected parameter,
requiredness, source pointer, schema reference, request body media, diagnostic,
schema hash, and unresolved disposition. Its operation sets match both issue
bodies. Parameter rows preserve both defects on the eleven overlapping operations.
The older [binary review](BINARY-QUERY.md) covered twelve upload operations;
this ledger includes all eighteen now identified by #28.

## What OpenAPI establishes

All six documents declare OpenAPI 3.1.0. A binary format annotation is not by
itself proof that a schema is invalid. In 3.1, `format` does not determine content
encoding. Nor does it change a parameter's declared query location into a request
body. Treating these declarations as multipart uploads would invent a contract.
See the [OpenAPI file-upload rules](https://spec.openapis.org/oas/v3.1.0.html#considerations-for-file-uploads).

The query defaults are `style: form` and `explode: true`. Those defaults do not
establish the intended encoding of array-valued members inside these objects.
Changing to `deepObject` would not resolve this: its array/object member encoding
is explicitly undefined in the 3.1.1 clarification. See the
[parameter rules](https://spec.openapis.org/oas/v3.1.1.html#parameter-object).

Consequently, these are unresolved wire contracts, not a finding that all twenty
operations are syntactically invalid OpenAPI. Retaining the diagnostics is the
supported outcome under the requirement not to repair uploaded schemas.

## The two Pageable operations

`GET /api/stdizer/protocols/{id}` and `POST /api/stdizer/protocols/{id}`
declare required query `pageable`, referencing `Pageable`. It contains integer
`page` with minimum 0, integer `size` with minimum 1, and `sort: array<string>`.
Neither operation declares a serialization override.

The adjacent ComptoxR helper has a generic Spring-style `page`/`size` pagination
branch. It does not prove how these two operations consume multiple sort entries,
empty values, or encoded delimiters. A framework convention or downstream wrapper
is insufficient evidence for a replacement contract.

A service-owned corrected schema could declare separate page, size, and sort
parameters if that is the actual contract. A declared JSON query parameter is
another possible contract, but it would require separate generator support.
Neither representation is selected here.

## Evidence required before implementation

For #28, establish whether each `files[]` value is an encoded string, identifier,
or uploaded bytes, its actual location and media type, and its relationship to
the accompanying metadata. Seventeen declarations mark `files[]` required;
omitting that parameter is not a general workaround.

For #31, establish exact field names and query bytes for nested members,
including absent, empty, and multiple sort values and delimiter escaping.
Scoped public searches for the operation and request-type names found no
service-owned implementation or replacement contract. The local ComptoxR and
AMOS harmonizer search did not supply one. The subsequent focused #31 check
below also inspected the current development schema.

Existing explicit mappings can accommodate reviewed client contracts, but cannot
establish them. Add no mapping or serializer until the evidence exists. Any later
implemented correction needs exact localhost received-request checks and a
recheck of independent blockers. Both GitHub issues remain open.

## Focused #31 follow-up

On 2026-09-21, the development service returned its
[current Standardizer schema](https://cim-dev.sciencedataexperts.com/api/stdizer/api-docs)
with SHA-256 `94c6a3f303e73f4e4b21b96738f0d41a9f9ae658f291cfb568e3ebb7e6379c74`.
Both target operations' parameter arrays and the referenced `Pageable` schema
are structurally identical to the archived inventory. Neither operation provides
a summary or description supplying the missing encoding. Both still produce
`nested_parameter` diagnostics. The alternate `/api/stdizer/swagger.json` URL
returned HTTP 404. Only schema documents were requested; no protocol endpoint
was invoked.

The adjacent ComptoxR snapshots were also checked. Both operations retain the
same diagnostic in all three files:

| Snapshot | SHA-256 |
| --- | --- |
| `chemi-stdizer-dev.json` | `ec07584f4cd5a0973f4696ee57a8a274eeef1d5e7661a406315a390fae72b0cd` |
| `chemi-stdizer-staging.json` | `ec07584f4cd5a0973f4696ee57a8a274eeef1d5e7661a406315a390fae72b0cd` |
| `chemi-stdizer-prod.json` | `a97a81298e849951aaf85c77fd6ef3352472601e6842a8fd2624651b4b13a3e9` |

Implementation remains dependent on a service-owned controller, corrected schema,
or independently verified query contract. Selecting #31 as the next investigation
does not make an inferred Spring-style encoding acceptable. Keep the two operations
blocked until that dependency is met.

## Reproduce

Run `Rscript dev/review_query_contracts.R` from the repository root after
installing the checkout. It extracts temporary copies, checks their hashes,
checks each affected query parameter independently, verifies all twenty operations
remain absent from generated-operation selection, and regenerates the ledger.
It asserts eighteen binary-query operations, thirteen nested-query operations,
eleven overlaps, and the exact two standalone Pageable keys.
