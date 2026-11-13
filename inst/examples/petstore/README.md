# Full Petstore example

This example builds a client for all 19 operations of the Swagger Petstore with
specmill's configuration and client-extension mechanisms. It uses the frozen
schema shipped with specmill (`inst/configuration/petstore.json`, retrieved
2026-09-10; see `petstore-origin.json` beside it), so building it downloads
nothing and sends no request.

```r
root <- file.path(tempdir(), 'petstoretrial')
specmill::petstore_example(root)
testthat::test_local(root) # needs callr and httpuv
```

`petstore_example()` initializes the `petstoretrial` package from the frozen
schema, replaces its project YAML with the three service files in this
directory, copies in the client-owned functions and the client test, and
generates wrappers and help. It returns the `generate_client()` result.

## What specmill handles

| Route through specmill | Operations | Meaning |
|---|---:|---|
| Native generation | 11 | Schema parameters and bodies generate directly |
| Explicit request mappings | 2 | An array query value and a header parameter use configured inputs |
| Retained client implementations | 6 | Five JSON bodies and one binary upload stay client-owned |

The current generator reports no unsupported operations for this schema; the
mappings and client-owned functions are kept on purpose to show those
mechanisms.

The client has 19 endpoint functions: 13 generated and six client-owned, plus
the session setters `petstoretrial_dry_run()` and `petstoretrial_run_verbose()`.

## Function groups

| Configuration | Functions |
|---|---|
| apis/pet.yml | pet_create, pet_update, pet_find_by_status, pet_find_by_tags, pet_get, pet_update_fields, pet_delete, pet_upload_image |
| apis/store.yml | store_inventory, store_order_create, store_order_get, store_order_delete |
| apis/user.yml | user_create, user_create_many, user_login, user_logout, user_get, user_update, user_delete |

New clients get tag-based service YAML from `initialize_client()`, with
optional `naming = 'tag_prefix'`. This example configures its own names and
groups instead. Each service reads the same unchanged schema and selects its
path prefix. The package has one R namespace; prefixes keep related functions
together.

The project configuration lists the three service files:

```yaml
config_version: 1
package: petstoretrial
services: [apis/pet.yml, apis/store.yml, apis/user.yml]
```

Within apis/pet.yml, three independent settings control the public interface:

```yaml
names:
  GET /pet/{petId}: pet_get
defaults:
  file: R/pet.R
  docs:
    tags: {family: pet endpoints}
operations:
  GET /pet/{petId}:
    parameters:
      path petId: {name: pet_id}
```

The names map changes operationId getPetById to the R function pet_get. The
parameter override changes the R argument to pet_id while keeping petId on the
wire. defaults.file groups generated source in R/pet.R; docs.tags.family groups
related help topics. Operation keys always use the original HTTP method and
path, so renaming does not change the endpoint.

## Change and regenerate

To try a different generated name, edit the existing names entry (for example
to pet_fetch; do not add a second key), then plan and apply:

```r
specmill::generate_client(root, config = 'specmill.yml', mode = 'plan',
  artifacts = c('wrappers', 'documentation'))
specmill::generate_client(root, config = 'specmill.yml', mode = 'apply',
  artifacts = c('wrappers', 'documentation'))
```

Generated definitions, exports, and help follow the configuration. Update the
client test's expectations (`tests/testthat/test-http.R`) when you rename the
public API on purpose. For `implementation: existing` entries, rename the
client-owned function and its roxygen block too: specmill checks its formals
and keeps its code. Client-owned functions document themselves with roxygen2;
specmill writes the help for generated functions. To refresh a client-owned
page, run `roxygen2::roxygenise()` on a copy of the package and copy back only
that page, as `petstore_example()` does; running it on the client itself would
rewrite the generated pages.

## Tests

`tests/testthat/test-http.R` specifies the expected wire request for every
endpoint independently and runs each against a temporary local HTTP server:
methods, path escaping, repeated array query values, headers, JSON bodies,
binary bytes, and an HTTP error. No request reaches the public demo. The
client's base URL is set for the test with
`options(petstoretrial.request = list(base_url = ...))`.

The example sets `base_url = 'https://petstore3.swagger.io/api/v3'` when it
initializes the client, because the schema's server is relative (`/api/v3`).
Calling the write functions against that URL changes the public demo's data.

## Boundaries

All endpoints are exposed, but full OpenAPI validation, alternate XML/form
representations, OAuth flows, and response-header return values are not
supplied. The six client-owned functions choose JSON or raw upload explicitly.
Secrets are not stored in configuration or fixtures; the header test uses a
dummy value.

Authoritative inputs: [Petstore OpenAPI schema](https://petstore3.swagger.io/api/v3/openapi.json),
[httr2 query encoding](https://httr2.r-lib.org/reference/req_url.html), and
[httr2 body encoding](https://httr2.r-lib.org/reference/req_body.html).
