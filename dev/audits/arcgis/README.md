# ArcGIS supplied-case verification (#269)

Capture retrieval: 2026-11-05 18:32:49 UTC.

Inputs supplied by the maintainer:

- <https://echogeo.epa.gov/arcgis/rest/services>, including ECHO, ECHOGov,
  monitor, Utilities and WQI.
- <https://services.arcgis.com/cJ9YHowT8TU7DUyn/arcgis/rest/services/National_Measured_Conductivity/FeatureServer>

The capture utility reproduced seven supported services and 25 layers/tables in
38 metadata requests. The EPA root also advertised SampleWorldCities. ECHOGov
returned HTML instead of a JSON directory. ECHO/getFacilities and
Utilities/RasterUtilities are GPServer services; Utilities/Symbols is a
SymbolServer. Those four cases remain explicit source diagnostics rather than
being treated as FeatureServer/MapServer inputs or silently omitted.

`tests/fixtures/arcgis/` freezes the reviewed metadata subset: service and layer
URLs, original response hashes, capabilities, limits, fields/domains, query
capabilities and relationships. It contains no feature samples or credentials.
Directory entries refer to local service captures. The importer never fetches
metadata, follows service links, or acquires a token.

`live-queries.csv` records generated-wrapper checks against every supplied
supported layer/table: **25 passed in 48 bounded GET requests**. Each of the 23
paging-capable layers was sampled with two requests of two records. The two
monitor services explicitly disable pagination; their wrappers omit paging
controls and were checked with an object-ID filter limiting the result to at
most two records. No edits, token acquisition or other mutating requests were
sent to live services. This samples request/paging behavior; it does not certify
complete downloads or stable data contents.

## Offline acceptance

After installing this checkout, run `Rscript tests/importer-arcgis.R`. It imports
all seven frozen services and expands the directory with four diagnostics. A
localhost FeatureServer validates query offsets 0, 2 and 4, including an empty
middle page whose transfer-limit flag is true. It checks the caller's page-size
stride, a renamed size argument, single-page reads, safe HTTP-200 error handling,
form edits and query-token injection. Editing/protected metadata is synthetic;
those requests only reach localhost. It also generates a client from the EPA
directory, verifies idempotence and rejects conflicting captured layer IDs and
respects explicit operation declarations. Capture integrity and IR validation run by default. Empty directories and
unsupported capture versions fail with explicit messages.

`dev/check_registry_output.R` still recovers every #229 reference byte after
removing only #230's additive importer provenance from seven ownership manifests.
`dev/check_ir_provenance.R` still verifies 102 cassette reference digests.
Existing OpenAPI/Swagger request contracts remain unchanged.

## Reproduce the live sample deliberately

The following is development tooling, separate from routine tests. Start with a
new or empty directory, capture and review metadata, initialize the reviewed
catalogue as described in the configuration guide, and generate the client.

```r
source('dev/capture_arcgis.R')
capture_arcgis(c(
  'https://echogeo.epa.gov/arcgis/rest/services',
  'https://services.arcgis.com/cJ9YHowT8TU7DUyn/arcgis/rest/services/National_Measured_Conductivity/FeatureServer'
), output = '/path/to/client/captures')

source('dev/check_arcgis_cases.R')
check_arcgis_cases(
  '/path/to/client',
  capture_index = '/path/to/client/captures/directory.json',
  output = '/path/to/results.csv'
)
```

The live checker assumes the default operation-ID naming written by
initialization. Source changes or unavailable services require review; do not
replace frozen fixtures just to accept a mismatch.

## Boundaries

Only captured MapServer/FeatureServer services and their advertised query,
related-record, edit and identify capabilities are mapped. Explicit
`supportedOperations` constrains emission. Unsupported field types retain native
spelling and lossy markers. Dates retain their epoch-millisecond wire value;
geometry and edit JSON text are not automatically converted to spatial objects.
Editing rights govern the form fields exposed. Root ArcGIS errors raise with a
service code without copying server text; per-edit failures remain in edit
results for caller inspection.

A token-capable server can host public services. Only reviewed
`requires_token: true` opts a capture into token requirements. The IR records a
session-token query scheme and captured generateToken endpoint/flow. Acquisition
and refresh stay client-owned (#251). Imported pagination becomes editable,
explicit YAML policy; broader paradigm-aware inference remains #254. The
transitional neutral-type-to-request-schema bridge remains part of #279's
renderer migration, rather than manufacturing OpenAPI descriptions for ArcGIS.

## Protocol references

- [Feature layer query](https://developers.arcgis.com/rest/services-reference/enterprise/query-feature-service-layer/)
- [Map layer query](https://developers.arcgis.com/rest/services-reference/enterprise/query-map-service-layer/)
- [Related records](https://developers.arcgis.com/rest/services-reference/enterprise/query-related-records-feature-service/)
- [Layer edits](https://developers.arcgis.com/rest/services-reference/enterprise/apply-edits-feature-service-layer/)
- [Map identify](https://developers.arcgis.com/rest/services-reference/enterprise/identify-map-service/)
- [Generate token](https://developers.arcgis.com/rest/services-reference/enterprise/generate-token/)

## Related-record paging observation

The WQI MapServer omitted `exceededTransferLimit` for a requested related-record
page of two rows, although offset 2 returned two more distinct rows. Treating an
absent flag as completion would truncate those results. The generated related
completion callback honors an explicit flag and, when it is absent, probes again
after a full page of related records. It counts records across groups, rather
than counting parent groups. The offline regression uses multiple parent groups
and an omitted flag. The corresponding live check traversed two bounded pages
and returned four related records. Related groups are preserved across pages;
callers can explicitly regroup them by parent ID. A separate generated
SampleWorldCities identify call returned one result.
