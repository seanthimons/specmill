# Bundled validation schemas

Official JSON Schemas used by `validate_schema()`. Files are byte-identical to
upstream; `R/schema_validation.R` applies the one documented rewrite at load
time. All are Apache-2.0 licensed by the OpenAPI Initiative.

| File | Source | SHA-256 |
|---|---|---|
| `swagger-2.0.json` | `https://raw.githubusercontent.com/OAI/OpenAPI-Specification/cb37ec78d088430b51fb6610257b2534701c6133/_archive_/schemas/v2.0/schema.json` | `b36871c8016292c5e66dd3b203e69aeff98bfef97e0b3c67c1909036095586a5` |
| `openapi-3.0.json` | `https://spec.openapis.org/oas/3.0/schema/2021-09-28` | `7a0db7311a69d8b7f2505f59c5d4cbb58539a0961df0c05724a07538014822cf` |
| `openapi-3.1.json` | `https://spec.openapis.org/oas/3.1/schema/2022-10-07` | `da01ba28852cac0de53893797cb8d1942bc3b05084f526dcc216717dec314ed0` |
| `openapi-3.1-dialect.json` | `https://spec.openapis.org/oas/3.1/dialect/base` | `8a0e89e365dadbebce2921ce6244340c1090e9d544c60d977e9ad6b97a61227b` |
| `openapi-3.1-meta.json` | `https://spec.openapis.org/oas/3.1/meta/base` | `267a88226e64e96dfc8c89dbd7e863160c84715e0fb893ca1d9fbf9f830f1f54` |

## OAS 3.1 rewrite

`openapi-3.1.json` leaves Schema Objects open through `"$dynamicRef": "#meta"`;
the upstream `schema-base` document binds that anchor to the OAS dialect. The
bundled ajv resolves that binding incorrectly and rejects valid schemas, so the
loader replaces each `"$dynamicRef": "#meta"` with a static `$ref` to the
dialect. This applies the default dialect only; documents declaring another
`jsonSchemaDialect` are validated against the default one.

To update, download the sources above, compare hashes, and rerun
`Rscript tests/schema-validation.R`.
