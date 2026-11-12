# Bundled validation schemas

Official JSON Schemas used by `validate_schema()`. Files are byte-identical to
upstream; the two documented rewrites below are applied at load time. All are
Apache-2.0 licensed by the OpenAPI Initiative.

| File | Source | SHA-256 |
|---|---|---|
| `swagger-2.0.json` | `https://raw.githubusercontent.com/OAI/OpenAPI-Specification/cb37ec78d088430b51fb6610257b2534701c6133/_archive_/schemas/v2.0/schema.json` | `b36871c8016292c5e66dd3b203e69aeff98bfef97e0b3c67c1909036095586a5` |
| `openapi-3.0.json` | `https://spec.openapis.org/oas/3.0/schema/2021-09-28` | `7a0db7311a69d8b7f2505f59c5d4cbb58539a0961df0c05724a07538014822cf` |
| `openapi-3.1.json` | `https://spec.openapis.org/oas/3.1/schema/2022-10-07` | `da01ba28852cac0de53893797cb8d1942bc3b05084f526dcc216717dec314ed0` |
| `openapi-3.1-dialect.json` | `https://spec.openapis.org/oas/3.1/dialect/base` | `8a0e89e365dadbebce2921ce6244340c1090e9d544c60d977e9ad6b97a61227b` |
| `openapi-3.1-meta.json` | `https://spec.openapis.org/oas/3.1/meta/base` | `267a88226e64e96dfc8c89dbd7e863160c84715e0fb893ca1d9fbf9f830f1f54` |
| `openapi-3.2.json` | `https://spec.openapis.org/oas/3.2/schema/2026-08-30` | `ec53db6e114b768ff2d273b232bda210f51b70c5e57d57ac8daf7e8496a6e073` |
| `openapi-3.2-dialect.json` | `https://spec.openapis.org/oas/3.2/dialect/2026-02-26` | `9375b7042aa0b01848403f0a9ebf12a3425e01a9e24337ce12624f10fea73833` |
| `openapi-3.2-meta.json` | `https://spec.openapis.org/oas/3.2/meta/2026-02-26` | `f444d02ef7d36f30293983fad8118c823a3c70a49a8e5aa6f1afe21215e35417` |

## OAS 3.1 and 3.2 dialect rewrite

`openapi-3.1.json` and `openapi-3.2.json` leave Schema Objects open through
`"$dynamicRef": "#meta"`; the upstream `schema-base` document binds that anchor to the OAS dialect. The
bundled ajv resolves that binding incorrectly and rejects valid schemas, so the
loader replaces each `"$dynamicRef": "#meta"` with a static `$ref` to the
dialect. This applies the default dialect only; documents declaring another
`jsonSchemaDialect` are validated against the default one.

## OAS 3.2 `contains` rewrite

`openapi-3.2.json` limits a parameter list to one `querystring` parameter with
`contains`, `minContains: 0` and `maxContains: 1`. The bundled ajv rejects such
an array when no item matches. `validate.js` restates the rule as
`not: {contains, minContains: 2}`, which accepts and rejects the same arrays.

To update, download the sources above, compare hashes, and rerun
`Rscript tests/schema-validation.R` and `Rscript tests/openapi-32.R`.

## Error reporting

`validate.js` is specmill code, not upstream. For Swagger 2.0 and OAS 3.0 it
compiles a second, diagnostic copy of the schema in which each `oneOf` keyed
by `$ref`, `in`, `type` or a similar enum property becomes an `allOf` of
guarded branches, so a failing instance reports only the branch it selects.
The unmodified schema still decides validity; the copy only words the
findings. OAS 3.1 and 3.2 already select branches with `if`/`then`.
