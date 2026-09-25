# Base proving-ground schemas

`specmill-testing-base-schemas.zip` transfers the base schema inputs from the
local `specmill-testing` proving ground to another device without copying its
generated R package or depending on access to the original API servers.
Keeping this snapshot lets development on another device use the same inputs.

Base inputs were captured on 2026-09-19. The archive now contains this README
and 75 JSON files, preserving their paths beneath `specmill-testing/`:

- 31 root-level source files, including existing alternate filenames.
- 27 files in `schema/`, used by the current proving-ground API configurations.
- 17 files in `additional-schemas/epa/`: the 14 ECHO Swagger 2.0 inputs, the
  Envirofacts SDWIS REST source contract, the original AQS Swagger 2.0 schema,
  and a provenance/hash manifest. ECHO/SDWIS were retrieved on 2026-09-21;
  AQS was retrieved on 2026-09-23.

The archive excludes the remaining `additional-schemas/` stress-test collection,
generated R files, caches, credentials, and project configuration. It provides
schema inputs, not a complete runnable copy of the proving ground; generation
policies and API configuration must be recreated separately.

## Transfer

Download the ZIP from the development branch and extract it into a new directory
on the other device. In PowerShell, for example:

```powershell
Expand-Archive -LiteralPath ./specmill-testing-base-schemas.zip -DestinationPath ./schema-transfer
```

The inputs will be under `schema-transfer/specmill-testing/`. Use a new
destination to avoid overwriting a pre-existing proving ground. Preserve the
directory layout for relative schema references.

These files are snapshots of the original API descriptions, not refreshed
downloads or normalized replacements. The collection is intended for schema
parsing and generation work; transferring it does not grant live API access.

## AQS fixture

`specmill-testing/additional-schemas/epa/aqs_api_specification.json` contains the
unaltered [EPA AQS schema](https://aqs.epa.gov/aqsweb/documents/aqs_api_specification.json).
Its source URL, retrieval time, SHA-256, and operation count are recorded in the
EPA manifest. All 79 operations are retained, including unavailable or
account-mutating endpoints; these are parser inputs, not live-test instructions.

The duplicate `qaAnnualPerformanceEvaluationsBySite` operationId on `/bySite`
and `/byPQAO` is intentionally preserved. A direct `read_operations()` call
reports the collision; supply explicit method/path name overrides to continue.
The schema also retains `securityDefinitions` without a root `security` field,
exercising the exact-lookup fix in `aa456bf`.

Run the offline fixture check from the repository root with the current specmill
installed:

```sh
Rscript dev/check_aqs_schema.R
```

The check verifies the archived checksum, the unchanged collision, and parsing
and authentication resolution for all 79 operations without API requests.
