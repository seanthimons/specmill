# Adopt an existing client

Adoption connects an existing R package to specmill without recreating
the package or replacing its HTTP implementation. Work on a dedicated
branch, record a clean baseline, and begin with one representative
operation.

If your project already has `specmill.yml`, use [the upgrade
workflow](#update-an-already-configured-client) below or [the
maintenance
loop](https://seanthimons.github.io/specmill/articles/maintenance.md).
ComptoxR maintainers can use the commands at the end of this guide.

## 1. Record the existing contract

Before adding configuration, run the package’s targeted tests and record
its wrapper names, argument order/defaults, exports, help text,
examples, lifecycle policy, hooks, and expected helper calls. Include
manual wrappers absent from schemas. Keep authentication, response
classes, pagination, and batching behavior: a schema alone cannot
describe all of those decisions.

Do not run
[`initialize_client()`](https://seanthimons.github.io/specmill/reference/initialize_client.md)
on an established client merely to add YAML. It adds a new httr2 helper
and refuses conflicts with existing scaffold files.

## 2. Add project and service files

For a schema-driven starting point, preview configuration without
writing files:

``` r

root <- normalizePath('/path/to/existingclient', winslash = '/', mustWork = TRUE)
proposal <- specmill::configure_client(
  root, file.path(root, 'schema/catalogue.yaml'), name_case = 'snake_case'
)
proposal$changes
proposal$diagnostics
proposal$files[['apis/default.yml']] # For a schema without tags.
```

Tagged schemas propose one service per first tag. Review the proposed
names against the package’s public interface, narrow `selection.include`
to the first operation, and configure your actual helper and mappings
before generating. `configure_client(..., mode = 'apply')` creates
absent files only and refuses conflicting existing files. It creates no
helper or package metadata. Copy reviewed changes into existing YAML
manually.

You can also write a minimal policy directly. Create `specmill.yml` in
the client root:

``` yaml
config_version: 1
package: existingclient
services: [apis/catalogue.yml]
```

Save a reviewed local schema as `schema/catalogue.json`, then create
`apis/catalogue.yml`:

``` yaml
id: catalogue
schemas:
  files: [schema/catalogue.json]
selection:
  methods: [GET]
  exclude: ['^/items$']
helper: request_item
documentation: true
operations:
  GET /items/{item_id}:
    name: fetch_item
    inputs:
      identifier: {type: character, required: true, description: Catalogue item ID.}
      language: {type: character, default: en, description: Response language.}
    request:
      arguments:
        endpoint: {value: items}
        id: {from: [params, identifier]}
        language: {from: [params, language]}
    docs:
      title: Fetch a catalogue item
      return: The item returned by the existing request helper.
      examples: [{identifier: item-1}]
```

This preserves `fetch_item(identifier, language = 'en')` while mapping
it to
`request_item(endpoint = 'items', id = identifier, language = language)`.
The helper must be defined in the client’s `R/` source. specmill parses
its arguments before applying generated code.

`inputs` declares the complete public interface and requires an explicit
request mapping. `parameters` is the alternative when only a few
schema-derived arguments need changing. See
[Configuration](https://seanthimons.github.io/specmill/articles/configuration.md).

Exclude config, schemas, and `.specmill` from the built client package
using `.Rbuildignore`, but keep them in Git. Do not add specmill to
runtime dependencies.

## 3. Keep executable customizations in R

For development callbacks, use an explicit environment:

``` r

root <- normalizePath('/path/to/existingclient', winslash = '/', mustWork = TRUE)
callbacks <- new.env(parent = baseenv())
sys.source(file.path(root, 'dev/callbacks.R'), envir = callbacks)
plan <- specmill::generate_client(
  root, config = 'specmill.yml', callbacks = callbacks, mode = 'plan'
)
```

Use `callback_files: [dev/callbacks.R]` in the project file to
fingerprint that source. It does not source the file. Only source code
you maintain and trust. Runtime hooks remain client code; `hook_config`
can point at existing declarations instead of duplicating them.

## 4. Review and adopt existing generated files

New paths can be created immediately. Existing paths need recorded
ownership or an explicit adoption hash. A generated header alone is
insufficient.

This runnable example uses a temporary copy of the bundled client, adds
an old generated wrapper, and adopts it after inspection. It never
touches your package. The YAML above illustrates a custom mapping; this
ownership example uses the bundled helper’s default contract.

``` r

root <- tempfile('existing-client-')
dir.create(root)
catalogue <- system.file('catalogue', package = 'specmill', mustWork = TRUE)
stopifnot(all(file.copy(list.files(catalogue, full.names = TRUE), root, recursive = TRUE)))
writeLines(c('config_version: 1', 'services: [catalogue.yml]'), file.path(root, 'specmill.yml'))
writeLines(c(
  'id: catalogue', 'schemas: {files: [schema.json]}',
  'helper: catalogue_request'
), file.path(root, 'catalogue.yml'))
legacy <- file.path(root, 'R/get_item.R')
writeLines(c(
  '# Generated by wrapmaint; do not edit by hand.',
  'get_item <- function(item_id, language = NULL) {',
  '  catalogue_request(method = "GET", path = "/items/{item_id}",',
  '    path_params = list(item_id = item_id), query = list(language = language), body = NULL)',
  '}'
), legacy)
plan <- specmill::generate_client(root, config = 'specmill.yml', mode = 'plan')
Filter(function(x) x$action == 'protected', plan$files)
#> [[1]]
#> [[1]]$file
#> [1] "R/get_item.R"
#> 
#> [[1]]$path
#> [1] "/tmp/Rtmpnq4Sfl/existing-client-20a82e76c1f6/R/get_item.R"
#> 
#> [[1]]$action
#> [1] "protected"
```

Review the file against the candidate behavior, including required-input
checks and documentation. Hash only files you have reviewed, using UTF-8
text, LF line endings, and no terminal newline:

``` r

text <- paste(readLines(legacy, warn = FALSE, encoding = 'UTF-8'), collapse = '\n')
hash <- digest::digest(enc2utf8(text), algo = 'sha256', serialize = FALSE)
adopt <- list('R/get_item.R' = hash)
reviewed <- specmill::generate_client(
  root, config = 'specmill.yml', mode = 'plan', adopt = adopt
)
applied <- specmill::generate_client(
  root, config = 'specmill.yml', mode = 'apply', adopt = adopt
)
checked <- specmill::generate_client(root, config = 'specmill.yml', mode = 'check')
stopifnot(!any(vapply(checked$files, function(x) x$action == 'protected', logical(1))))
```

The manifest now records ownership. Adoption hashes are a one-time
review input; do not keep passing old hashes on later runs. A changed
hash blocks adoption. Lifecycle and mixed-file protection still apply.
Review existing documentation or shared `NAMESPACE` conflicts
separately.

## 5. Retain manual implementations and grouped files

For a schema operation that must keep its handwritten wrapper, add
`implementation: existing`, along with its explicit `name`, complete
`inputs`, and `request` mapping. specmill checks the actual formals and
retains the source. It can generate a fixed contract test, but does not
rewrite that implementation’s documentation.

To preserve grouped generated output, set `file: R/catalogue.R`. Every
top-level definition in that file must be accounted for. Undeclared
functions, other top-level code, or retained implementations block
replacement of the group. Keep those files manual or separate them
deliberately before adoption.

## 6. Verify and expand

Compare formals, exports, documentation, examples, lifecycle, and
independently expected helper calls with the baseline. Run generated
contract tests and existing bespoke tests. Check that a second apply is
a no-op. Only then add more operations/services.

Commit policy, schemas, callbacks, fixtures, generated output, and
manifest together. Keep the prior toolkit pin with matching output
available for rollback. See
[Testing](https://seanthimons.github.io/specmill/articles/testing.md)
and
[Troubleshooting](https://seanthimons.github.io/specmill/articles/troubleshooting.md).

## Update an already configured client

Keep the current toolkit pin and a clean baseline before upgrading.
Install the candidate toolkit in a separate R library or project
environment when comparing versions, then restart R. The current guides
describe `main`; use a reviewed commit SHA or your project’s installer
to make subsequent runs reproducible.

1.  Run `generate_client(..., mode = 'plan')` with the existing policy
    and callbacks. Review diagnostics, file actions, public signatures,
    and request mappings. Do not rerun initialization or replace
    reviewed YAML with a fresh proposal.
2.  Inspect client-owned helpers with the candidate toolkit:

``` r

inspection <- specmill::inspect_client(root, config = 'specmill.yml')
inspection$helpers
inspection$protected_sources
helper <- inspection$helpers[['api_request']] # Use your configured helper name.
if (identical(helper$baseline, 'known')) {
  helper$customized
  helper$upstream_changed
  helper$missing_explicit_arguments
  cat(helper$comparison$proposed)
}
```

For projects with development callbacks, pass the same `callbacks`
environment to inspection and generation. New scaffolds keep helper
baselines under `.specmill/helpers/`; commit that directory with the
manifest. Older helpers without provenance report an unknown baseline.
Inspection writes nothing and cannot establish whether a helper behaves
correctly.

3.  Manually merge the transport changes needed by your selected
    operations. Preserve authentication, hooks, response classes, and
    service-specific behavior. New arguments such as `server`,
    `request_controls`, `parameter_serialization`, or `form_schema` need
    their implementation too; adding `...` is insufficient. See
    [transport
    configuration](https://seanthimons.github.io/specmill/articles/configuration.html#parameter-serialization).
4.  To add session controls, review the installed templates with
    `system.file('templates/options.R', package = 'specmill')` and
    `system.file('templates/request.R', package = 'specmill')`. Copy the
    options template into client-owned `R/api_options.R`, replace
    `CLIENT_PREFIX` with the exact package name and `OPTION_PREFIX` with
    a quoted lowercase package name with punctuation replaced by `_`,
    and merge the helper’s option handling. Generate documentation to
    export the setters. Existing clients do not receive either change
    through regeneration alone.
5.  Replan, apply reviewed changes, check, and run contract and
    transport tests. Exercise dry-run and verbose controls if adopted,
    including turning them off. Compare public names, arguments,
    exports, and results with the baseline. Commit the toolkit pin,
    policy, helper edits, output, and manifest together.

You can keep an existing helper when no newly selected feature requires
changes. Generated wrappers need no specmill runtime dependency. Adding
a companion that calls
[`specmill::paginated()`](https://seanthimons.github.io/specmill/reference/paginated.md),
[`paginated_links()`](https://seanthimons.github.io/specmill/reference/paginated_links.md),
or
[`batched()`](https://seanthimons.github.io/specmill/reference/batched.md)
does require specmill in the client’s Imports.

## ComptoxR: use the maintained integration

These commands use the specmill integration in ComptoxR. Use the
`CONTRIBUTING.md` in your checkout for its current branch/release
policy.

From the ComptoxR root, install its checksum-pinned toolkit:

``` r

source('dev/install_toolkit.R')
install_toolkit()
```

The project declares Air **0.9.0** in `specmill.yml`; install that exact
formatter before generation. The project selects CTX, EPI, and separate
Chemi service files. `dev/specmill_callbacks.R` supplies development
callbacks; `inst/hook_config.yml` remains the runtime hook policy. Keep
these rather than substituting the simplified examples above.

Routine regeneration does not apply a naming convention again.
ComptoxR’s reviewed `names` maps keep public functions such as
`ct_chemical_detail_search` unchanged. When previewing configuration for
newly catalogued endpoints, pass `name_case = 'snake_case'` to
[`configure_client()`](https://seanthimons.github.io/specmill/reference/configure_client.md).
Multi-API proposals apply the API prefix first, so an API named `ct`
proposes names beginning with `ct_`. Review and copy new mappings into
the existing service YAML before regeneration.

Preview and check from a terminal:

``` sh
Rscript dev/generate_stubs.R --plan
Rscript dev/generate_tests.R --dry-run
Rscript dev/generate_stubs.R --check --rebuild=ct --rebuild=chemi --rebuild=epi
Rscript dev/generate_tests.R --check
Rscript dev/check_hook_config.R
Rscript dev/check_public_api.R
```

After reviewing changes, regenerate:

``` sh
Rscript dev/generate_stubs.R --rebuild=ct --rebuild=chemi --rebuild=epi
Rscript dev/generate_tests.R --generate
```

Repeat the checks and run the checkout’s targeted offline tests. The
thin commands load callbacks for you. For interactive R, use their
sourceable functions with explicit arguments:

``` r

source('dev/generate_stubs.R')
generate_stubs_main(args = '--plan')
source('dev/generate_tests.R')
generate_tests_main(args = '--dry-run')
```

The compatibility `--rebuild` flags are accepted, but YAML selection
defines the operation set; the flags do not override it. Preserve
ComptoxR’s runtime, production selection, custom roxygen tags, and
public-boundary policy.
