# Read and compare local schema operations

Extract operation records from local OpenAPI 3.0/3.1 or Swagger 2.0 JSON
or YAML schemas and compare their input contracts.

## Usage

``` r
read_operations(files, policy = list())
compare_operations(old, new)
```

## Arguments

- files:

  Local JSON, YAML, or YML schema paths.

- policy:

  A list with optional service identity, methods allowlist, include
  allowlist of exact METHOD /path keys, path exclude regexes, names
  keyed by METHOD /path, and override_keys for declared operation
  settings. When include is supplied, an operation must match it as well
  as the method and path filters; an empty include selects nothing.
  Unknown included keys are errors.

- old:

  Results from `read_operations`.

- new:

  Results from `read_operations`.

## Value

read_operations() returns named operations and unsupported_operations
plus diagnostic, server_diagnostics, and inventory lists. Every
operation carries server metadata containing a resolved URL or a
selection diagnostic; runtime overrides may resolve the latter.
Effective server changes are reported for review. compare_operations()
returns change records with key, status (added, breaking, review, or
unknown), and reason; no changes returns an empty list.

## Details

The supported subset includes scalar and supported flat array/object
parameters in path, query, header and cookie locations; JSON
scalar/nested-object/array bodies with supported composition and bounded
local recursion; binary string bodies sent as application/octet-stream;
and supported URL-encoded and multipart form bodies. Binary inputs are
raw vectors; multipart files also accept curl::form_file values. JSON is
selected when offered unless policy selects another supported media
type. Same-document and local-file references are resolved; remote
references are not downloaded. Unsupported references, media,
constraints and parameter/body shapes are diagnosed. See the
configuration guide for serialization styles and limits. Structurally
valid unsupported metadata is returned separately for reviewed client
mapping. Effective security requirements and resolved security schemes
are retained for generation. Authentication changes are reported for
review. Generated authentication is enabled by the project's
authentication environment-variable map; existing client helpers remain
responsible when that map is omitted. This is not a full schema
validator. Comparison classifies input changes conservatively and cannot
prove HTTP or response compatibility.

## See also

[Step-by-step
guide](https://seanthimons.github.io/specmill/articles/troubleshooting.html).

## Examples

``` r
schema <- system.file('catalogue/schema.json', package = 'specmill')
parsed <- read_operations(schema)
names(parsed$operations)
#> [1] "get_item"    "list_items"  "create_item" "refresh"    
stopifnot(length(compare_operations(parsed, parsed)) == 0L)
```
