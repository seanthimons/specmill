library(tibble)

specs <- tribble(
  ~tier,          ~stresses,                                  ~url,
  # --- canonical: clean, small, should always pass ---
  "canonical",    "3.0 baseline",                             "https://raw.githubusercontent.com/OAI/learn.openapis.org/main/examples/v3.0/petstore.yaml",
  "canonical",    "3.0 expanded models",                      "https://raw.githubusercontent.com/OAI/learn.openapis.org/main/examples/v3.0/petstore-expanded.yaml",
  "canonical",    "response examples",                        "https://raw.githubusercontent.com/OAI/learn.openapis.org/main/examples/v3.0/api-with-examples.yaml",
  "canonical",    "callbacks",                                "https://raw.githubusercontent.com/OAI/learn.openapis.org/main/examples/v3.0/callback-example.yaml",
  "canonical",    "links",                                    "https://raw.githubusercontent.com/OAI/learn.openapis.org/main/examples/v3.0/link-example.yaml",
  "canonical",    "real-world 3.0 (USPTO)",                   "https://raw.githubusercontent.com/OAI/learn.openapis.org/main/examples/v3.0/uspto.yaml",
  "canonical",    "3.1 webhooks",                             "https://raw.githubusercontent.com/OAI/learn.openapis.org/main/examples/v3.1/webhook-example.yaml",
  "canonical",    "3.1 non-oauth scopes",                     "https://raw.githubusercontent.com/OAI/learn.openapis.org/main/examples/v3.1/non-oauth-scopes.yaml",
  "canonical",    "3.1 clean modeling",                       "https://raw.githubusercontent.com/OAI/learn.openapis.org/main/examples/v3.1/tictactoe.yaml",
  "canonical",    "3.2 (bleeding edge)",                      "https://raw.githubusercontent.com/OAI/learn.openapis.org/main/examples/v3.2/3.2-tags-example.yaml",
  "canonical",    "2.0 / Swagger",                            "https://raw.githubusercontent.com/OAI/learn.openapis.org/main/examples/v2.0/yaml/petstore.yaml",
  "canonical",    "2.0 real-world (Uber)",                    "https://raw.githubusercontent.com/OAI/learn.openapis.org/main/examples/v2.0/yaml/uber.yaml",
  "refs",         "multi-file external $ref",                 "https://raw.githubusercontent.com/OAI/learn.openapis.org/main/examples/v2.0/yaml/petstore-separate/spec/swagger.yaml",

  # --- polymorphism: your active pain point ---
  "polymorphism", "bare oneOf",                               "https://raw.githubusercontent.com/OpenAPITools/openapi-generator/master/modules/openapi-generator/src/test/resources/3_0/oneOf.yaml",
  "polymorphism", "bare anyOf",                               "https://raw.githubusercontent.com/OpenAPITools/openapi-generator/master/modules/openapi-generator/src/test/resources/3_0/anyOf.yaml",
  "polymorphism", "allOf inheritance",                        "https://raw.githubusercontent.com/OpenAPITools/openapi-generator/master/modules/openapi-generator/src/test/resources/3_0/allOf.yaml",
  "polymorphism", "allOf composition",                        "https://raw.githubusercontent.com/OpenAPITools/openapi-generator/master/modules/openapi-generator/src/test/resources/3_0/allOf_composition.yaml",
  "polymorphism", "composed schemas mix",                     "https://raw.githubusercontent.com/OpenAPITools/openapi-generator/master/modules/openapi-generator/src/test/resources/3_0/composed-schemas.yaml",
  "polymorphism", "oneOf + discriminator + mapping",          "https://raw.githubusercontent.com/OpenAPITools/openapi-generator/master/modules/openapi-generator/src/test/resources/3_0/oneOfDiscriminator.yaml",
  "polymorphism", "oneOf inside array/map imports",           "https://raw.githubusercontent.com/OpenAPITools/openapi-generator/master/modules/openapi-generator/src/test/resources/3_0/oneOfArrayMapImport.yaml",
  "polymorphism", "oneOf regression case",                    "https://raw.githubusercontent.com/OpenAPITools/openapi-generator/master/modules/openapi-generator/src/test/resources/3_0/issue_9848.yaml",
  "polymorphism", "3.1 oneOf",                                "https://raw.githubusercontent.com/OpenAPITools/openapi-generator/master/modules/openapi-generator/src/test/resources/3_1/oneOf.yaml",
  "kitchen-sink", "the everything fixture",                   "https://raw.githubusercontent.com/OpenAPITools/openapi-generator/master/modules/openapi-generator/src/test/resources/3_0/petstore-with-fake-endpoints-models-for-testing.yaml",

  # --- schema-layer adversarial (NOT OpenAPI docs — see note) ---
  "json-schema",  "2020-12 oneOf edge cases",                 "https://raw.githubusercontent.com/json-schema-org/JSON-Schema-Test-Suite/main/tests/draft2020-12/oneOf.json",
  "json-schema",  "2020-12 anyOf edge cases",                 "https://raw.githubusercontent.com/json-schema-org/JSON-Schema-Test-Suite/main/tests/draft2020-12/anyOf.json",
  "json-schema",  "2020-12 $ref resolution",                  "https://raw.githubusercontent.com/json-schema-org/JSON-Schema-Test-Suite/main/tests/draft2020-12/ref.json",
  "json-schema",  "unevaluatedProperties",                    "https://raw.githubusercontent.com/json-schema-org/JSON-Schema-Test-Suite/main/tests/draft2020-12/unevaluatedProperties.json",

  # --- screamers: scale + real-world pathology ---
  "screamer",     "Stripe: deep oneOf, ~6MB",                 "https://raw.githubusercontent.com/stripe/openapi/master/openapi/spec3.yaml",
  "screamer",     "GitHub 3.0: ~10MB, webhooks",              "https://raw.githubusercontent.com/github/rest-api-description/main/descriptions/api.github.com/api.github.com.yaml",
  "screamer",     "GitHub 3.1: ~13MB",                        "https://raw.githubusercontent.com/github/rest-api-description/main/descriptions-next/api.github.com/api.github.com.json",
  "screamer",     "Kubernetes: 2.0, x-k8s-* extensions",      "https://raw.githubusercontent.com/kubernetes/kubernetes/master/api/openapi-spec/swagger.json",
  "screamer",     "DigitalOcean: bundled, clean-ish",         "https://raw.githubusercontent.com/digitalocean/openapi/main/specification/DigitalOcean-public.v2.yaml",
  "screamer",     "Box: multipart, oauth2",                   "https://raw.githubusercontent.com/box/box-openapi/main/openapi.json"
)