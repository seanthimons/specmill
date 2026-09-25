# Build diagnostics

Parser-blocked operations were not generated. Source defects require a corrected upstream schema.
Missing request contracts require service-owned evidence. No schema repairs or encoding guesses were applied.
Capability gaps describe generator limitations; they do not establish that a schema is invalid.
Only the first parser blocker per operation is reported; correcting it may expose another.
Offline smoke passes do not establish live service compatibility.

- Document OAI/learn.openapis.org/main/examples/v3.1/webhook-example.yaml [parser_error]: Missing paths: artifacts/corpus-2026-09-21/additional-schemas/OAI/learn.openapis.org/main/examples/v3.1/webhook-example.yaml
- Document OAI/learn.openapis.org/main/examples/v3.2/3.2-tags-example.yaml [parser_error]: Unsupported schema version in artifacts/corpus-2026-09-21/additional-schemas/OAI/learn.openapis.org/main/examples/v3.2/3.2-tags-example.yaml
- Document json-schema-org/JSON-Schema-Test-Suite/main/tests/draft2020-12/oneOf.json [parser_error]: Unsupported schema version in artifacts/corpus-2026-09-21/additional-schemas/json-schema-org/JSON-Schema-Test-Suite/main/tests/draft2020-12/oneOf.json
- Document json-schema-org/JSON-Schema-Test-Suite/main/tests/draft2020-12/anyOf.json [parser_error]: Unsupported schema version in artifacts/corpus-2026-09-21/additional-schemas/json-schema-org/JSON-Schema-Test-Suite/main/tests/draft2020-12/anyOf.json
- Document json-schema-org/JSON-Schema-Test-Suite/main/tests/draft2020-12/ref.json [parser_error]: Unsupported schema version in artifacts/corpus-2026-09-21/additional-schemas/json-schema-org/JSON-Schema-Test-Suite/main/tests/draft2020-12/ref.json
- Document json-schema-org/JSON-Schema-Test-Suite/main/tests/draft2020-12/unevaluatedProperties.json [parser_error]: Unsupported schema version in artifacts/corpus-2026-09-21/additional-schemas/json-schema-org/JSON-Schema-Test-Suite/main/tests/draft2020-12/unevaluatedProperties.json

Operation failures or blockers: 1338

- OpenAPITools/openapi-generator/master/modules/openapi-generator/src/test/resources/3_0/composed-schemas.yaml: `POST /file` [schema_defect]: Invalid input schema type
  Source: `#/paths/~1file/post/requestBody/content/application~1json/schema/properties/file/allOf/0/type`
  Verify the source contract and correct the schema or use an explicitly retained implementation; do not guess a replacement.
- OpenAPITools/openapi-generator/master/modules/openapi-generator/src/test/resources/3_0/petstore-with-fake-endpoints-models-for-testing.yaml: `POST /fake` [capability_gap]: Binary form fields require multipart/form-data
  Source: `#/paths/~1fake/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- OpenAPITools/openapi-generator/master/modules/openapi-generator/src/test/resources/3_0/petstore-with-fake-endpoints-models-for-testing.yaml: `PUT /fake/body-with-binary` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1fake~1body-with-binary/put/requestBody`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/account` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1account/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/account_links` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1account_links/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/account_sessions` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1account_sessions/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/accounts` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1accounts/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/accounts` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1accounts/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/bank_account`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/accounts/{account}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1accounts~1{account}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/accounts/{account}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1accounts~1{account}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/business_profile/properties/support_url`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/accounts/{account}/bank_accounts` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1accounts~1{account}~1bank_accounts/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/bank_account`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/accounts/{account}/bank_accounts/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1accounts~1{account}~1bank_accounts~1{id}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/accounts/{account}/bank_accounts/{id}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1accounts~1{account}~1bank_accounts~1{id}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/accounts/{account}/capabilities` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1accounts~1{account}~1capabilities/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/accounts/{account}/capabilities/{capability}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1accounts~1{account}~1capabilities~1{capability}/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/accounts/{account}/capabilities/{capability}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1accounts~1{account}~1capabilities~1{capability}/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/accounts/{account}/external_accounts` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1accounts~1{account}~1external_accounts/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/accounts/{account}/external_accounts` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1accounts~1{account}~1external_accounts/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/bank_account`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/accounts/{account}/external_accounts/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1accounts~1{account}~1external_accounts~1{id}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/accounts/{account}/external_accounts/{id}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1accounts~1{account}~1external_accounts~1{id}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/accounts/{account}/login_links` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1accounts~1{account}~1login_links/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/accounts/{account}/people` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1accounts~1{account}~1people/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/accounts/{account}/people` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1accounts~1{account}~1people/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/additional_tos_acceptances/properties/account/properties/user_agent`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/accounts/{account}/people/{person}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1accounts~1{account}~1people~1{person}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/accounts/{account}/people/{person}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1accounts~1{account}~1people~1{person}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/additional_tos_acceptances/properties/account/properties/user_agent`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/accounts/{account}/persons` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1accounts~1{account}~1persons/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/accounts/{account}/persons` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1accounts~1{account}~1persons/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/additional_tos_acceptances/properties/account/properties/user_agent`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/accounts/{account}/persons/{person}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1accounts~1{account}~1persons~1{person}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/accounts/{account}/persons/{person}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1accounts~1{account}~1persons~1{person}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/additional_tos_acceptances/properties/account/properties/user_agent`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/accounts/{account}/reject` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1accounts~1{account}~1reject/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/accounts/{account}/unreject` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1accounts~1{account}~1unreject/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/apple_pay/domains` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1apple_pay~1domains/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/apple_pay/domains` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1apple_pay~1domains/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/apple_pay/domains/{domain}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1apple_pay~1domains~1{domain}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/application_fees` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1application_fees/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/application_fees/{fee}/refunds/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1application_fees~1{fee}~1refunds~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/application_fees/{fee}/refunds/{id}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1application_fees~1{fee}~1refunds~1{id}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/application_fees/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1application_fees~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/application_fees/{id}/refund` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1application_fees~1{id}~1refund/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/application_fees/{id}/refunds` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1application_fees~1{id}~1refunds/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/application_fees/{id}/refunds` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1application_fees~1{id}~1refunds/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/apps/secrets` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1apps~1secrets/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/apps/secrets` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1apps~1secrets/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/apps/secrets/delete` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1apps~1secrets~1delete/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/apps/secrets/find` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1apps~1secrets~1find/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/balance` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1balance/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/balance/history` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1balance~1history/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/balance/history/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1balance~1history~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/balance_settings` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1balance_settings/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/balance_settings` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1balance_settings/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/payments/properties/payouts/properties/automatic_transfer_rules_by_currency`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/balance_transactions` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1balance_transactions/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/balance_transactions/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1balance_transactions~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/billing/alerts` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1alerts/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing/alerts` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1alerts/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/billing/alerts/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1alerts~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing/alerts/{id}/activate` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1alerts~1{id}~1activate/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing/alerts/{id}/archive` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1alerts~1{id}~1archive/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing/alerts/{id}/deactivate` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1alerts~1{id}~1deactivate/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/billing/credit_balance_summary` [capability_gap]: Unsupported parameter serialization; Unsupported nested parameter object
  Source: `#/paths/~1v1~1billing~1credit_balance_summary/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/billing/credit_balance_transactions` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1credit_balance_transactions/get/parameters/4/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/billing/credit_balance_transactions/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1credit_balance_transactions~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/billing/credit_grants` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1credit_grants/get/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing/credit_grants` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1billing~1credit_grants/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/billing/credit_grants/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1credit_grants~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing/credit_grants/{id}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1billing~1credit_grants~1{id}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/expires_at`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing/credit_grants/{id}/expire` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1credit_grants~1{id}~1expire/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing/credit_grants/{id}/void` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1credit_grants~1{id}~1void/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/billing/feedback_options` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1feedback_options/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing/feedback_options` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1feedback_options/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/billing/feedback_options/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1feedback_options~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing/feedback_options/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1feedback_options~1{id}/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing/feedback_options/{id}/deactivate` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1feedback_options~1{id}~1deactivate/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing/meter_event_adjustments` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1billing~1meter_event_adjustments/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing/meter_events` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1meter_events/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/billing/meters` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1meters/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing/meters` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1billing~1meters/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/billing/meters/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1meters~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing/meters/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1meters~1{id}/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing/meters/{id}/deactivate` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1meters~1{id}~1deactivate/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/billing/meters/{id}/event_summaries` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1meters~1{id}~1event_summaries/get/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing/meters/{id}/reactivate` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing~1meters~1{id}~1reactivate/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/billing_portal/configurations` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing_portal~1configurations/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing_portal/configurations` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1billing_portal~1configurations/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/business_profile/properties/headline`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/billing_portal/configurations/{configuration}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing_portal~1configurations~1{configuration}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing_portal/configurations/{configuration}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1billing_portal~1configurations~1{configuration}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/business_profile/properties/headline`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/billing_portal/sessions` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1billing_portal~1sessions/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/charges` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1charges/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/charges` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1charges/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/card`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/charges/search` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1charges~1search/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/charges/{charge}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1charges~1{charge}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/charges/{charge}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1charges~1{charge}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/charges/{charge}/capture` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1charges~1{charge}~1capture/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/charges/{charge}/dispute` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1charges~1{charge}~1dispute/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/charges/{charge}/dispute` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1charges~1{charge}~1dispute/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/evidence/properties/enhanced_evidence`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/charges/{charge}/dispute/close` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1charges~1{charge}~1dispute~1close/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/charges/{charge}/refund` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1charges~1{charge}~1refund/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/charges/{charge}/refunds` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1charges~1{charge}~1refunds/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/charges/{charge}/refunds` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1charges~1{charge}~1refunds/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/charges/{charge}/refunds/{refund}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1charges~1{charge}~1refunds~1{refund}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/charges/{charge}/refunds/{refund}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1charges~1{charge}~1refunds~1{refund}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/checkout/sessions` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1checkout~1sessions/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/checkout/sessions` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1checkout~1sessions/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/branding_settings/properties/background_color`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/checkout/sessions/{session}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1checkout~1sessions~1{session}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/checkout/sessions/{session}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1checkout~1sessions~1{session}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/line_items/items/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/checkout/sessions/{session}/expire` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1checkout~1sessions~1{session}~1expire/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/checkout/sessions/{session}/line_items` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1checkout~1sessions~1{session}~1line_items/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/climate/orders` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1climate~1orders/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/climate/orders` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1climate~1orders/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/climate/orders/{order}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1climate~1orders~1{order}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/climate/orders/{order}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1climate~1orders~1{order}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/beneficiary`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/climate/orders/{order}/cancel` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1climate~1orders~1{order}~1cancel/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/climate/products` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1climate~1products/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/climate/products/{product}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1climate~1products~1{product}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/climate/suppliers` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1climate~1suppliers/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/climate/suppliers/{supplier}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1climate~1suppliers~1{supplier}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/confirmation_tokens/{confirmation_token}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1confirmation_tokens~1{confirmation_token}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/country_specs` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1country_specs/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/country_specs/{country}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1country_specs~1{country}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/coupons` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1coupons/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/coupons` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1coupons/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/coupons/{coupon}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1coupons~1{coupon}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/coupons/{coupon}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1coupons~1{coupon}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/credit_notes` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1credit_notes/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/credit_notes` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1credit_notes/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/lines/items/properties/tax_amounts`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/credit_notes/preview` [capability_gap]: Unsupported parameter serialization; Unsupported parameter array items
  Source: `#/paths/~1v1~1credit_notes~1preview/get/parameters/4/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/credit_notes/preview/lines` [capability_gap]: Unsupported parameter serialization; Unsupported parameter array items
  Source: `#/paths/~1v1~1credit_notes~1preview~1lines/get/parameters/5/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/credit_notes/{credit_note}/lines` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1credit_notes~1{credit_note}~1lines/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/credit_notes/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1credit_notes~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/credit_notes/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1credit_notes~1{id}/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/credit_notes/{id}/void` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1credit_notes~1{id}~1void/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/customer_sessions` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1customer_sessions/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/customers` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1customers/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/address`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/search` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1search/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/customers/{customer}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1customers~1{customer}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/address`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}/balance_transactions` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1balance_transactions/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/customers/{customer}/balance_transactions` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1customers~1{customer}~1balance_transactions/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}/balance_transactions/{transaction}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1balance_transactions~1{transaction}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/customers/{customer}/balance_transactions/{transaction}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1customers~1{customer}~1balance_transactions~1{transaction}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}/bank_accounts` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1bank_accounts/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/customers/{customer}/bank_accounts` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1customers~1{customer}~1bank_accounts/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/bank_account`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}/bank_accounts/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1bank_accounts~1{id}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/customers/{customer}/bank_accounts/{id}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1customers~1{customer}~1bank_accounts~1{id}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/customers/{customer}/bank_accounts/{id}/verify` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1bank_accounts~1{id}~1verify/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}/cards` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1cards/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/customers/{customer}/cards` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1customers~1{customer}~1cards/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/bank_account`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}/cards/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1cards~1{id}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/customers/{customer}/cards/{id}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1customers~1{customer}~1cards~1{id}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}/cash_balance` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1cash_balance/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/customers/{customer}/cash_balance` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1cash_balance/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}/cash_balance_transactions` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1cash_balance_transactions/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}/cash_balance_transactions/{transaction}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1cash_balance_transactions~1{transaction}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}/discount` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1discount/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/customers/{customer}/funding_instructions` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1customers~1{customer}~1funding_instructions/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}/payment_methods` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1payment_methods/get/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}/payment_methods/{payment_method}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1payment_methods~1{payment_method}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}/sources` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1sources/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/customers/{customer}/sources` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1customers~1{customer}~1sources/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/bank_account`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}/sources/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1sources~1{id}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/customers/{customer}/sources/{id}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1customers~1{customer}~1sources~1{id}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/customers/{customer}/sources/{id}/verify` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1sources~1{id}~1verify/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}/subscriptions` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1subscriptions/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/customers/{customer}/subscriptions` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1customers~1{customer}~1subscriptions/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/add_invoice_items/items/properties/tax_rates`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}/subscriptions/{subscription_exposed_id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1subscriptions~1{subscription_exposed_id}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/customers/{customer}/subscriptions/{subscription_exposed_id}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1customers~1{customer}~1subscriptions~1{subscription_exposed_id}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/add_invoice_items/items/properties/tax_rates`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}/subscriptions/{subscription_exposed_id}/discount` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1subscriptions~1{subscription_exposed_id}~1discount/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}/tax_ids` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1tax_ids/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/customers/{customer}/tax_ids` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1tax_ids/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/customers/{customer}/tax_ids/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1customers~1{customer}~1tax_ids~1{id}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/disputes` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1disputes/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/disputes/{dispute}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1disputes~1{dispute}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/disputes/{dispute}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1disputes~1{dispute}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/evidence/properties/enhanced_evidence`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/disputes/{dispute}/close` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1disputes~1{dispute}~1close/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/entitlements/active_entitlements` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1entitlements~1active_entitlements/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/entitlements/active_entitlements/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1entitlements~1active_entitlements~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/entitlements/features` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1entitlements~1features/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/entitlements/features` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1entitlements~1features/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/entitlements/features/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1entitlements~1features~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/entitlements/features/{id}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1entitlements~1features~1{id}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/ephemeral_keys` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1ephemeral_keys/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/events` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1events/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/events/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1events~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/exchange_rates` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1exchange_rates/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/exchange_rates/{rate_id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1exchange_rates~1{rate_id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/external_accounts/{id}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1external_accounts~1{id}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/file_links` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1file_links/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/file_links` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1file_links/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/file_links/{link}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1file_links~1{link}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/file_links/{link}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1file_links~1{link}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/expires_at`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/files` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1files/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/files` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1files/post/requestBody/content/multipart~1form-data/schema/properties/file_link_data/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/files/{file}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1files~1{file}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/financial_connections/accounts` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1financial_connections~1accounts/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/financial_connections/accounts/{account}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1financial_connections~1accounts~1{account}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/financial_connections/accounts/{account}/disconnect` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1financial_connections~1accounts~1{account}~1disconnect/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/financial_connections/accounts/{account}/owners` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1financial_connections~1accounts~1{account}~1owners/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/financial_connections/accounts/{account}/refresh` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1financial_connections~1accounts~1{account}~1refresh/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/financial_connections/accounts/{account}/subscribe` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1financial_connections~1accounts~1{account}~1subscribe/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/financial_connections/accounts/{account}/unsubscribe` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1financial_connections~1accounts~1{account}~1unsubscribe/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/financial_connections/sessions` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1financial_connections~1sessions/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/limits/properties/accounts`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/financial_connections/sessions/{session}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1financial_connections~1sessions~1{session}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/financial_connections/transactions` [capability_gap]: Unsupported parameter serialization; Unsupported parameter composition
  Source: `#/paths/~1v1~1financial_connections~1transactions/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/financial_connections/transactions/{transaction}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1financial_connections~1transactions~1{transaction}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/forwarding/requests` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1forwarding~1requests/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/forwarding/requests` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1forwarding~1requests/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/forwarding/requests/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1forwarding~1requests~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/identity/verification_reports` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1identity~1verification_reports/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/identity/verification_reports/{report}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1identity~1verification_reports~1{report}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/identity/verification_sessions` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1identity~1verification_sessions/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/identity/verification_sessions` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1identity~1verification_sessions/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/options/properties/document`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/identity/verification_sessions/{session}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1identity~1verification_sessions~1{session}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/identity/verification_sessions/{session}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1identity~1verification_sessions~1{session}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/options/properties/document`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/identity/verification_sessions/{session}/cancel` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1identity~1verification_sessions~1{session}~1cancel/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/identity/verification_sessions/{session}/redact` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1identity~1verification_sessions~1{session}~1redact/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/invoice_payments` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1invoice_payments/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/invoice_payments/{invoice_payment}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1invoice_payments~1{invoice_payment}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/invoice_rendering_templates` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1invoice_rendering_templates/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/invoice_rendering_templates/{template}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1invoice_rendering_templates~1{template}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/invoice_rendering_templates/{template}/archive` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1invoice_rendering_templates~1{template}~1archive/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/invoice_rendering_templates/{template}/unarchive` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1invoice_rendering_templates~1{template}~1unarchive/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/invoiceitems` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1invoiceitems/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/invoiceitems` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1invoiceitems/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/discounts`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/invoiceitems/{invoiceitem}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1invoiceitems~1{invoiceitem}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/invoiceitems/{invoiceitem}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1invoiceitems~1{invoiceitem}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/discounts`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/invoices` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1invoices/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/invoices` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1invoices/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/account_tax_ids`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/invoices/create_preview` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1invoices~1create_preview/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/customer_details/properties/address`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/invoices/search` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1invoices~1search/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/invoices/{invoice}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1invoices~1{invoice}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/invoices/{invoice}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1invoices~1{invoice}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/account_tax_ids`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/invoices/{invoice}/add_lines` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1invoices~1{invoice}~1add_lines/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/invoice_metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/invoices/{invoice}/attach_payment` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1invoices~1{invoice}~1attach_payment/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/invoices/{invoice}/finalize` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1invoices~1{invoice}~1finalize/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/invoices/{invoice}/lines` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1invoices~1{invoice}~1lines/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/invoices/{invoice}/lines/{line_item_id}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1invoices~1{invoice}~1lines~1{line_item_id}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/discounts`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/invoices/{invoice}/mark_uncollectible` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1invoices~1{invoice}~1mark_uncollectible/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/invoices/{invoice}/pay` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1invoices~1{invoice}~1pay/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/mandate`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/invoices/{invoice}/remove_lines` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1invoices~1{invoice}~1remove_lines/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/invoice_metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/invoices/{invoice}/send` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1invoices~1{invoice}~1send/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/invoices/{invoice}/update_lines` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1invoices~1{invoice}~1update_lines/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/invoice_metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/invoices/{invoice}/void` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1invoices~1{invoice}~1void/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/issuing/authorizations` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1issuing~1authorizations/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/issuing/authorizations/{authorization}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1issuing~1authorizations~1{authorization}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/issuing/authorizations/{authorization}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1issuing~1authorizations~1{authorization}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/issuing/authorizations/{authorization}/approve` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1issuing~1authorizations~1{authorization}~1approve/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/issuing/authorizations/{authorization}/decline` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1issuing~1authorizations~1{authorization}~1decline/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/issuing/cardholders` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1issuing~1cardholders/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/issuing/cardholders` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1issuing~1cardholders/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/individual/properties/card_issuing/properties/user_terms_acceptance/properties/user_agent`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/issuing/cardholders/{cardholder}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1issuing~1cardholders~1{cardholder}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/issuing/cardholders/{cardholder}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1issuing~1cardholders~1{cardholder}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/individual/properties/card_issuing/properties/user_terms_acceptance/properties/user_agent`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/issuing/cards` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1issuing~1cards/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/issuing/cards` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1issuing~1cards/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/second_line`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/issuing/cards/{card}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1issuing~1cards~1{card}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/issuing/cards/{card}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1issuing~1cards~1{card}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/issuing/disputes` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1issuing~1disputes/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/issuing/disputes` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1issuing~1disputes/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/evidence/properties/canceled`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/issuing/disputes/{dispute}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1issuing~1disputes~1{dispute}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/issuing/disputes/{dispute}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1issuing~1disputes~1{dispute}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/evidence/properties/canceled`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/issuing/disputes/{dispute}/submit` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1issuing~1disputes~1{dispute}~1submit/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/issuing/personalization_designs` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1issuing~1personalization_designs/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/issuing/personalization_designs` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1issuing~1personalization_designs/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/carrier_text/properties/footer_body`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/issuing/personalization_designs/{personalization_design}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1issuing~1personalization_designs~1{personalization_design}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/issuing/personalization_designs/{personalization_design}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1issuing~1personalization_designs~1{personalization_design}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/card_logo`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/issuing/physical_bundles` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1issuing~1physical_bundles/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/issuing/physical_bundles/{physical_bundle}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1issuing~1physical_bundles~1{physical_bundle}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/issuing/settlements/{settlement}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1issuing~1settlements~1{settlement}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/issuing/settlements/{settlement}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1issuing~1settlements~1{settlement}/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/issuing/tokens` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1issuing~1tokens/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/issuing/tokens/{token}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1issuing~1tokens~1{token}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/issuing/tokens/{token}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1issuing~1tokens~1{token}/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/issuing/transactions` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1issuing~1transactions/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/issuing/transactions/{transaction}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1issuing~1transactions~1{transaction}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/issuing/transactions/{transaction}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1issuing~1transactions~1{transaction}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/link_account_sessions` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1link_account_sessions/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/limits/properties/accounts`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/link_account_sessions/{session}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1link_account_sessions~1{session}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/linked_accounts` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1linked_accounts/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/linked_accounts/{account}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1linked_accounts~1{account}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/linked_accounts/{account}/disconnect` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1linked_accounts~1{account}~1disconnect/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/linked_accounts/{account}/owners` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1linked_accounts~1{account}~1owners/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/linked_accounts/{account}/refresh` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1linked_accounts~1{account}~1refresh/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/mandates/{mandate}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1mandates~1{mandate}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/payment_attempt_records` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_attempt_records/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/payment_attempt_records/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_attempt_records~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/payment_intents` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_intents/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_intents` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1payment_intents/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/amount_details/properties/discount_amount`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/payment_intents/search` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_intents~1search/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/payment_intents/{intent}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_intents~1{intent}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_intents/{intent}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1payment_intents~1{intent}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/amount_details`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/payment_intents/{intent}/amount_details_line_items` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_intents~1{intent}~1amount_details_line_items/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_intents/{intent}/apply_customer_balance` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_intents~1{intent}~1apply_customer_balance/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_intents/{intent}/cancel` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_intents~1{intent}~1cancel/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_intents/{intent}/capture` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1payment_intents~1{intent}~1capture/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/amount_details/properties/discount_amount`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_intents/{intent}/confirm` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1payment_intents~1{intent}~1confirm/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/amount_details`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_intents/{intent}/increment_authorization` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1payment_intents~1{intent}~1increment_authorization/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/amount_details/properties/discount_amount`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_intents/{intent}/verify_microdeposits` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_intents~1{intent}~1verify_microdeposits/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/payment_links` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_links/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_links` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1payment_links/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/custom_text/properties/after_submit`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/payment_links/{payment_link}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_links~1{payment_link}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_links/{payment_link}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1payment_links~1{payment_link}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/application_fee_amount`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/payment_links/{payment_link}/line_items` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_links~1{payment_link}~1line_items/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/payment_method_configurations` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_method_configurations/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_method_configurations` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1payment_method_configurations/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/payment_method_configurations/{configuration}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_method_configurations~1{configuration}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_method_configurations/{configuration}` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1payment_method_configurations~1{configuration}/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/payment_method_domains` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_method_domains/get/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_method_domains` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_method_domains/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/payment_method_domains/{payment_method_domain}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_method_domains~1{payment_method_domain}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_method_domains/{payment_method_domain}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_method_domains~1{payment_method_domain}/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_method_domains/{payment_method_domain}/validate` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_method_domains~1{payment_method_domain}~1validate/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/payment_methods` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_methods/get/parameters/4/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_methods` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1payment_methods/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/billing_details/properties/address`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/payment_methods/{payment_method}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_methods~1{payment_method}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_methods/{payment_method}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1payment_methods~1{payment_method}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/billing_details/properties/address`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_methods/{payment_method}/attach` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_methods~1{payment_method}~1attach/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_methods/{payment_method}/detach` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_methods~1{payment_method}~1detach/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/payment_records` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_records/get/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_records/report_payment` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1payment_records~1report_payment/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/payment_records/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payment_records~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_records/{id}/report_payment_attempt` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1payment_records~1{id}~1report_payment_attempt/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_records/{id}/report_payment_attempt_canceled` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1payment_records~1{id}~1report_payment_attempt_canceled/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_records/{id}/report_payment_attempt_failed` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1payment_records~1{id}~1report_payment_attempt_failed/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_records/{id}/report_payment_attempt_guaranteed` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1payment_records~1{id}~1report_payment_attempt_guaranteed/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_records/{id}/report_payment_attempt_informational` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1payment_records~1{id}~1report_payment_attempt_informational/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/description`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payment_records/{id}/report_refund` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1payment_records~1{id}~1report_refund/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/payouts` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1payouts/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payouts` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payouts/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/payouts/{payout}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payouts~1{payout}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payouts/{payout}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1payouts~1{payout}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payouts/{payout}/cancel` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payouts~1{payout}~1cancel/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/payouts/{payout}/reverse` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1payouts~1{payout}~1reverse/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/plans` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1plans/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/plans` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1plans/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/plans/{plan}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1plans~1{plan}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/plans/{plan}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1plans~1{plan}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/prices` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1prices/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/prices` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1prices/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/currency_options/additionalProperties/properties/tiers/items/properties/up_to`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/prices/search` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1prices~1search/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/prices/{price}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1prices~1{price}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/prices/{price}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1prices~1{price}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/currency_options`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/products` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1products/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/products` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1products/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/default_price_data/properties/currency_options/additionalProperties/properties/tiers/items/properties/up_to`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/products/search` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1products~1search/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/products/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1products~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/products/{id}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1products~1{id}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/description`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/products/{product}/features` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1products~1{product}~1features/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/products/{product}/features` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1products~1{product}~1features/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/products/{product}/features/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1products~1{product}~1features~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/promotion_codes` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1promotion_codes/get/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/promotion_codes` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1promotion_codes/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/promotion_codes/{promotion_code}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1promotion_codes~1{promotion_code}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/promotion_codes/{promotion_code}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1promotion_codes~1{promotion_code}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/quotes` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1quotes/get/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/quotes` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1quotes/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/application_fee_amount`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/quotes/{quote}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1quotes~1{quote}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/quotes/{quote}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1quotes~1{quote}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/application_fee_amount`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/quotes/{quote}/accept` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1quotes~1{quote}~1accept/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/quotes/{quote}/cancel` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1quotes~1{quote}~1cancel/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/quotes/{quote}/computed_upfront_line_items` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1quotes~1{quote}~1computed_upfront_line_items/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/quotes/{quote}/finalize` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1quotes~1{quote}~1finalize/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/quotes/{quote}/line_items` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1quotes~1{quote}~1line_items/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/quotes/{quote}/pdf` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1quotes~1{quote}~1pdf/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/radar/early_fraud_warnings` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1radar~1early_fraud_warnings/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/radar/early_fraud_warnings/{early_fraud_warning}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1radar~1early_fraud_warnings~1{early_fraud_warning}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/radar/payment_evaluations` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1radar~1payment_evaluations/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/radar/value_list_items` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1radar~1value_list_items/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/radar/value_list_items` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1radar~1value_list_items/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/radar/value_list_items/{item}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1radar~1value_list_items~1{item}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/radar/value_lists` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1radar~1value_lists/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/radar/value_lists` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1radar~1value_lists/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/radar/value_lists/{value_list}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1radar~1value_lists~1{value_list}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/radar/value_lists/{value_list}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1radar~1value_lists~1{value_list}/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/refunds` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1refunds/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/refunds` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1refunds/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/refunds/{refund}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1refunds~1{refund}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/refunds/{refund}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1refunds~1{refund}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/refunds/{refund}/cancel` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1refunds~1{refund}~1cancel/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/reporting/report_runs` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1reporting~1report_runs/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/reporting/report_runs` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1reporting~1report_runs/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/reporting/report_runs/{report_run}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1reporting~1report_runs~1{report_run}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/reporting/report_types` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1reporting~1report_types/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/reporting/report_types/{report_type}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1reporting~1report_types~1{report_type}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/reviews` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1reviews/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/reviews/{review}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1reviews~1{review}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/reviews/{review}/approve` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1reviews~1{review}~1approve/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/setup_attempts` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1setup_attempts/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/setup_intents` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1setup_intents/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/setup_intents` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1setup_intents/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/mandate_data`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/setup_intents/{intent}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1setup_intents~1{intent}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/setup_intents/{intent}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1setup_intents~1{intent}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/allowed_payment_method_types`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/setup_intents/{intent}/cancel` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1setup_intents~1{intent}~1cancel/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/setup_intents/{intent}/confirm` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1setup_intents~1{intent}~1confirm/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/mandate_data`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/setup_intents/{intent}/verify_microdeposits` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1setup_intents~1{intent}~1verify_microdeposits/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/shipping_rates` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1shipping_rates/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/shipping_rates` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1shipping_rates/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/shipping_rates/{shipping_rate_token}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1shipping_rates~1{shipping_rate_token}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/shipping_rates/{shipping_rate_token}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1shipping_rates~1{shipping_rate_token}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/sigma/saved_queries/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1sigma~1saved_queries~1{id}/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/sigma/scheduled_query_runs` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1sigma~1scheduled_query_runs/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/sigma/scheduled_query_runs/{scheduled_query_run}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1sigma~1scheduled_query_runs~1{scheduled_query_run}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/sources` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1sources/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/mandate/properties/amount`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/sources/{source}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1sources~1{source}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/sources/{source}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1sources~1{source}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/mandate/properties/amount`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/sources/{source}/mandate_notifications/{mandate_notification}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1sources~1{source}~1mandate_notifications~1{mandate_notification}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/sources/{source}/source_transactions` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1sources~1{source}~1source_transactions/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/sources/{source}/source_transactions/{source_transaction}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1sources~1{source}~1source_transactions~1{source_transaction}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/sources/{source}/verify` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1sources~1{source}~1verify/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/subscription_items` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1subscription_items/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/subscription_items` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1subscription_items/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/billing_thresholds`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/subscription_items/{item}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1subscription_items~1{item}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/subscription_items/{item}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1subscription_items~1{item}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/billing_thresholds`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/subscription_schedules` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1subscription_schedules/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/subscription_schedules` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1subscription_schedules/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/default_settings/properties/billing_thresholds`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/subscription_schedules/{schedule}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1subscription_schedules~1{schedule}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/subscription_schedules/{schedule}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1subscription_schedules~1{schedule}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/default_settings/properties/billing_thresholds`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/subscription_schedules/{schedule}/cancel` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1subscription_schedules~1{schedule}~1cancel/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/subscription_schedules/{schedule}/release` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1subscription_schedules~1{schedule}~1release/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/subscriptions` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1subscriptions/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/subscriptions` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1subscriptions/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/add_invoice_items/items/properties/tax_rates`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/subscriptions/search` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1subscriptions~1search/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/subscriptions/{subscription_exposed_id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1subscriptions~1{subscription_exposed_id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/subscriptions/{subscription_exposed_id}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1subscriptions~1{subscription_exposed_id}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/add_invoice_items/items/properties/tax_rates`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/subscriptions/{subscription}/migrate` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1subscriptions~1{subscription}~1migrate/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/subscriptions/{subscription}/resume` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1subscriptions~1{subscription}~1resume/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/tax/associations/find` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1tax~1associations~1find/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/tax/calculations` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1tax~1calculations/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/customer_details/properties/address/properties/city`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/tax/calculations/{calculation}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1tax~1calculations~1{calculation}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/tax/calculations/{calculation}/line_items` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1tax~1calculations~1{calculation}~1line_items/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/tax/registrations` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1tax~1registrations/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/tax/registrations` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1tax~1registrations/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/active_from`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/tax/registrations/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1tax~1registrations~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/tax/registrations/{id}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1tax~1registrations~1{id}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/active_from`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/tax/settings` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1tax~1settings/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/tax/settings` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1tax~1settings/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/tax/transactions/create_from_calculation` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1tax~1transactions~1create_from_calculation/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/tax/transactions/create_reversal` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1tax~1transactions~1create_reversal/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/tax/transactions/{transaction}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1tax~1transactions~1{transaction}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/tax/transactions/{transaction}/line_items` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1tax~1transactions~1{transaction}~1line_items/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/tax_codes` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1tax_codes/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/tax_codes/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1tax_codes~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/tax_ids` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1tax_ids/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/tax_ids` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1tax_ids/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/tax_ids/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1tax_ids~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/tax_rates` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1tax_rates/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/tax_rates` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1tax_rates/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/tax_rates/{tax_rate}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1tax_rates~1{tax_rate}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/tax_rates/{tax_rate}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1tax_rates~1{tax_rate}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/terminal/configurations` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1terminal~1configurations/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/terminal/configurations` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1terminal~1configurations/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/bbpos_wisepad3/properties/splashscreen`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/terminal/configurations/{configuration}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1terminal~1configurations~1{configuration}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/terminal/configurations/{configuration}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1terminal~1configurations~1{configuration}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/bbpos_wisepad3`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/terminal/connection_tokens` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1terminal~1connection_tokens/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/terminal/locations` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1terminal~1locations/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/terminal/locations` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1terminal~1locations/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/terminal/locations/{location}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1terminal~1locations~1{location}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/terminal/locations/{location}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1terminal~1locations~1{location}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/configuration_overrides`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/terminal/onboarding_links` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1terminal~1onboarding_links/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/terminal/readers` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1terminal~1readers/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/terminal/readers` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1terminal~1readers/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/terminal/readers/{reader}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1terminal~1readers~1{reader}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/terminal/readers/{reader}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1terminal~1readers~1{reader}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/label`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/terminal/readers/{reader}/cancel_action` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1terminal~1readers~1{reader}~1cancel_action/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/terminal/readers/{reader}/collect_inputs` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1terminal~1readers~1{reader}~1collect_inputs/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/terminal/readers/{reader}/collect_payment_method` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1terminal~1readers~1{reader}~1collect_payment_method/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/terminal/readers/{reader}/confirm_payment_intent` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1terminal~1readers~1{reader}~1confirm_payment_intent/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/terminal/readers/{reader}/process_payment_intent` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1terminal~1readers~1{reader}~1process_payment_intent/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/terminal/readers/{reader}/process_setup_intent` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1terminal~1readers~1{reader}~1process_setup_intent/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/terminal/readers/{reader}/refund_payment` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1terminal~1readers~1{reader}~1refund_payment/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/terminal/readers/{reader}/set_reader_display` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1terminal~1readers~1{reader}~1set_reader_display/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/terminal/refunds` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1terminal~1refunds/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/confirmation_tokens` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1test_helpers~1confirmation_tokens/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/payment_method_data/properties/billing_details/properties/address`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/customers/{customer}/fund_cash_balance` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1customers~1{customer}~1fund_cash_balance/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/authorizations` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1test_helpers~1issuing~1authorizations/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/authorizations/{authorization}/capture` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1issuing~1authorizations~1{authorization}~1capture/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/authorizations/{authorization}/expire` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1issuing~1authorizations~1{authorization}~1expire/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/authorizations/{authorization}/finalize_amount` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1issuing~1authorizations~1{authorization}~1finalize_amount/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/authorizations/{authorization}/fraud_challenges/respond` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1issuing~1authorizations~1{authorization}~1fraud_challenges~1respond/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/authorizations/{authorization}/increment` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1issuing~1authorizations~1{authorization}~1increment/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/authorizations/{authorization}/reverse` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1issuing~1authorizations~1{authorization}~1reverse/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/cards/{card}/shipping/deliver` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1issuing~1cards~1{card}~1shipping~1deliver/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/cards/{card}/shipping/fail` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1issuing~1cards~1{card}~1shipping~1fail/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/cards/{card}/shipping/return` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1issuing~1cards~1{card}~1shipping~1return/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/cards/{card}/shipping/ship` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1issuing~1cards~1{card}~1shipping~1ship/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/cards/{card}/shipping/submit` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1issuing~1cards~1{card}~1shipping~1submit/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/personalization_designs/{personalization_design}/activate` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1issuing~1personalization_designs~1{personalization_design}~1activate/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/personalization_designs/{personalization_design}/deactivate` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1issuing~1personalization_designs~1{personalization_design}~1deactivate/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/personalization_designs/{personalization_design}/reject` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1issuing~1personalization_designs~1{personalization_design}~1reject/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/settlements` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1issuing~1settlements/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/settlements/{settlement}/complete` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1issuing~1settlements~1{settlement}~1complete/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/transactions/create_force_capture` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1issuing~1transactions~1create_force_capture/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/transactions/create_unlinked_refund` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1issuing~1transactions~1create_unlinked_refund/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/issuing/transactions/{transaction}/refund` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1issuing~1transactions~1{transaction}~1refund/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/refunds/{refund}/expire` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1refunds~1{refund}~1expire/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/terminal/readers/{reader}/present_payment_method` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1test_helpers~1terminal~1readers~1{reader}~1present_payment_method/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/terminal/readers/{reader}/succeed_input_collection` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1terminal~1readers~1{reader}~1succeed_input_collection/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/terminal/readers/{reader}/timeout_input_collection` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1terminal~1readers~1{reader}~1timeout_input_collection/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/test_helpers/test_clocks` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1test_clocks/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/test_clocks` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1test_clocks/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/test_helpers/test_clocks/{test_clock}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1test_clocks~1{test_clock}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/test_clocks/{test_clock}/advance` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1test_clocks~1{test_clock}~1advance/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/treasury/inbound_transfers/{id}/fail` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1treasury~1inbound_transfers~1{id}~1fail/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/treasury/inbound_transfers/{id}/return` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1treasury~1inbound_transfers~1{id}~1return/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/treasury/inbound_transfers/{id}/succeed` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1treasury~1inbound_transfers~1{id}~1succeed/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/treasury/outbound_payments/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1treasury~1outbound_payments~1{id}/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/treasury/outbound_payments/{id}/fail` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1treasury~1outbound_payments~1{id}~1fail/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/treasury/outbound_payments/{id}/post` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1treasury~1outbound_payments~1{id}~1post/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/treasury/outbound_payments/{id}/return` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1treasury~1outbound_payments~1{id}~1return/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/treasury/outbound_transfers/{outbound_transfer}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1treasury~1outbound_transfers~1{outbound_transfer}/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/treasury/outbound_transfers/{outbound_transfer}/fail` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1treasury~1outbound_transfers~1{outbound_transfer}~1fail/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/treasury/outbound_transfers/{outbound_transfer}/post` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1treasury~1outbound_transfers~1{outbound_transfer}~1post/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/treasury/outbound_transfers/{outbound_transfer}/return` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1treasury~1outbound_transfers~1{outbound_transfer}~1return/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/treasury/received_credits` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1treasury~1received_credits/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/test_helpers/treasury/received_debits` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1test_helpers~1treasury~1received_debits/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/tokens` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1tokens/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/account/properties/company/properties/registration_date`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/tokens/{token}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1tokens~1{token}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/topups` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1topups/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/topups` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1topups/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/topups/{topup}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1topups~1{topup}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/topups/{topup}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1topups~1{topup}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/topups/{topup}/cancel` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1topups~1{topup}~1cancel/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/transfers` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1transfers/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/transfers` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1transfers/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/transfers/{id}/reversals` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1transfers~1{id}~1reversals/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/transfers/{id}/reversals` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1transfers~1{id}~1reversals/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/transfers/{transfer}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1transfers~1{transfer}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/transfers/{transfer}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1transfers~1{transfer}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/transfers/{transfer}/reversals/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1transfers~1{transfer}~1reversals~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/transfers/{transfer}/reversals/{id}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1transfers~1{transfer}~1reversals~1{id}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/metadata`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/credit_reversals` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1credit_reversals/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/treasury/credit_reversals` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1credit_reversals/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/credit_reversals/{credit_reversal}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1credit_reversals~1{credit_reversal}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/debit_reversals` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1debit_reversals/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/treasury/debit_reversals` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1debit_reversals/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/debit_reversals/{debit_reversal}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1debit_reversals~1{debit_reversal}/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/financial_accounts` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1financial_accounts/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/treasury/financial_accounts` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1treasury~1financial_accounts/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/nickname`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/financial_accounts/{financial_account}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1financial_accounts~1{financial_account}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/treasury/financial_accounts/{financial_account}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1treasury~1financial_accounts~1{financial_account}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/nickname`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/treasury/financial_accounts/{financial_account}/close` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1financial_accounts~1{financial_account}~1close/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/financial_accounts/{financial_account}/features` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1financial_accounts~1{financial_account}~1features/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/treasury/financial_accounts/{financial_account}/features` [capability_gap]: Nested URL-encoded form fields are unsupported
  Source: `#/paths/~1v1~1treasury~1financial_accounts~1{financial_account}~1features/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/inbound_transfers` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1inbound_transfers/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/treasury/inbound_transfers` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1inbound_transfers/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/inbound_transfers/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1inbound_transfers~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/treasury/inbound_transfers/{inbound_transfer}/cancel` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1inbound_transfers~1{inbound_transfer}~1cancel/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/outbound_payments` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1outbound_payments/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/treasury/outbound_payments` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1treasury~1outbound_payments/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/destination_payment_method_data/properties/billing_details/properties/address`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/outbound_payments/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1outbound_payments~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/treasury/outbound_payments/{id}/cancel` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1outbound_payments~1{id}~1cancel/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/outbound_transfers` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1outbound_transfers/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/treasury/outbound_transfers` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1treasury~1outbound_transfers/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/destination_payment_method_options/properties/us_bank_account`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/outbound_transfers/{outbound_transfer}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1outbound_transfers~1{outbound_transfer}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/treasury/outbound_transfers/{outbound_transfer}/cancel` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1outbound_transfers~1{outbound_transfer}~1cancel/post/requestBody/content/application~1x-www-form-urlencoded/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/received_credits` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1received_credits/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/received_credits/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1received_credits~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/received_debits` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1received_debits/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/received_debits/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1received_debits~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/transaction_entries` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1transaction_entries/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/transaction_entries/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1transaction_entries~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/transactions` [capability_gap]: Unsupported parameter composition; Unsupported parameter serialization; Unsupported nested parameter object
  Source: `#/paths/~1v1~1treasury~1transactions/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/treasury/transactions/{id}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1treasury~1transactions~1{id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/webhook_endpoints` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1webhook_endpoints/get/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/webhook_endpoints` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1webhook_endpoints/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/description`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `GET /v1/webhook_endpoints/{webhook_endpoint}` [capability_gap]: Unsupported parameter serialization
  Source: `#/paths/~1v1~1webhook_endpoints~1{webhook_endpoint}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- stripe/openapi/master/openapi/spec3.yaml: `POST /v1/webhook_endpoints/{webhook_endpoint}` [capability_gap]: Unsupported body composition
  Source: `#/paths/~1v1~1webhook_endpoints~1{webhook_endpoint}/post/requestBody/content/application~1x-www-form-urlencoded/schema/properties/description`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `GET /advisories` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1advisories/get/parameters/5/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `GET /enterprises/{enterprise}/dependabot/alerts` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1enterprises~1{enterprise}~1dependabot~1alerts/get/parameters/7/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `POST /markdown/raw` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1markdown~1raw/post/requestBody`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `GET /orgs/{org}/dependabot/alerts` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1orgs~1{org}~1dependabot~1alerts/get/parameters/9/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `GET /orgs/{org}/projectsV2/{project_number}/items` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1orgs~1{org}~1projectsV2~1{project_number}~1items/get/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `GET /orgs/{org}/projectsV2/{project_number}/items/{item_id}` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1orgs~1{org}~1projectsV2~1{project_number}~1items~1{item_id}/get/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `GET /orgs/{org}/projectsV2/{project_number}/views/{view_number}/items` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1orgs~1{org}~1projectsV2~1{project_number}~1views~1{view_number}~1items/get/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `GET /repos/{owner}/{repo}/actions/workflows/{workflow_id}` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1repos~1{owner}~1{repo}~1actions~1workflows~1{workflow_id}/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `PUT /repos/{owner}/{repo}/actions/workflows/{workflow_id}/disable` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1repos~1{owner}~1{repo}~1actions~1workflows~1{workflow_id}~1disable/put/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1repos~1{owner}~1{repo}~1actions~1workflows~1{workflow_id}~1dispatches/post/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `PUT /repos/{owner}/{repo}/actions/workflows/{workflow_id}/enable` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1repos~1{owner}~1{repo}~1actions~1workflows~1{workflow_id}~1enable/put/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `GET /repos/{owner}/{repo}/actions/workflows/{workflow_id}/runs` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1repos~1{owner}~1{repo}~1actions~1workflows~1{workflow_id}~1runs/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `GET /repos/{owner}/{repo}/actions/workflows/{workflow_id}/timing` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1repos~1{owner}~1{repo}~1actions~1workflows~1{workflow_id}~1timing/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `GET /repos/{owner}/{repo}/dependabot/alerts` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1repos~1{owner}~1{repo}~1dependabot~1alerts/get/parameters/9/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `GET /repos/{owner}/{repo}/pages/deployments/{pages_deployment_id}` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1repos~1{owner}~1{repo}~1pages~1deployments~1{pages_deployment_id}/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `POST /repos/{owner}/{repo}/pages/deployments/{pages_deployment_id}/cancel` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1repos~1{owner}~1{repo}~1pages~1deployments~1{pages_deployment_id}~1cancel/post/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `GET /users/{username}/projectsV2/{project_number}/items` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1users~1{username}~1projectsV2~1{project_number}~1items/get/parameters/6/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `GET /users/{username}/projectsV2/{project_number}/items/{item_id}` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1users~1{username}~1projectsV2~1{project_number}~1items~1{item_id}/get/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `GET /users/{username}/projectsV2/{project_number}/views/{view_number}/items` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1users~1{username}~1projectsV2~1{project_number}~1views~1{view_number}~1items/get/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `GET /orgs/{org}/actions/hosted-runners/images/custom/{image_definition_id}/versions/{version}` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `DELETE /orgs/{org}/actions/hosted-runners/images/custom/{image_definition_id}/versions/{version}` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `PUT /orgs/{org}/actions/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `PUT /orgs/{org}/agents/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `POST /orgs/{org}/artifacts/metadata/deployment-record` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `POST /orgs/{org}/artifacts/metadata/deployment-record/cluster/{cluster}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `POST /orgs/{org}/artifacts/metadata/deployment-record/cluster/{cluster}/jobs` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `POST /orgs/{org}/artifacts/metadata/storage-record` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `GET /orgs/{org}/artifacts/{subject_digest}/metadata/deployment-records` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `GET /orgs/{org}/artifacts/{subject_digest}/metadata/storage-records` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `POST /orgs/{org}/attestations/delete-request` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `PUT /orgs/{org}/codespaces/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `PUT /orgs/{org}/dependabot/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `POST /orgs/{org}/private-registries` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `PATCH /orgs/{org}/private-registries/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `POST /orgs/{org}/projectsV2/{project_number}/items` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `PUT /repos/{owner}/{repo}/actions/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `PUT /repos/{owner}/{repo}/agents/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `POST /repos/{owner}/{repo}/code-scanning/codeql/variant-analyses` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `POST /repos/{owner}/{repo}/code-scanning/sarifs` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `PUT /repos/{owner}/{repo}/codespaces/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `PUT /repos/{owner}/{repo}/dependabot/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `PUT /repos/{owner}/{repo}/environments/{environment_name}/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `PUT /user/codespaces/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `POST /user/keys` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `POST /user/ssh_signing_keys` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `POST /users/{username}/attestations/delete-request` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml: `POST /users/{username}/projectsV2/{project_number}/items` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /advisories` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1advisories/get/parameters/5/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /applications/{client_id}/grant` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1applications~1{client_id}~1grant/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /applications/{client_id}/token` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1applications~1{client_id}~1token/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /enterprises/{enterprise}/copilot/policies/coding_agent/organizations` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1enterprises~1{enterprise}~1copilot~1policies~1coding_agent~1organizations/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /enterprises/{enterprise}/dependabot/alerts` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1enterprises~1{enterprise}~1dependabot~1alerts/get/parameters/7/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /markdown/raw` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1markdown~1raw/post/requestBody`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /orgs/{org}/code-scanning/alerts` [capability_gap]: Unsupported parameter type
  Source: `#/paths/~1orgs~1{org}~1code-scanning~1alerts/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /orgs/{org}/code-security/configurations/detach` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1orgs~1{org}~1code-security~1configurations~1detach/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /orgs/{org}/codespaces/access/selected_users` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1orgs~1{org}~1codespaces~1access~1selected_users/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /orgs/{org}/copilot/billing/selected_teams` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1orgs~1{org}~1copilot~1billing~1selected_teams/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /orgs/{org}/copilot/billing/selected_users` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1orgs~1{org}~1copilot~1billing~1selected_users/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /orgs/{org}/dependabot/alerts` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1orgs~1{org}~1dependabot~1alerts/get/parameters/9/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /orgs/{org}/projectsV2/{project_number}/items` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1orgs~1{org}~1projectsV2~1{project_number}~1items/get/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /orgs/{org}/projectsV2/{project_number}/items/{item_id}` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1orgs~1{org}~1projectsV2~1{project_number}~1items~1{item_id}/get/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /orgs/{org}/projectsV2/{project_number}/views/{view_number}/items` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1orgs~1{org}~1projectsV2~1{project_number}~1views~1{view_number}~1items/get/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /orgs/{org}/secret-scanning/custom-patterns` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1orgs~1{org}~1secret-scanning~1custom-patterns/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /repos/{owner}/{repo}/actions/workflows/{workflow_id}` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1repos~1{owner}~1{repo}~1actions~1workflows~1{workflow_id}/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /repos/{owner}/{repo}/actions/workflows/{workflow_id}/disable` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1repos~1{owner}~1{repo}~1actions~1workflows~1{workflow_id}~1disable/put/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1repos~1{owner}~1{repo}~1actions~1workflows~1{workflow_id}~1dispatches/post/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /repos/{owner}/{repo}/actions/workflows/{workflow_id}/enable` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1repos~1{owner}~1{repo}~1actions~1workflows~1{workflow_id}~1enable/put/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /repos/{owner}/{repo}/actions/workflows/{workflow_id}/runs` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1repos~1{owner}~1{repo}~1actions~1workflows~1{workflow_id}~1runs/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /repos/{owner}/{repo}/actions/workflows/{workflow_id}/timing` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1repos~1{owner}~1{repo}~1actions~1workflows~1{workflow_id}~1timing/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /repos/{owner}/{repo}/branches/{branch}/protection/required_status_checks/contexts` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1repos~1{owner}~1{repo}~1branches~1{branch}~1protection~1required_status_checks~1contexts/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /repos/{owner}/{repo}/branches/{branch}/protection/restrictions/apps` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1repos~1{owner}~1{repo}~1branches~1{branch}~1protection~1restrictions~1apps/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /repos/{owner}/{repo}/branches/{branch}/protection/restrictions/teams` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1repos~1{owner}~1{repo}~1branches~1{branch}~1protection~1restrictions~1teams/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /repos/{owner}/{repo}/branches/{branch}/protection/restrictions/users` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1repos~1{owner}~1{repo}~1branches~1{branch}~1protection~1restrictions~1users/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /repos/{owner}/{repo}/code-scanning/alerts` [capability_gap]: Unsupported parameter type
  Source: `#/paths/~1repos~1{owner}~1{repo}~1code-scanning~1alerts/get/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /repos/{owner}/{repo}/code-scanning/analyses` [capability_gap]: Unsupported parameter type
  Source: `#/paths/~1repos~1{owner}~1{repo}~1code-scanning~1analyses/get/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /repos/{owner}/{repo}/code-scanning/analyses/{analysis_id}` [capability_gap]: Unsupported parameter type
  Source: `#/paths/~1repos~1{owner}~1{repo}~1code-scanning~1analyses~1{analysis_id}/delete/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /repos/{owner}/{repo}/contents/{path}` [review_required]: OAS 3.1 GET request body requires an explicit operation body_media review
  Source: `#/paths/~1repos~1{owner}~1{repo}~1contents~1{path}/get/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /repos/{owner}/{repo}/contents/{path}` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1repos~1{owner}~1{repo}~1contents~1{path}/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /repos/{owner}/{repo}/dependabot/alerts` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1repos~1{owner}~1{repo}~1dependabot~1alerts/get/parameters/9/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /repos/{owner}/{repo}/deployments` [capability_gap]: Unsupported parameter type
  Source: `#/paths/~1repos~1{owner}~1{repo}~1deployments/get/parameters/5/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /repos/{owner}/{repo}/interaction-limits/pulls/bypass-list` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1repos~1{owner}~1{repo}~1interaction-limits~1pulls~1bypass-list/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /repos/{owner}/{repo}/issues/{issue_number}/assignees` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1repos~1{owner}~1{repo}~1issues~1{issue_number}~1assignees/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /repos/{owner}/{repo}/issues/{issue_number}/sub_issue` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1repos~1{owner}~1{repo}~1issues~1{issue_number}~1sub_issue/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /repos/{owner}/{repo}/pages/deployments/{pages_deployment_id}` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1repos~1{owner}~1{repo}~1pages~1deployments~1{pages_deployment_id}/get/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /repos/{owner}/{repo}/pages/deployments/{pages_deployment_id}/cancel` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1repos~1{owner}~1{repo}~1pages~1deployments~1{pages_deployment_id}~1cancel/post/parameters/2/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /repos/{owner}/{repo}/pulls/{pull_number}/requested_reviewers` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1repos~1{owner}~1{repo}~1pulls~1{pull_number}~1requested_reviewers/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /repos/{owner}/{repo}/secret-scanning/custom-patterns` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1repos~1{owner}~1{repo}~1secret-scanning~1custom-patterns/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /user/emails` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1user~1emails/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /user/social_accounts` [review_required]: OAS 3.1 DELETE request body requires an explicit operation body_media review
  Source: `#/paths/~1user~1social_accounts/delete/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /users/{username}/projectsV2/{project_number}/items` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1users~1{username}~1projectsV2~1{project_number}~1items/get/parameters/6/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /users/{username}/projectsV2/{project_number}/items/{item_id}` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1users~1{username}~1projectsV2~1{project_number}~1items~1{item_id}/get/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /users/{username}/projectsV2/{project_number}/views/{view_number}/items` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1users~1{username}~1projectsV2~1{project_number}~1views~1{view_number}~1items/get/parameters/3/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PATCH /app/hook/config` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /app/installations/{installation_id}/access_tokens` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /applications/{client_id}/token/scoped` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /enterprises/{enterprise}/actions/cache/retention-limit` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /enterprises/{enterprise}/actions/cache/storage-limit` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /enterprises/{enterprise}/copilot/metrics/reports/enterprise-1-day` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /enterprises/{enterprise}/copilot/metrics/reports/repos-1-day` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /enterprises/{enterprise}/copilot/metrics/reports/user-teams-1-day` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /enterprises/{enterprise}/copilot/metrics/reports/users-1-day` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /gists` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /gists/{gist_id}/comments` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PATCH /gists/{gist_id}/comments/{comment_id}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /organizations/{org}/actions/cache/retention-limit` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /organizations/{org}/actions/cache/storage-limit` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PATCH /orgs/{org}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /orgs/{org}/actions/hosted-runners/images/custom/{image_definition_id}/versions/{version}` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `DELETE /orgs/{org}/actions/hosted-runners/images/custom/{image_definition_id}/versions/{version}` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /orgs/{org}/actions/runner-groups` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PATCH /orgs/{org}/actions/runner-groups/{runner_group_id}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /orgs/{org}/actions/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /orgs/{org}/agents/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /orgs/{org}/artifacts/metadata/deployment-record` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /orgs/{org}/artifacts/metadata/deployment-record/cluster/{cluster}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /orgs/{org}/artifacts/metadata/deployment-record/cluster/{cluster}/jobs` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /orgs/{org}/artifacts/metadata/storage-record` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /orgs/{org}/artifacts/{subject_digest}/metadata/deployment-records` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /orgs/{org}/artifacts/{subject_digest}/metadata/storage-records` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /orgs/{org}/attestations/delete-request` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /orgs/{org}/codespaces/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /orgs/{org}/copilot-spaces` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /orgs/{org}/copilot-spaces/{space_number}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /orgs/{org}/copilot/metrics/reports/organization-1-day` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /orgs/{org}/copilot/metrics/reports/repos-1-day` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /orgs/{org}/copilot/metrics/reports/user-teams-1-day` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /orgs/{org}/copilot/metrics/reports/users-1-day` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /orgs/{org}/dependabot/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /orgs/{org}/hooks` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PATCH /orgs/{org}/hooks/{hook_id}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PATCH /orgs/{org}/hooks/{hook_id}/config` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /orgs/{org}/personal-access-token-requests` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /orgs/{org}/personal-access-tokens` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /orgs/{org}/private-registries` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PATCH /orgs/{org}/private-registries/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /orgs/{org}/projectsV2/{project_number}/items` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /orgs/{org}/projectsV2/{project_number}/views` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /orgs/{org}/rulesets` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /repos/{owner}/{repo}/actions/cache/retention-limit` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /repos/{owner}/{repo}/actions/cache/storage-limit` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /repos/{owner}/{repo}/actions/runs/{run_id}/pending_deployments` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /repos/{owner}/{repo}/actions/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /repos/{owner}/{repo}/agents/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /repos/{owner}/{repo}/code-scanning/codeql/variant-analyses` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /repos/{owner}/{repo}/code-scanning/sarifs` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /repos/{owner}/{repo}/codespaces/machines` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /repos/{owner}/{repo}/codespaces/new` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /repos/{owner}/{repo}/codespaces/permissions_check` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /repos/{owner}/{repo}/codespaces/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /repos/{owner}/{repo}/contents/{path}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /repos/{owner}/{repo}/dependabot/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /repos/{owner}/{repo}/dependency-graph/snapshots` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /repos/{owner}/{repo}/environments/{environment_name}/deployment-branch-policies` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /repos/{owner}/{repo}/environments/{environment_name}/deployment-branch-policies/{branch_policy_id}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /repos/{owner}/{repo}/environments/{environment_name}/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PATCH /repos/{owner}/{repo}/hooks/{hook_id}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PATCH /repos/{owner}/{repo}/hooks/{hook_id}/config` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /repos/{owner}/{repo}/issues/{issue_number}/issue-field-values` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /repos/{owner}/{repo}/issues/{issue_number}/issue-field-values` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /repos/{owner}/{repo}/pulls` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /repos/{owner}/{repo}/pulls/{pull_number}/reviews` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PATCH /repos/{owner}/{repo}/releases/assets/{asset_id}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `GET /repos/{owner}/{repo}/rulesets` [fixture]: No valid fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PATCH /user` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /user/codespaces/secrets/{secret_name}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /user/keys` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /user/migrations` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /user/repos` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /user/ssh_signing_keys` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /users/{user_id}/projectsV2/{project_number}/views` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /users/{username}/attestations/delete-request` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /users/{username}/copilot-spaces` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `PUT /users/{username}/copilot-spaces/{space_number}` [fixture]: No valid body fixture: supply a reviewed override
- github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json: `POST /users/{username}/projectsV2/{project_number}/items` [fixture]: No valid body fixture: supply a reviewed override
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /api/v1/namespaces` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /api/v1/namespaces/{namespace}/bindings` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1bindings/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/configmaps` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1configmaps/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /api/v1/namespaces/{namespace}/configmaps` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1configmaps/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/configmaps/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1configmaps~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/configmaps/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1configmaps~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/configmaps/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1configmaps~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/endpoints` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1endpoints/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /api/v1/namespaces/{namespace}/endpoints` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1endpoints/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/endpoints/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1endpoints~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/endpoints/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1endpoints~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/endpoints/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1endpoints~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/events` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1events/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /api/v1/namespaces/{namespace}/events` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1events/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/events/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1events~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/events/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1events~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/events/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1events~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/limitranges` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1limitranges/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /api/v1/namespaces/{namespace}/limitranges` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1limitranges/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/limitranges/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1limitranges~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/limitranges/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1limitranges~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/limitranges/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1limitranges~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/persistentvolumeclaims` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1persistentvolumeclaims/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /api/v1/namespaces/{namespace}/persistentvolumeclaims` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1persistentvolumeclaims/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/persistentvolumeclaims/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1persistentvolumeclaims~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/persistentvolumeclaims/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1persistentvolumeclaims~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/persistentvolumeclaims/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1persistentvolumeclaims~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/persistentvolumeclaims/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1persistentvolumeclaims~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/persistentvolumeclaims/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1persistentvolumeclaims~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/pods` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1pods/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /api/v1/namespaces/{namespace}/pods` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1pods/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/pods/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1pods~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/pods/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1pods~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/pods/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1pods~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /api/v1/namespaces/{namespace}/pods/{name}/binding` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1pods~1{name}~1binding/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/pods/{name}/ephemeralcontainers` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1pods~1{name}~1ephemeralcontainers/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/pods/{name}/ephemeralcontainers` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1pods~1{name}~1ephemeralcontainers/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /api/v1/namespaces/{namespace}/pods/{name}/eviction` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1pods~1{name}~1eviction/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/pods/{name}/resize` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1pods~1{name}~1resize/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/pods/{name}/resize` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1pods~1{name}~1resize/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/pods/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1pods~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/pods/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1pods~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/podtemplates` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1podtemplates/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /api/v1/namespaces/{namespace}/podtemplates` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1podtemplates/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/podtemplates/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1podtemplates~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/podtemplates/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1podtemplates~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/podtemplates/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1podtemplates~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/replicationcontrollers` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1replicationcontrollers/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /api/v1/namespaces/{namespace}/replicationcontrollers` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1replicationcontrollers/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/replicationcontrollers/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1replicationcontrollers~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/replicationcontrollers/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1replicationcontrollers~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/replicationcontrollers/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1replicationcontrollers~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/replicationcontrollers/{name}/scale` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1replicationcontrollers~1{name}~1scale/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/replicationcontrollers/{name}/scale` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1replicationcontrollers~1{name}~1scale/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/replicationcontrollers/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1replicationcontrollers~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/replicationcontrollers/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1replicationcontrollers~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/resourcequotas` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1resourcequotas/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /api/v1/namespaces/{namespace}/resourcequotas` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1resourcequotas/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/resourcequotas/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1resourcequotas~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/resourcequotas/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1resourcequotas~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/resourcequotas/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1resourcequotas~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/resourcequotas/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1resourcequotas~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/resourcequotas/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1resourcequotas~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/secrets` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1secrets/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /api/v1/namespaces/{namespace}/secrets` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1secrets/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/secrets/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1secrets~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/secrets/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1secrets~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/secrets/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1secrets~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/serviceaccounts` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1serviceaccounts/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /api/v1/namespaces/{namespace}/serviceaccounts` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1serviceaccounts/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/serviceaccounts/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1serviceaccounts~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/serviceaccounts/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1serviceaccounts~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/serviceaccounts/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1serviceaccounts~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /api/v1/namespaces/{namespace}/serviceaccounts/{name}/token` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1serviceaccounts~1{name}~1token/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/services` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1services/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /api/v1/namespaces/{namespace}/services` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1services/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{namespace}/services/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1services~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/services/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1services~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/services/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1services~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{namespace}/services/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1services~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{namespace}/services/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{namespace}~1services~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/namespaces/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{name}/finalize` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{name}~1finalize/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/namespaces/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/namespaces/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1namespaces~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/nodes` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1nodes/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /api/v1/nodes` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1nodes/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/nodes/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1nodes~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/nodes/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1nodes~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/nodes/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1nodes~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/nodes/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1nodes~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/nodes/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1nodes~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/persistentvolumes` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1persistentvolumes/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /api/v1/persistentvolumes` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1persistentvolumes/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /api/v1/persistentvolumes/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1persistentvolumes~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/persistentvolumes/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1persistentvolumes~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/persistentvolumes/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1persistentvolumes~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /api/v1/persistentvolumes/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1persistentvolumes~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /api/v1/persistentvolumes/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1api~1v1~1persistentvolumes~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1/mutatingadmissionpolicies` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1mutatingadmissionpolicies/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/admissionregistration.k8s.io/v1/mutatingadmissionpolicies` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1mutatingadmissionpolicies/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1/mutatingadmissionpolicies/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1mutatingadmissionpolicies~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/admissionregistration.k8s.io/v1/mutatingadmissionpolicies/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1mutatingadmissionpolicies~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/admissionregistration.k8s.io/v1/mutatingadmissionpolicies/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1mutatingadmissionpolicies~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1/mutatingadmissionpolicybindings` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1mutatingadmissionpolicybindings/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/admissionregistration.k8s.io/v1/mutatingadmissionpolicybindings` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1mutatingadmissionpolicybindings/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1/mutatingadmissionpolicybindings/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1mutatingadmissionpolicybindings~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/admissionregistration.k8s.io/v1/mutatingadmissionpolicybindings/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1mutatingadmissionpolicybindings~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/admissionregistration.k8s.io/v1/mutatingadmissionpolicybindings/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1mutatingadmissionpolicybindings~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1/mutatingwebhookconfigurations` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1mutatingwebhookconfigurations/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/admissionregistration.k8s.io/v1/mutatingwebhookconfigurations` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1mutatingwebhookconfigurations/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1/mutatingwebhookconfigurations/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1mutatingwebhookconfigurations~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/admissionregistration.k8s.io/v1/mutatingwebhookconfigurations/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1mutatingwebhookconfigurations~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/admissionregistration.k8s.io/v1/mutatingwebhookconfigurations/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1mutatingwebhookconfigurations~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1/validatingadmissionpolicies` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1validatingadmissionpolicies/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/admissionregistration.k8s.io/v1/validatingadmissionpolicies` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1validatingadmissionpolicies/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1/validatingadmissionpolicies/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1validatingadmissionpolicies~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/admissionregistration.k8s.io/v1/validatingadmissionpolicies/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1validatingadmissionpolicies~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/admissionregistration.k8s.io/v1/validatingadmissionpolicies/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1validatingadmissionpolicies~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/admissionregistration.k8s.io/v1/validatingadmissionpolicies/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1validatingadmissionpolicies~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/admissionregistration.k8s.io/v1/validatingadmissionpolicies/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1validatingadmissionpolicies~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1/validatingadmissionpolicybindings` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1validatingadmissionpolicybindings/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/admissionregistration.k8s.io/v1/validatingadmissionpolicybindings` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1validatingadmissionpolicybindings/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1/validatingadmissionpolicybindings/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1validatingadmissionpolicybindings~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/admissionregistration.k8s.io/v1/validatingadmissionpolicybindings/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1validatingadmissionpolicybindings~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/admissionregistration.k8s.io/v1/validatingadmissionpolicybindings/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1validatingadmissionpolicybindings~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1/validatingwebhookconfigurations` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1validatingwebhookconfigurations/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/admissionregistration.k8s.io/v1/validatingwebhookconfigurations` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1validatingwebhookconfigurations/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1/validatingwebhookconfigurations/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1validatingwebhookconfigurations~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/admissionregistration.k8s.io/v1/validatingwebhookconfigurations/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1validatingwebhookconfigurations~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/admissionregistration.k8s.io/v1/validatingwebhookconfigurations/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1~1validatingwebhookconfigurations~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1alpha1/mutatingadmissionpolicies` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1alpha1~1mutatingadmissionpolicies/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/admissionregistration.k8s.io/v1alpha1/mutatingadmissionpolicies` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1alpha1~1mutatingadmissionpolicies/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1alpha1/mutatingadmissionpolicies/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1alpha1~1mutatingadmissionpolicies~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/admissionregistration.k8s.io/v1alpha1/mutatingadmissionpolicies/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1alpha1~1mutatingadmissionpolicies~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/admissionregistration.k8s.io/v1alpha1/mutatingadmissionpolicies/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1alpha1~1mutatingadmissionpolicies~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1alpha1/mutatingadmissionpolicybindings` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1alpha1~1mutatingadmissionpolicybindings/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/admissionregistration.k8s.io/v1alpha1/mutatingadmissionpolicybindings` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1alpha1~1mutatingadmissionpolicybindings/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1alpha1/mutatingadmissionpolicybindings/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1alpha1~1mutatingadmissionpolicybindings~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/admissionregistration.k8s.io/v1alpha1/mutatingadmissionpolicybindings/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1alpha1~1mutatingadmissionpolicybindings~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/admissionregistration.k8s.io/v1alpha1/mutatingadmissionpolicybindings/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1alpha1~1mutatingadmissionpolicybindings~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1beta1/mutatingadmissionpolicies` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1beta1~1mutatingadmissionpolicies/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/admissionregistration.k8s.io/v1beta1/mutatingadmissionpolicies` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1beta1~1mutatingadmissionpolicies/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1beta1/mutatingadmissionpolicies/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1beta1~1mutatingadmissionpolicies~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/admissionregistration.k8s.io/v1beta1/mutatingadmissionpolicies/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1beta1~1mutatingadmissionpolicies~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/admissionregistration.k8s.io/v1beta1/mutatingadmissionpolicies/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1beta1~1mutatingadmissionpolicies~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1beta1/mutatingadmissionpolicybindings` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1beta1~1mutatingadmissionpolicybindings/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/admissionregistration.k8s.io/v1beta1/mutatingadmissionpolicybindings` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1beta1~1mutatingadmissionpolicybindings/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/admissionregistration.k8s.io/v1beta1/mutatingadmissionpolicybindings/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1beta1~1mutatingadmissionpolicybindings~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/admissionregistration.k8s.io/v1beta1/mutatingadmissionpolicybindings/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1beta1~1mutatingadmissionpolicybindings~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/admissionregistration.k8s.io/v1beta1/mutatingadmissionpolicybindings/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1admissionregistration.k8s.io~1v1beta1~1mutatingadmissionpolicybindings~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/apiextensions.k8s.io/v1/customresourcedefinitions` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apiextensions.k8s.io~1v1~1customresourcedefinitions/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/apiextensions.k8s.io/v1/customresourcedefinitions` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apiextensions.k8s.io~1v1~1customresourcedefinitions/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/apiextensions.k8s.io/v1/customresourcedefinitions/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apiextensions.k8s.io~1v1~1customresourcedefinitions~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/apiextensions.k8s.io/v1/customresourcedefinitions/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apiextensions.k8s.io~1v1~1customresourcedefinitions~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/apiextensions.k8s.io/v1/customresourcedefinitions/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apiextensions.k8s.io~1v1~1customresourcedefinitions~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/apiextensions.k8s.io/v1/customresourcedefinitions/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apiextensions.k8s.io~1v1~1customresourcedefinitions~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/apiextensions.k8s.io/v1/customresourcedefinitions/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apiextensions.k8s.io~1v1~1customresourcedefinitions~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/apiregistration.k8s.io/v1/apiservices` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apiregistration.k8s.io~1v1~1apiservices/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/apiregistration.k8s.io/v1/apiservices` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apiregistration.k8s.io~1v1~1apiservices/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/apiregistration.k8s.io/v1/apiservices/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apiregistration.k8s.io~1v1~1apiservices~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/apiregistration.k8s.io/v1/apiservices/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apiregistration.k8s.io~1v1~1apiservices~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/apiregistration.k8s.io/v1/apiservices/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apiregistration.k8s.io~1v1~1apiservices~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/apiregistration.k8s.io/v1/apiservices/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apiregistration.k8s.io~1v1~1apiservices~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/apiregistration.k8s.io/v1/apiservices/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apiregistration.k8s.io~1v1~1apiservices~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/apps/v1/namespaces/{namespace}/controllerrevisions` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1controllerrevisions/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/apps/v1/namespaces/{namespace}/controllerrevisions` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1controllerrevisions/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/apps/v1/namespaces/{namespace}/controllerrevisions/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1controllerrevisions~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/apps/v1/namespaces/{namespace}/controllerrevisions/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1controllerrevisions~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/apps/v1/namespaces/{namespace}/controllerrevisions/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1controllerrevisions~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/apps/v1/namespaces/{namespace}/daemonsets` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1daemonsets/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/apps/v1/namespaces/{namespace}/daemonsets` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1daemonsets/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/apps/v1/namespaces/{namespace}/daemonsets/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1daemonsets~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/apps/v1/namespaces/{namespace}/daemonsets/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1daemonsets~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/apps/v1/namespaces/{namespace}/daemonsets/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1daemonsets~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/apps/v1/namespaces/{namespace}/daemonsets/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1daemonsets~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/apps/v1/namespaces/{namespace}/daemonsets/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1daemonsets~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/apps/v1/namespaces/{namespace}/deployments` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1deployments/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/apps/v1/namespaces/{namespace}/deployments` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1deployments/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/apps/v1/namespaces/{namespace}/deployments/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1deployments~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/apps/v1/namespaces/{namespace}/deployments/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1deployments~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/apps/v1/namespaces/{namespace}/deployments/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1deployments~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/apps/v1/namespaces/{namespace}/deployments/{name}/scale` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1deployments~1{name}~1scale/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/apps/v1/namespaces/{namespace}/deployments/{name}/scale` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1deployments~1{name}~1scale/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/apps/v1/namespaces/{namespace}/deployments/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1deployments~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/apps/v1/namespaces/{namespace}/deployments/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1deployments~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/apps/v1/namespaces/{namespace}/replicasets` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1replicasets/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/apps/v1/namespaces/{namespace}/replicasets` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1replicasets/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/apps/v1/namespaces/{namespace}/replicasets/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1replicasets~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/apps/v1/namespaces/{namespace}/replicasets/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1replicasets~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/apps/v1/namespaces/{namespace}/replicasets/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1replicasets~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/apps/v1/namespaces/{namespace}/replicasets/{name}/scale` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1replicasets~1{name}~1scale/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/apps/v1/namespaces/{namespace}/replicasets/{name}/scale` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1replicasets~1{name}~1scale/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/apps/v1/namespaces/{namespace}/replicasets/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1replicasets~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/apps/v1/namespaces/{namespace}/replicasets/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1replicasets~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/apps/v1/namespaces/{namespace}/statefulsets` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1statefulsets/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/apps/v1/namespaces/{namespace}/statefulsets` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1statefulsets/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/apps/v1/namespaces/{namespace}/statefulsets/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1statefulsets~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/apps/v1/namespaces/{namespace}/statefulsets/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1statefulsets~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/apps/v1/namespaces/{namespace}/statefulsets/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1statefulsets~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/apps/v1/namespaces/{namespace}/statefulsets/{name}/scale` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1statefulsets~1{name}~1scale/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/apps/v1/namespaces/{namespace}/statefulsets/{name}/scale` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1statefulsets~1{name}~1scale/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/apps/v1/namespaces/{namespace}/statefulsets/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1statefulsets~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/apps/v1/namespaces/{namespace}/statefulsets/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1apps~1v1~1namespaces~1{namespace}~1statefulsets~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/authentication.k8s.io/v1/selfsubjectreviews` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1authentication.k8s.io~1v1~1selfsubjectreviews/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/authentication.k8s.io/v1/tokenreviews` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1authentication.k8s.io~1v1~1tokenreviews/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/authorization.k8s.io/v1/namespaces/{namespace}/localsubjectaccessreviews` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1authorization.k8s.io~1v1~1namespaces~1{namespace}~1localsubjectaccessreviews/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/authorization.k8s.io/v1/selfsubjectaccessreviews` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1authorization.k8s.io~1v1~1selfsubjectaccessreviews/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/authorization.k8s.io/v1/selfsubjectrulesreviews` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1authorization.k8s.io~1v1~1selfsubjectrulesreviews/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/authorization.k8s.io/v1/subjectaccessreviews` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1authorization.k8s.io~1v1~1subjectaccessreviews/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/autoscaling/v1/namespaces/{namespace}/horizontalpodautoscalers` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1autoscaling~1v1~1namespaces~1{namespace}~1horizontalpodautoscalers/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/autoscaling/v1/namespaces/{namespace}/horizontalpodautoscalers` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1autoscaling~1v1~1namespaces~1{namespace}~1horizontalpodautoscalers/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/autoscaling/v1/namespaces/{namespace}/horizontalpodautoscalers/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1autoscaling~1v1~1namespaces~1{namespace}~1horizontalpodautoscalers~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/autoscaling/v1/namespaces/{namespace}/horizontalpodautoscalers/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1autoscaling~1v1~1namespaces~1{namespace}~1horizontalpodautoscalers~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/autoscaling/v1/namespaces/{namespace}/horizontalpodautoscalers/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1autoscaling~1v1~1namespaces~1{namespace}~1horizontalpodautoscalers~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/autoscaling/v1/namespaces/{namespace}/horizontalpodautoscalers/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1autoscaling~1v1~1namespaces~1{namespace}~1horizontalpodautoscalers~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/autoscaling/v1/namespaces/{namespace}/horizontalpodautoscalers/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1autoscaling~1v1~1namespaces~1{namespace}~1horizontalpodautoscalers~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/autoscaling/v2/namespaces/{namespace}/horizontalpodautoscalers` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1autoscaling~1v2~1namespaces~1{namespace}~1horizontalpodautoscalers/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/autoscaling/v2/namespaces/{namespace}/horizontalpodautoscalers` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1autoscaling~1v2~1namespaces~1{namespace}~1horizontalpodautoscalers/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/autoscaling/v2/namespaces/{namespace}/horizontalpodautoscalers/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1autoscaling~1v2~1namespaces~1{namespace}~1horizontalpodautoscalers~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/autoscaling/v2/namespaces/{namespace}/horizontalpodautoscalers/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1autoscaling~1v2~1namespaces~1{namespace}~1horizontalpodautoscalers~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/autoscaling/v2/namespaces/{namespace}/horizontalpodautoscalers/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1autoscaling~1v2~1namespaces~1{namespace}~1horizontalpodautoscalers~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/autoscaling/v2/namespaces/{namespace}/horizontalpodautoscalers/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1autoscaling~1v2~1namespaces~1{namespace}~1horizontalpodautoscalers~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/autoscaling/v2/namespaces/{namespace}/horizontalpodautoscalers/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1autoscaling~1v2~1namespaces~1{namespace}~1horizontalpodautoscalers~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/batch/v1/namespaces/{namespace}/cronjobs` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1batch~1v1~1namespaces~1{namespace}~1cronjobs/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/batch/v1/namespaces/{namespace}/cronjobs` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1batch~1v1~1namespaces~1{namespace}~1cronjobs/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/batch/v1/namespaces/{namespace}/cronjobs/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1batch~1v1~1namespaces~1{namespace}~1cronjobs~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/batch/v1/namespaces/{namespace}/cronjobs/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1batch~1v1~1namespaces~1{namespace}~1cronjobs~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/batch/v1/namespaces/{namespace}/cronjobs/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1batch~1v1~1namespaces~1{namespace}~1cronjobs~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/batch/v1/namespaces/{namespace}/cronjobs/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1batch~1v1~1namespaces~1{namespace}~1cronjobs~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/batch/v1/namespaces/{namespace}/cronjobs/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1batch~1v1~1namespaces~1{namespace}~1cronjobs~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/batch/v1/namespaces/{namespace}/jobs` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1batch~1v1~1namespaces~1{namespace}~1jobs/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/batch/v1/namespaces/{namespace}/jobs` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1batch~1v1~1namespaces~1{namespace}~1jobs/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/batch/v1/namespaces/{namespace}/jobs/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1batch~1v1~1namespaces~1{namespace}~1jobs~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/batch/v1/namespaces/{namespace}/jobs/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1batch~1v1~1namespaces~1{namespace}~1jobs~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/batch/v1/namespaces/{namespace}/jobs/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1batch~1v1~1namespaces~1{namespace}~1jobs~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/batch/v1/namespaces/{namespace}/jobs/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1batch~1v1~1namespaces~1{namespace}~1jobs~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/batch/v1/namespaces/{namespace}/jobs/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1batch~1v1~1namespaces~1{namespace}~1jobs~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/certificates.k8s.io/v1/certificatesigningrequests` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1certificatesigningrequests/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/certificates.k8s.io/v1/certificatesigningrequests` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1certificatesigningrequests/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/certificates.k8s.io/v1/certificatesigningrequests/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1certificatesigningrequests~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/certificates.k8s.io/v1/certificatesigningrequests/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1certificatesigningrequests~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/certificates.k8s.io/v1/certificatesigningrequests/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1certificatesigningrequests~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/certificates.k8s.io/v1/certificatesigningrequests/{name}/approval` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1certificatesigningrequests~1{name}~1approval/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/certificates.k8s.io/v1/certificatesigningrequests/{name}/approval` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1certificatesigningrequests~1{name}~1approval/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/certificates.k8s.io/v1/certificatesigningrequests/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1certificatesigningrequests~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/certificates.k8s.io/v1/certificatesigningrequests/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1certificatesigningrequests~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/certificates.k8s.io/v1/clustertrustbundles` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1clustertrustbundles/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/certificates.k8s.io/v1/clustertrustbundles` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1clustertrustbundles/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/certificates.k8s.io/v1/clustertrustbundles/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1clustertrustbundles~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/certificates.k8s.io/v1/clustertrustbundles/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1clustertrustbundles~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/certificates.k8s.io/v1/clustertrustbundles/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1clustertrustbundles~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/certificates.k8s.io/v1/namespaces/{namespace}/podcertificaterequests` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1namespaces~1{namespace}~1podcertificaterequests/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/certificates.k8s.io/v1/namespaces/{namespace}/podcertificaterequests` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1namespaces~1{namespace}~1podcertificaterequests/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/certificates.k8s.io/v1/namespaces/{namespace}/podcertificaterequests/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1namespaces~1{namespace}~1podcertificaterequests~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/certificates.k8s.io/v1/namespaces/{namespace}/podcertificaterequests/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1namespaces~1{namespace}~1podcertificaterequests~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/certificates.k8s.io/v1/namespaces/{namespace}/podcertificaterequests/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1namespaces~1{namespace}~1podcertificaterequests~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/certificates.k8s.io/v1/namespaces/{namespace}/podcertificaterequests/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1namespaces~1{namespace}~1podcertificaterequests~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/certificates.k8s.io/v1/namespaces/{namespace}/podcertificaterequests/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1~1namespaces~1{namespace}~1podcertificaterequests~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/certificates.k8s.io/v1beta1/clustertrustbundles` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1beta1~1clustertrustbundles/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/certificates.k8s.io/v1beta1/clustertrustbundles` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1beta1~1clustertrustbundles/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/certificates.k8s.io/v1beta1/clustertrustbundles/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1beta1~1clustertrustbundles~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/certificates.k8s.io/v1beta1/clustertrustbundles/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1beta1~1clustertrustbundles~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/certificates.k8s.io/v1beta1/clustertrustbundles/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1beta1~1clustertrustbundles~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/certificates.k8s.io/v1beta1/namespaces/{namespace}/podcertificaterequests` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1beta1~1namespaces~1{namespace}~1podcertificaterequests/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/certificates.k8s.io/v1beta1/namespaces/{namespace}/podcertificaterequests` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1beta1~1namespaces~1{namespace}~1podcertificaterequests/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/certificates.k8s.io/v1beta1/namespaces/{namespace}/podcertificaterequests/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1beta1~1namespaces~1{namespace}~1podcertificaterequests~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/certificates.k8s.io/v1beta1/namespaces/{namespace}/podcertificaterequests/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1beta1~1namespaces~1{namespace}~1podcertificaterequests~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/certificates.k8s.io/v1beta1/namespaces/{namespace}/podcertificaterequests/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1beta1~1namespaces~1{namespace}~1podcertificaterequests~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/certificates.k8s.io/v1beta1/namespaces/{namespace}/podcertificaterequests/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1beta1~1namespaces~1{namespace}~1podcertificaterequests~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/certificates.k8s.io/v1beta1/namespaces/{namespace}/podcertificaterequests/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1certificates.k8s.io~1v1beta1~1namespaces~1{namespace}~1podcertificaterequests~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/coordination.k8s.io/v1/namespaces/{namespace}/leases` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1coordination.k8s.io~1v1~1namespaces~1{namespace}~1leases/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/coordination.k8s.io/v1/namespaces/{namespace}/leases` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1coordination.k8s.io~1v1~1namespaces~1{namespace}~1leases/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/coordination.k8s.io/v1/namespaces/{namespace}/leases/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1coordination.k8s.io~1v1~1namespaces~1{namespace}~1leases~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/coordination.k8s.io/v1/namespaces/{namespace}/leases/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1coordination.k8s.io~1v1~1namespaces~1{namespace}~1leases~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/coordination.k8s.io/v1/namespaces/{namespace}/leases/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1coordination.k8s.io~1v1~1namespaces~1{namespace}~1leases~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/coordination.k8s.io/v1alpha2/namespaces/{namespace}/leasecandidates` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1coordination.k8s.io~1v1alpha2~1namespaces~1{namespace}~1leasecandidates/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/coordination.k8s.io/v1alpha2/namespaces/{namespace}/leasecandidates` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1coordination.k8s.io~1v1alpha2~1namespaces~1{namespace}~1leasecandidates/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/coordination.k8s.io/v1alpha2/namespaces/{namespace}/leasecandidates/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1coordination.k8s.io~1v1alpha2~1namespaces~1{namespace}~1leasecandidates~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/coordination.k8s.io/v1alpha2/namespaces/{namespace}/leasecandidates/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1coordination.k8s.io~1v1alpha2~1namespaces~1{namespace}~1leasecandidates~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/coordination.k8s.io/v1alpha2/namespaces/{namespace}/leasecandidates/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1coordination.k8s.io~1v1alpha2~1namespaces~1{namespace}~1leasecandidates~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/coordination.k8s.io/v1beta1/namespaces/{namespace}/leasecandidates` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1coordination.k8s.io~1v1beta1~1namespaces~1{namespace}~1leasecandidates/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/coordination.k8s.io/v1beta1/namespaces/{namespace}/leasecandidates` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1coordination.k8s.io~1v1beta1~1namespaces~1{namespace}~1leasecandidates/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/coordination.k8s.io/v1beta1/namespaces/{namespace}/leasecandidates/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1coordination.k8s.io~1v1beta1~1namespaces~1{namespace}~1leasecandidates~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/coordination.k8s.io/v1beta1/namespaces/{namespace}/leasecandidates/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1coordination.k8s.io~1v1beta1~1namespaces~1{namespace}~1leasecandidates~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/coordination.k8s.io/v1beta1/namespaces/{namespace}/leasecandidates/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1coordination.k8s.io~1v1beta1~1namespaces~1{namespace}~1leasecandidates~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/discovery.k8s.io/v1/namespaces/{namespace}/endpointslices` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1discovery.k8s.io~1v1~1namespaces~1{namespace}~1endpointslices/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/discovery.k8s.io/v1/namespaces/{namespace}/endpointslices` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1discovery.k8s.io~1v1~1namespaces~1{namespace}~1endpointslices/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/discovery.k8s.io/v1/namespaces/{namespace}/endpointslices/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1discovery.k8s.io~1v1~1namespaces~1{namespace}~1endpointslices~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/discovery.k8s.io/v1/namespaces/{namespace}/endpointslices/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1discovery.k8s.io~1v1~1namespaces~1{namespace}~1endpointslices~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/discovery.k8s.io/v1/namespaces/{namespace}/endpointslices/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1discovery.k8s.io~1v1~1namespaces~1{namespace}~1endpointslices~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/events.k8s.io/v1/namespaces/{namespace}/events` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1events.k8s.io~1v1~1namespaces~1{namespace}~1events/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/events.k8s.io/v1/namespaces/{namespace}/events` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1events.k8s.io~1v1~1namespaces~1{namespace}~1events/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/events.k8s.io/v1/namespaces/{namespace}/events/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1events.k8s.io~1v1~1namespaces~1{namespace}~1events~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/events.k8s.io/v1/namespaces/{namespace}/events/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1events.k8s.io~1v1~1namespaces~1{namespace}~1events~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/events.k8s.io/v1/namespaces/{namespace}/events/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1events.k8s.io~1v1~1namespaces~1{namespace}~1events~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/flowcontrol.apiserver.k8s.io/v1/flowschemas` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1flowcontrol.apiserver.k8s.io~1v1~1flowschemas/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/flowcontrol.apiserver.k8s.io/v1/flowschemas` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1flowcontrol.apiserver.k8s.io~1v1~1flowschemas/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/flowcontrol.apiserver.k8s.io/v1/flowschemas/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1flowcontrol.apiserver.k8s.io~1v1~1flowschemas~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/flowcontrol.apiserver.k8s.io/v1/flowschemas/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1flowcontrol.apiserver.k8s.io~1v1~1flowschemas~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/flowcontrol.apiserver.k8s.io/v1/flowschemas/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1flowcontrol.apiserver.k8s.io~1v1~1flowschemas~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/flowcontrol.apiserver.k8s.io/v1/flowschemas/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1flowcontrol.apiserver.k8s.io~1v1~1flowschemas~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/flowcontrol.apiserver.k8s.io/v1/flowschemas/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1flowcontrol.apiserver.k8s.io~1v1~1flowschemas~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/flowcontrol.apiserver.k8s.io/v1/prioritylevelconfigurations` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1flowcontrol.apiserver.k8s.io~1v1~1prioritylevelconfigurations/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/flowcontrol.apiserver.k8s.io/v1/prioritylevelconfigurations` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1flowcontrol.apiserver.k8s.io~1v1~1prioritylevelconfigurations/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/flowcontrol.apiserver.k8s.io/v1/prioritylevelconfigurations/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1flowcontrol.apiserver.k8s.io~1v1~1prioritylevelconfigurations~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/flowcontrol.apiserver.k8s.io/v1/prioritylevelconfigurations/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1flowcontrol.apiserver.k8s.io~1v1~1prioritylevelconfigurations~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/flowcontrol.apiserver.k8s.io/v1/prioritylevelconfigurations/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1flowcontrol.apiserver.k8s.io~1v1~1prioritylevelconfigurations~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/flowcontrol.apiserver.k8s.io/v1/prioritylevelconfigurations/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1flowcontrol.apiserver.k8s.io~1v1~1prioritylevelconfigurations~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/flowcontrol.apiserver.k8s.io/v1/prioritylevelconfigurations/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1flowcontrol.apiserver.k8s.io~1v1~1prioritylevelconfigurations~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/internal.apiserver.k8s.io/v1alpha1/storageversions` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1internal.apiserver.k8s.io~1v1alpha1~1storageversions/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/internal.apiserver.k8s.io/v1alpha1/storageversions` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1internal.apiserver.k8s.io~1v1alpha1~1storageversions/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/internal.apiserver.k8s.io/v1alpha1/storageversions/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1internal.apiserver.k8s.io~1v1alpha1~1storageversions~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/internal.apiserver.k8s.io/v1alpha1/storageversions/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1internal.apiserver.k8s.io~1v1alpha1~1storageversions~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/internal.apiserver.k8s.io/v1alpha1/storageversions/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1internal.apiserver.k8s.io~1v1alpha1~1storageversions~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/internal.apiserver.k8s.io/v1alpha1/storageversions/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1internal.apiserver.k8s.io~1v1alpha1~1storageversions~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/internal.apiserver.k8s.io/v1alpha1/storageversions/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1internal.apiserver.k8s.io~1v1alpha1~1storageversions~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/lifecycle.k8s.io/v1alpha1/namespaces/{namespace}/evictionrequests` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1lifecycle.k8s.io~1v1alpha1~1namespaces~1{namespace}~1evictionrequests/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/lifecycle.k8s.io/v1alpha1/namespaces/{namespace}/evictionrequests` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1lifecycle.k8s.io~1v1alpha1~1namespaces~1{namespace}~1evictionrequests/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/lifecycle.k8s.io/v1alpha1/namespaces/{namespace}/evictionrequests/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1lifecycle.k8s.io~1v1alpha1~1namespaces~1{namespace}~1evictionrequests~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/lifecycle.k8s.io/v1alpha1/namespaces/{namespace}/evictionrequests/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1lifecycle.k8s.io~1v1alpha1~1namespaces~1{namespace}~1evictionrequests~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/lifecycle.k8s.io/v1alpha1/namespaces/{namespace}/evictionrequests/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1lifecycle.k8s.io~1v1alpha1~1namespaces~1{namespace}~1evictionrequests~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/lifecycle.k8s.io/v1alpha1/namespaces/{namespace}/evictionrequests/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1lifecycle.k8s.io~1v1alpha1~1namespaces~1{namespace}~1evictionrequests~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/lifecycle.k8s.io/v1alpha1/namespaces/{namespace}/evictionrequests/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1lifecycle.k8s.io~1v1alpha1~1namespaces~1{namespace}~1evictionrequests~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/lifecycle.k8s.io/v1alpha1/namespaces/{namespace}/evictions` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1lifecycle.k8s.io~1v1alpha1~1namespaces~1{namespace}~1evictions/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/lifecycle.k8s.io/v1alpha1/namespaces/{namespace}/evictions` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1lifecycle.k8s.io~1v1alpha1~1namespaces~1{namespace}~1evictions/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/lifecycle.k8s.io/v1alpha1/namespaces/{namespace}/evictions/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1lifecycle.k8s.io~1v1alpha1~1namespaces~1{namespace}~1evictions~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/lifecycle.k8s.io/v1alpha1/namespaces/{namespace}/evictions/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1lifecycle.k8s.io~1v1alpha1~1namespaces~1{namespace}~1evictions~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/lifecycle.k8s.io/v1alpha1/namespaces/{namespace}/evictions/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1lifecycle.k8s.io~1v1alpha1~1namespaces~1{namespace}~1evictions~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/lifecycle.k8s.io/v1alpha1/namespaces/{namespace}/evictions/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1lifecycle.k8s.io~1v1alpha1~1namespaces~1{namespace}~1evictions~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/lifecycle.k8s.io/v1alpha1/namespaces/{namespace}/evictions/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1lifecycle.k8s.io~1v1alpha1~1namespaces~1{namespace}~1evictions~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/networking.k8s.io/v1/ingressclasses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1ingressclasses/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/networking.k8s.io/v1/ingressclasses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1ingressclasses/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/networking.k8s.io/v1/ingressclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1ingressclasses~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/networking.k8s.io/v1/ingressclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1ingressclasses~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/networking.k8s.io/v1/ingressclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1ingressclasses~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/networking.k8s.io/v1/ipaddresses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1ipaddresses/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/networking.k8s.io/v1/ipaddresses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1ipaddresses/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/networking.k8s.io/v1/ipaddresses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1ipaddresses~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/networking.k8s.io/v1/ipaddresses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1ipaddresses~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/networking.k8s.io/v1/ipaddresses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1ipaddresses~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/networking.k8s.io/v1/namespaces/{namespace}/ingresses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1namespaces~1{namespace}~1ingresses/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/networking.k8s.io/v1/namespaces/{namespace}/ingresses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1namespaces~1{namespace}~1ingresses/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/networking.k8s.io/v1/namespaces/{namespace}/ingresses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1namespaces~1{namespace}~1ingresses~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/networking.k8s.io/v1/namespaces/{namespace}/ingresses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1namespaces~1{namespace}~1ingresses~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/networking.k8s.io/v1/namespaces/{namespace}/ingresses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1namespaces~1{namespace}~1ingresses~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/networking.k8s.io/v1/namespaces/{namespace}/ingresses/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1namespaces~1{namespace}~1ingresses~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/networking.k8s.io/v1/namespaces/{namespace}/ingresses/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1namespaces~1{namespace}~1ingresses~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/networking.k8s.io/v1/namespaces/{namespace}/networkpolicies` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1namespaces~1{namespace}~1networkpolicies/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/networking.k8s.io/v1/namespaces/{namespace}/networkpolicies` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1namespaces~1{namespace}~1networkpolicies/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/networking.k8s.io/v1/namespaces/{namespace}/networkpolicies/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1namespaces~1{namespace}~1networkpolicies~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/networking.k8s.io/v1/namespaces/{namespace}/networkpolicies/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1namespaces~1{namespace}~1networkpolicies~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/networking.k8s.io/v1/namespaces/{namespace}/networkpolicies/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1namespaces~1{namespace}~1networkpolicies~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/networking.k8s.io/v1/servicecidrs` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1servicecidrs/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/networking.k8s.io/v1/servicecidrs` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1servicecidrs/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/networking.k8s.io/v1/servicecidrs/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1servicecidrs~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/networking.k8s.io/v1/servicecidrs/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1servicecidrs~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/networking.k8s.io/v1/servicecidrs/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1servicecidrs~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/networking.k8s.io/v1/servicecidrs/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1servicecidrs~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/networking.k8s.io/v1/servicecidrs/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1networking.k8s.io~1v1~1servicecidrs~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/node.k8s.io/v1/runtimeclasses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1node.k8s.io~1v1~1runtimeclasses/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/node.k8s.io/v1/runtimeclasses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1node.k8s.io~1v1~1runtimeclasses/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/node.k8s.io/v1/runtimeclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1node.k8s.io~1v1~1runtimeclasses~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/node.k8s.io/v1/runtimeclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1node.k8s.io~1v1~1runtimeclasses~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/node.k8s.io/v1/runtimeclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1node.k8s.io~1v1~1runtimeclasses~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/policy/v1/namespaces/{namespace}/poddisruptionbudgets` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1policy~1v1~1namespaces~1{namespace}~1poddisruptionbudgets/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/policy/v1/namespaces/{namespace}/poddisruptionbudgets` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1policy~1v1~1namespaces~1{namespace}~1poddisruptionbudgets/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/policy/v1/namespaces/{namespace}/poddisruptionbudgets/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1policy~1v1~1namespaces~1{namespace}~1poddisruptionbudgets~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/policy/v1/namespaces/{namespace}/poddisruptionbudgets/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1policy~1v1~1namespaces~1{namespace}~1poddisruptionbudgets~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/policy/v1/namespaces/{namespace}/poddisruptionbudgets/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1policy~1v1~1namespaces~1{namespace}~1poddisruptionbudgets~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/policy/v1/namespaces/{namespace}/poddisruptionbudgets/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1policy~1v1~1namespaces~1{namespace}~1poddisruptionbudgets~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/policy/v1/namespaces/{namespace}/poddisruptionbudgets/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1policy~1v1~1namespaces~1{namespace}~1poddisruptionbudgets~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/rbac.authorization.k8s.io/v1/clusterrolebindings` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1clusterrolebindings/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/rbac.authorization.k8s.io/v1/clusterrolebindings` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1clusterrolebindings/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/rbac.authorization.k8s.io/v1/clusterrolebindings/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1clusterrolebindings~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/rbac.authorization.k8s.io/v1/clusterrolebindings/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1clusterrolebindings~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/rbac.authorization.k8s.io/v1/clusterrolebindings/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1clusterrolebindings~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/rbac.authorization.k8s.io/v1/clusterroles` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1clusterroles/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/rbac.authorization.k8s.io/v1/clusterroles` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1clusterroles/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/rbac.authorization.k8s.io/v1/clusterroles/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1clusterroles~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/rbac.authorization.k8s.io/v1/clusterroles/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1clusterroles~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/rbac.authorization.k8s.io/v1/clusterroles/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1clusterroles~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/rbac.authorization.k8s.io/v1/namespaces/{namespace}/rolebindings` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1namespaces~1{namespace}~1rolebindings/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/rbac.authorization.k8s.io/v1/namespaces/{namespace}/rolebindings` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1namespaces~1{namespace}~1rolebindings/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/rbac.authorization.k8s.io/v1/namespaces/{namespace}/rolebindings/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1namespaces~1{namespace}~1rolebindings~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/rbac.authorization.k8s.io/v1/namespaces/{namespace}/rolebindings/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1namespaces~1{namespace}~1rolebindings~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/rbac.authorization.k8s.io/v1/namespaces/{namespace}/rolebindings/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1namespaces~1{namespace}~1rolebindings~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/rbac.authorization.k8s.io/v1/namespaces/{namespace}/roles` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1namespaces~1{namespace}~1roles/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/rbac.authorization.k8s.io/v1/namespaces/{namespace}/roles` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1namespaces~1{namespace}~1roles/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/rbac.authorization.k8s.io/v1/namespaces/{namespace}/roles/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1namespaces~1{namespace}~1roles~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/rbac.authorization.k8s.io/v1/namespaces/{namespace}/roles/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1namespaces~1{namespace}~1roles~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/rbac.authorization.k8s.io/v1/namespaces/{namespace}/roles/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1rbac.authorization.k8s.io~1v1~1namespaces~1{namespace}~1roles~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1/deviceclasses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1deviceclasses/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/resource.k8s.io/v1/deviceclasses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1deviceclasses/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1/deviceclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1deviceclasses~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1/deviceclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1deviceclasses~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1/deviceclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1deviceclasses~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1/devicetaintrules` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1devicetaintrules/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/resource.k8s.io/v1/devicetaintrules` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1devicetaintrules/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1/devicetaintrules/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1devicetaintrules~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1/devicetaintrules/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1devicetaintrules~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1/devicetaintrules/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1devicetaintrules~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1/devicetaintrules/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1devicetaintrules~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1/devicetaintrules/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1devicetaintrules~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1/namespaces/{namespace}/resourceclaims` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1namespaces~1{namespace}~1resourceclaims/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/resource.k8s.io/v1/namespaces/{namespace}/resourceclaims` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1namespaces~1{namespace}~1resourceclaims/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1/namespaces/{namespace}/resourceclaims/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1namespaces~1{namespace}~1resourceclaims~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1/namespaces/{namespace}/resourceclaims/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1namespaces~1{namespace}~1resourceclaims~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1/namespaces/{namespace}/resourceclaims/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1namespaces~1{namespace}~1resourceclaims~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1/namespaces/{namespace}/resourceclaims/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1namespaces~1{namespace}~1resourceclaims~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1/namespaces/{namespace}/resourceclaims/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1namespaces~1{namespace}~1resourceclaims~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1/namespaces/{namespace}/resourceclaimtemplates` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1namespaces~1{namespace}~1resourceclaimtemplates/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/resource.k8s.io/v1/namespaces/{namespace}/resourceclaimtemplates` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1namespaces~1{namespace}~1resourceclaimtemplates/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1/namespaces/{namespace}/resourceclaimtemplates/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1namespaces~1{namespace}~1resourceclaimtemplates~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1/namespaces/{namespace}/resourceclaimtemplates/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1namespaces~1{namespace}~1resourceclaimtemplates~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1/namespaces/{namespace}/resourceclaimtemplates/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1namespaces~1{namespace}~1resourceclaimtemplates~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1/resourceslices` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1resourceslices/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/resource.k8s.io/v1/resourceslices` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1resourceslices/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1/resourceslices/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1resourceslices~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1/resourceslices/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1resourceslices~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1/resourceslices/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1~1resourceslices~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1alpha3/devicetaintrules` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1alpha3~1devicetaintrules/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/resource.k8s.io/v1alpha3/devicetaintrules` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1alpha3~1devicetaintrules/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1alpha3/devicetaintrules/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1alpha3~1devicetaintrules~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1alpha3/devicetaintrules/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1alpha3~1devicetaintrules~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1alpha3/devicetaintrules/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1alpha3~1devicetaintrules~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1alpha3/devicetaintrules/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1alpha3~1devicetaintrules~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1alpha3/devicetaintrules/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1alpha3~1devicetaintrules~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1alpha3/resourcepoolstatusrequests` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1alpha3~1resourcepoolstatusrequests/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/resource.k8s.io/v1alpha3/resourcepoolstatusrequests` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1alpha3~1resourcepoolstatusrequests/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1alpha3/resourcepoolstatusrequests/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1alpha3~1resourcepoolstatusrequests~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1alpha3/resourcepoolstatusrequests/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1alpha3~1resourcepoolstatusrequests~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1alpha3/resourcepoolstatusrequests/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1alpha3~1resourcepoolstatusrequests~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1alpha3/resourcepoolstatusrequests/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1alpha3~1resourcepoolstatusrequests~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1alpha3/resourcepoolstatusrequests/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1alpha3~1resourcepoolstatusrequests~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1beta1/deviceclasses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1deviceclasses/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/resource.k8s.io/v1beta1/deviceclasses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1deviceclasses/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1beta1/deviceclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1deviceclasses~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1beta1/deviceclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1deviceclasses~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1beta1/deviceclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1deviceclasses~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1beta1/namespaces/{namespace}/resourceclaims` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1namespaces~1{namespace}~1resourceclaims/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/resource.k8s.io/v1beta1/namespaces/{namespace}/resourceclaims` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1namespaces~1{namespace}~1resourceclaims/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1beta1/namespaces/{namespace}/resourceclaims/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1namespaces~1{namespace}~1resourceclaims~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1beta1/namespaces/{namespace}/resourceclaims/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1namespaces~1{namespace}~1resourceclaims~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1beta1/namespaces/{namespace}/resourceclaims/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1namespaces~1{namespace}~1resourceclaims~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1beta1/namespaces/{namespace}/resourceclaims/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1namespaces~1{namespace}~1resourceclaims~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1beta1/namespaces/{namespace}/resourceclaims/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1namespaces~1{namespace}~1resourceclaims~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1beta1/namespaces/{namespace}/resourceclaimtemplates` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1namespaces~1{namespace}~1resourceclaimtemplates/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/resource.k8s.io/v1beta1/namespaces/{namespace}/resourceclaimtemplates` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1namespaces~1{namespace}~1resourceclaimtemplates/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1beta1/namespaces/{namespace}/resourceclaimtemplates/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1namespaces~1{namespace}~1resourceclaimtemplates~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1beta1/namespaces/{namespace}/resourceclaimtemplates/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1namespaces~1{namespace}~1resourceclaimtemplates~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1beta1/namespaces/{namespace}/resourceclaimtemplates/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1namespaces~1{namespace}~1resourceclaimtemplates~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1beta1/resourceslices` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1resourceslices/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/resource.k8s.io/v1beta1/resourceslices` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1resourceslices/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1beta1/resourceslices/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1resourceslices~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1beta1/resourceslices/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1resourceslices~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1beta1/resourceslices/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta1~1resourceslices~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1beta2/deviceclasses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1deviceclasses/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/resource.k8s.io/v1beta2/deviceclasses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1deviceclasses/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1beta2/deviceclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1deviceclasses~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1beta2/deviceclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1deviceclasses~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1beta2/deviceclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1deviceclasses~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1beta2/devicetaintrules` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1devicetaintrules/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/resource.k8s.io/v1beta2/devicetaintrules` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1devicetaintrules/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1beta2/devicetaintrules/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1devicetaintrules~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1beta2/devicetaintrules/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1devicetaintrules~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1beta2/devicetaintrules/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1devicetaintrules~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1beta2/devicetaintrules/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1devicetaintrules~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1beta2/devicetaintrules/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1devicetaintrules~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1beta2/namespaces/{namespace}/resourceclaims` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1namespaces~1{namespace}~1resourceclaims/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/resource.k8s.io/v1beta2/namespaces/{namespace}/resourceclaims` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1namespaces~1{namespace}~1resourceclaims/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1beta2/namespaces/{namespace}/resourceclaims/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1namespaces~1{namespace}~1resourceclaims~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1beta2/namespaces/{namespace}/resourceclaims/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1namespaces~1{namespace}~1resourceclaims~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1beta2/namespaces/{namespace}/resourceclaims/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1namespaces~1{namespace}~1resourceclaims~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1beta2/namespaces/{namespace}/resourceclaims/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1namespaces~1{namespace}~1resourceclaims~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1beta2/namespaces/{namespace}/resourceclaims/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1namespaces~1{namespace}~1resourceclaims~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1beta2/namespaces/{namespace}/resourceclaimtemplates` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1namespaces~1{namespace}~1resourceclaimtemplates/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/resource.k8s.io/v1beta2/namespaces/{namespace}/resourceclaimtemplates` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1namespaces~1{namespace}~1resourceclaimtemplates/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1beta2/namespaces/{namespace}/resourceclaimtemplates/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1namespaces~1{namespace}~1resourceclaimtemplates~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1beta2/namespaces/{namespace}/resourceclaimtemplates/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1namespaces~1{namespace}~1resourceclaimtemplates~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1beta2/namespaces/{namespace}/resourceclaimtemplates/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1namespaces~1{namespace}~1resourceclaimtemplates~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1beta2/resourceslices` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1resourceslices/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/resource.k8s.io/v1beta2/resourceslices` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1resourceslices/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/resource.k8s.io/v1beta2/resourceslices/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1resourceslices~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/resource.k8s.io/v1beta2/resourceslices/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1resourceslices~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/resource.k8s.io/v1beta2/resourceslices/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1resource.k8s.io~1v1beta2~1resourceslices~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/scheduling.k8s.io/v1/priorityclasses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1~1priorityclasses/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/scheduling.k8s.io/v1/priorityclasses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1~1priorityclasses/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/scheduling.k8s.io/v1/priorityclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1~1priorityclasses~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/scheduling.k8s.io/v1/priorityclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1~1priorityclasses~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/scheduling.k8s.io/v1/priorityclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1~1priorityclasses~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/scheduling.k8s.io/v1alpha3/namespaces/{namespace}/compositepodgroups` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1alpha3~1namespaces~1{namespace}~1compositepodgroups/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/scheduling.k8s.io/v1alpha3/namespaces/{namespace}/compositepodgroups` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1alpha3~1namespaces~1{namespace}~1compositepodgroups/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/scheduling.k8s.io/v1alpha3/namespaces/{namespace}/compositepodgroups/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1alpha3~1namespaces~1{namespace}~1compositepodgroups~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/scheduling.k8s.io/v1alpha3/namespaces/{namespace}/compositepodgroups/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1alpha3~1namespaces~1{namespace}~1compositepodgroups~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/scheduling.k8s.io/v1alpha3/namespaces/{namespace}/compositepodgroups/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1alpha3~1namespaces~1{namespace}~1compositepodgroups~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/scheduling.k8s.io/v1alpha3/namespaces/{namespace}/compositepodgroups/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1alpha3~1namespaces~1{namespace}~1compositepodgroups~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/scheduling.k8s.io/v1alpha3/namespaces/{namespace}/compositepodgroups/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1alpha3~1namespaces~1{namespace}~1compositepodgroups~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/scheduling.k8s.io/v1alpha3/namespaces/{namespace}/podgroups` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1alpha3~1namespaces~1{namespace}~1podgroups/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/scheduling.k8s.io/v1alpha3/namespaces/{namespace}/podgroups` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1alpha3~1namespaces~1{namespace}~1podgroups/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/scheduling.k8s.io/v1alpha3/namespaces/{namespace}/podgroups/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1alpha3~1namespaces~1{namespace}~1podgroups~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/scheduling.k8s.io/v1alpha3/namespaces/{namespace}/podgroups/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1alpha3~1namespaces~1{namespace}~1podgroups~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/scheduling.k8s.io/v1alpha3/namespaces/{namespace}/podgroups/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1alpha3~1namespaces~1{namespace}~1podgroups~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/scheduling.k8s.io/v1alpha3/namespaces/{namespace}/podgroups/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1alpha3~1namespaces~1{namespace}~1podgroups~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/scheduling.k8s.io/v1alpha3/namespaces/{namespace}/podgroups/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1alpha3~1namespaces~1{namespace}~1podgroups~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/scheduling.k8s.io/v1alpha3/namespaces/{namespace}/workloads` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1alpha3~1namespaces~1{namespace}~1workloads/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/scheduling.k8s.io/v1alpha3/namespaces/{namespace}/workloads` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1alpha3~1namespaces~1{namespace}~1workloads/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/scheduling.k8s.io/v1alpha3/namespaces/{namespace}/workloads/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1alpha3~1namespaces~1{namespace}~1workloads~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/scheduling.k8s.io/v1alpha3/namespaces/{namespace}/workloads/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1alpha3~1namespaces~1{namespace}~1workloads~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/scheduling.k8s.io/v1alpha3/namespaces/{namespace}/workloads/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1alpha3~1namespaces~1{namespace}~1workloads~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/scheduling.k8s.io/v1beta1/namespaces/{namespace}/podgroups` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1beta1~1namespaces~1{namespace}~1podgroups/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/scheduling.k8s.io/v1beta1/namespaces/{namespace}/podgroups` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1beta1~1namespaces~1{namespace}~1podgroups/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/scheduling.k8s.io/v1beta1/namespaces/{namespace}/podgroups/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1beta1~1namespaces~1{namespace}~1podgroups~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/scheduling.k8s.io/v1beta1/namespaces/{namespace}/podgroups/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1beta1~1namespaces~1{namespace}~1podgroups~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/scheduling.k8s.io/v1beta1/namespaces/{namespace}/podgroups/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1beta1~1namespaces~1{namespace}~1podgroups~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/scheduling.k8s.io/v1beta1/namespaces/{namespace}/podgroups/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1beta1~1namespaces~1{namespace}~1podgroups~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/scheduling.k8s.io/v1beta1/namespaces/{namespace}/podgroups/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1beta1~1namespaces~1{namespace}~1podgroups~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/scheduling.k8s.io/v1beta1/namespaces/{namespace}/workloads` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1beta1~1namespaces~1{namespace}~1workloads/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/scheduling.k8s.io/v1beta1/namespaces/{namespace}/workloads` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1beta1~1namespaces~1{namespace}~1workloads/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/scheduling.k8s.io/v1beta1/namespaces/{namespace}/workloads/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1beta1~1namespaces~1{namespace}~1workloads~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/scheduling.k8s.io/v1beta1/namespaces/{namespace}/workloads/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1beta1~1namespaces~1{namespace}~1workloads~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/scheduling.k8s.io/v1beta1/namespaces/{namespace}/workloads/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1scheduling.k8s.io~1v1beta1~1namespaces~1{namespace}~1workloads~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/storage.k8s.io/v1/csidrivers` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1csidrivers/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/storage.k8s.io/v1/csidrivers` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1csidrivers/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/storage.k8s.io/v1/csidrivers/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1csidrivers~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/storage.k8s.io/v1/csidrivers/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1csidrivers~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/storage.k8s.io/v1/csidrivers/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1csidrivers~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/storage.k8s.io/v1/csinodes` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1csinodes/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/storage.k8s.io/v1/csinodes` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1csinodes/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/storage.k8s.io/v1/csinodes/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1csinodes~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/storage.k8s.io/v1/csinodes/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1csinodes~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/storage.k8s.io/v1/csinodes/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1csinodes~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/storage.k8s.io/v1/csinodes/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1csinodes~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/storage.k8s.io/v1/csinodes/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1csinodes~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/storage.k8s.io/v1/namespaces/{namespace}/csistoragecapacities` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1namespaces~1{namespace}~1csistoragecapacities/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/storage.k8s.io/v1/namespaces/{namespace}/csistoragecapacities` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1namespaces~1{namespace}~1csistoragecapacities/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/storage.k8s.io/v1/namespaces/{namespace}/csistoragecapacities/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1namespaces~1{namespace}~1csistoragecapacities~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/storage.k8s.io/v1/namespaces/{namespace}/csistoragecapacities/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1namespaces~1{namespace}~1csistoragecapacities~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/storage.k8s.io/v1/namespaces/{namespace}/csistoragecapacities/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1namespaces~1{namespace}~1csistoragecapacities~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/storage.k8s.io/v1/storageclasses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1storageclasses/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/storage.k8s.io/v1/storageclasses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1storageclasses/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/storage.k8s.io/v1/storageclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1storageclasses~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/storage.k8s.io/v1/storageclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1storageclasses~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/storage.k8s.io/v1/storageclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1storageclasses~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/storage.k8s.io/v1/volumeattachments` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1volumeattachments/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/storage.k8s.io/v1/volumeattachments` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1volumeattachments/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/storage.k8s.io/v1/volumeattachments/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1volumeattachments~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/storage.k8s.io/v1/volumeattachments/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1volumeattachments~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/storage.k8s.io/v1/volumeattachments/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1volumeattachments~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/storage.k8s.io/v1/volumeattachments/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1volumeattachments~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/storage.k8s.io/v1/volumeattachments/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1volumeattachments~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/storage.k8s.io/v1/volumeattributesclasses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1volumeattributesclasses/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/storage.k8s.io/v1/volumeattributesclasses` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1volumeattributesclasses/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/storage.k8s.io/v1/volumeattributesclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1volumeattributesclasses~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/storage.k8s.io/v1/volumeattributesclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1volumeattributesclasses~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/storage.k8s.io/v1/volumeattributesclasses/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storage.k8s.io~1v1~1volumeattributesclasses~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/storagemigration.k8s.io/v1/storageversionmigrations` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storagemigration.k8s.io~1v1~1storageversionmigrations/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/storagemigration.k8s.io/v1/storageversionmigrations` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storagemigration.k8s.io~1v1~1storageversionmigrations/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/storagemigration.k8s.io/v1/storageversionmigrations/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storagemigration.k8s.io~1v1~1storageversionmigrations~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/storagemigration.k8s.io/v1/storageversionmigrations/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storagemigration.k8s.io~1v1~1storageversionmigrations~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/storagemigration.k8s.io/v1/storageversionmigrations/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storagemigration.k8s.io~1v1~1storageversionmigrations~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/storagemigration.k8s.io/v1/storageversionmigrations/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storagemigration.k8s.io~1v1~1storageversionmigrations~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/storagemigration.k8s.io/v1/storageversionmigrations/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storagemigration.k8s.io~1v1~1storageversionmigrations~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/storagemigration.k8s.io/v1beta1/storageversionmigrations` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storagemigration.k8s.io~1v1beta1~1storageversionmigrations/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `POST /apis/storagemigration.k8s.io/v1beta1/storageversionmigrations` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storagemigration.k8s.io~1v1beta1~1storageversionmigrations/post/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `DELETE /apis/storagemigration.k8s.io/v1beta1/storageversionmigrations/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storagemigration.k8s.io~1v1beta1~1storageversionmigrations~1{name}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/storagemigration.k8s.io/v1beta1/storageversionmigrations/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storagemigration.k8s.io~1v1beta1~1storageversionmigrations~1{name}/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/storagemigration.k8s.io/v1beta1/storageversionmigrations/{name}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storagemigration.k8s.io~1v1beta1~1storageversionmigrations~1{name}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PATCH /apis/storagemigration.k8s.io/v1beta1/storageversionmigrations/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storagemigration.k8s.io~1v1beta1~1storageversionmigrations~1{name}~1status/patch/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- kubernetes/kubernetes/master/api/openapi-spec/swagger.json: `PUT /apis/storagemigration.k8s.io/v1beta1/storageversionmigrations/{name}/status` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1apis~1storagemigration.k8s.io~1v1beta1~1storageversionmigrations~1{name}~1status/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- box/box-openapi/main/openapi.json: `PUT /files/{file_id}/metadata/enterprise/securityClassification-6VMVochwUWo` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1files~1{file_id}~1metadata~1enterprise~1securityClassification-6VMVochwUWo/put/requestBody`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- box/box-openapi/main/openapi.json: `PUT /files/{file_id}/metadata/{scope}/{template_key}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1files~1{file_id}~1metadata~1{scope}~1{template_key}/put/requestBody`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- box/box-openapi/main/openapi.json: `PUT /files/{file_id}/metadata/global/boxSkillsCards` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1files~1{file_id}~1metadata~1global~1boxSkillsCards/put/requestBody`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- box/box-openapi/main/openapi.json: `PUT /folders/{folder_id}/metadata/enterprise/securityClassification-6VMVochwUWo` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1folders~1{folder_id}~1metadata~1enterprise~1securityClassification-6VMVochwUWo/put/requestBody`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- box/box-openapi/main/openapi.json: `PUT /folders/{folder_id}/metadata/{scope}/{template_key}` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1folders~1{folder_id}~1metadata~1{scope}~1{template_key}/put/requestBody`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- box/box-openapi/main/openapi.json: `PUT /metadata_templates/enterprise/securityClassification-6VMVochwUWo/schema#update` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1metadata_templates~1enterprise~1securityClassification-6VMVochwUWo~1schema#update/put/requestBody`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- box/box-openapi/main/openapi.json: `PUT /metadata_templates/{scope}/{template_key}/schema` [capability_gap]: Unsupported body media type
  Source: `#/paths/~1metadata_templates~1{scope}~1{template_key}~1schema/put/requestBody`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- box/box-openapi/main/openapi.json: `GET /search` [capability_gap]: Unsupported parameter array items
  Source: `#/paths/~1search/get/parameters/12/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- box/box-openapi/main/openapi.json: `POST /oauth2/revoke` [fixture]: Form field needs a declared schema: grant_type
- box/box-openapi/main/openapi.json: `POST /file_requests/{file_request_id}/copy` [fixture]: No valid body fixture: supply a reviewed override
- digitalocean/openapi/main/specification/DigitalOcean-public.v2.yaml: `GET /v2/account/keys/{ssh_key_identifier}` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1v2~1account~1keys~1{ssh_key_identifier}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- digitalocean/openapi/main/specification/DigitalOcean-public.v2.yaml: `PUT /v2/account/keys/{ssh_key_identifier}` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1v2~1account~1keys~1{ssh_key_identifier}/put/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- digitalocean/openapi/main/specification/DigitalOcean-public.v2.yaml: `DELETE /v2/account/keys/{ssh_key_identifier}` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1v2~1account~1keys~1{ssh_key_identifier}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- digitalocean/openapi/main/specification/DigitalOcean-public.v2.yaml: `GET /v2/images/{image_id}` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1v2~1images~1{image_id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- digitalocean/openapi/main/specification/DigitalOcean-public.v2.yaml: `GET /v2/snapshots/{snapshot_id}` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1v2~1snapshots~1{snapshot_id}/get/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- digitalocean/openapi/main/specification/DigitalOcean-public.v2.yaml: `DELETE /v2/snapshots/{snapshot_id}` [capability_gap]: Unsupported parameter composition
  Source: `#/paths/~1v2~1snapshots~1{snapshot_id}/delete/parameters/0/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- digitalocean/openapi/main/specification/DigitalOcean-public.v2.yaml: `GET /v2/certificates` [invoke]: Empty query parameter: name
- digitalocean/openapi/main/specification/DigitalOcean-public.v2.yaml: `POST /v2/databases/{database_cluster_uuid}/logsink` [fixture]: No valid body fixture: supply a reviewed override
- digitalocean/openapi/main/specification/DigitalOcean-public.v2.yaml: `POST /v2/droplets/actions` [fixture]: No valid body fixture: supply a reviewed override
- digitalocean/openapi/main/specification/DigitalOcean-public.v2.yaml: `POST /v2/firewalls` [fixture]: No valid body fixture: supply a reviewed override
- digitalocean/openapi/main/specification/DigitalOcean-public.v2.yaml: `PUT /v2/firewalls/{firewall_id}` [fixture]: No valid body fixture: supply a reviewed override
- digitalocean/openapi/main/specification/DigitalOcean-public.v2.yaml: `POST /v2/firewalls/{firewall_id}/rules` [fixture]: No valid body fixture: supply a reviewed override
- digitalocean/openapi/main/specification/DigitalOcean-public.v2.yaml: `POST /v2/volumes` [fixture]: No valid body fixture: supply a reviewed override
- digitalocean/openapi/main/specification/DigitalOcean-public.v2.yaml: `POST /v2/volumes/actions` [fixture]: No valid body fixture: supply a reviewed override
- digitalocean/openapi/main/specification/DigitalOcean-public.v2.yaml: `POST /v2/volumes/{volume_id}/actions` [fixture]: No valid body fixture: supply a reviewed override
- digitalocean/openapi/main/specification/DigitalOcean-public.v2.yaml: `POST /v2/uptime/checks` [fixture]: No valid body fixture: supply a reviewed override

Details: [operations.csv](operations.csv), [schemas.csv](schemas.csv), [sources.csv](sources.csv).
