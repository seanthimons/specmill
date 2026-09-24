# Configure and maintain runtime hooks

Runtime hooks customize generated wrappers before the request helper
runs and after it returns. Use them to normalize identifiers, construct
service-specific payloads, skip requests, or shape results. Your client
owns the executor and the hook functions. Installing the client does not
require specmill.

This guide uses the development version of specmill with
[`configure_hooks()`](https://seanthimons.github.io/specmill/reference/configure_hooks.md).
Follow [installation and package
setup](https://seanthimons.github.io/specmill/articles/specmill.md)
first. An older installed version may support hook configuration without
providing this setup command. The examples below run offline when this
article is built.

## Create the optional executor

For a new client, initialize the package first. For an existing package,
use its root and proceed directly to
[`configure_hooks()`](https://seanthimons.github.io/specmill/reference/configure_hooks.md).

``` r

schema <- system.file('catalogue/schema.json', package = 'specmill', mustWork = TRUE)
root <- tempfile('hook-client-')
specmill::initialize_client(
  root, schema, package = 'hookclient', title = 'Hook Example Client',
  author = list(given = 'Example', family = 'Maintainer', email = 'you@example.org'),
  license = 'MIT + file LICENSE', base_url = 'https://example.invalid'
)
#> [[1]]
#> [[1]]$file
#> [1] "schema/openapi.json"
#> 
#> [[1]]$path
#> [1] "/tmp/Rtmppm7nKJ/hook-client-227a1fd7ec0e/schema/openapi.json"
#> 
#> [[1]]$action
#> [1] "write"
#> 
#> 
#> [[2]]
#> [[2]]$file
#> [1] "specmill.yml"
#> 
#> [[2]]$path
#> [1] "/tmp/Rtmppm7nKJ/hook-client-227a1fd7ec0e/specmill.yml"
#> 
#> [[2]]$action
#> [1] "write"
#> 
#> 
#> [[3]]
#> [[3]]$file
#> [1] "apis/default.yml"
#> 
#> [[3]]$path
#> [1] "/tmp/Rtmppm7nKJ/hook-client-227a1fd7ec0e/apis/default.yml"
#> 
#> [[3]]$action
#> [1] "write"
#> 
#> 
#> [[4]]
#> [[4]]$file
#> [1] "R/api_request.R"
#> 
#> [[4]]$path
#> [1] "/tmp/Rtmppm7nKJ/hook-client-227a1fd7ec0e/R/api_request.R"
#> 
#> [[4]]$action
#> [1] "write"
#> 
#> 
#> [[5]]
#> [[5]]$file
#> [1] "R/api_options.R"
#> 
#> [[5]]$path
#> [1] "/tmp/Rtmppm7nKJ/hook-client-227a1fd7ec0e/R/api_options.R"
#> 
#> [[5]]$action
#> [1] "write"
#> 
#> 
#> [[6]]
#> [[6]]$file
#> [1] ".specmill/helpers/api_request.json"
#> 
#> [[6]]$path
#> [1] "/tmp/Rtmppm7nKJ/hook-client-227a1fd7ec0e/.specmill/helpers/api_request.json"
#> 
#> [[6]]$action
#> [1] "write"
#> 
#> 
#> [[7]]
#> [[7]]$file
#> [1] ".Rbuildignore"
#> 
#> [[7]]$path
#> [1] "/tmp/Rtmppm7nKJ/hook-client-227a1fd7ec0e/.Rbuildignore"
#> 
#> [[7]]$action
#> [1] "write"
#> 
#> 
#> [[8]]
#> [[8]]$file
#> [1] "DESCRIPTION"
#> 
#> [[8]]$path
#> [1] "/tmp/Rtmppm7nKJ/hook-client-227a1fd7ec0e/DESCRIPTION"
#> 
#> [[8]]$action
#> [1] "write"
#> 
#> 
#> [[9]]
#> [[9]]$file
#> [1] "NAMESPACE"
#> 
#> [[9]]$path
#> [1] "/tmp/Rtmppm7nKJ/hook-client-227a1fd7ec0e/NAMESPACE"
#> 
#> [[9]]$action
#> [1] "write"
#> 
#> 
#> [[10]]
#> [[10]]$file
#> [1] "LICENSE"
#> 
#> [[10]]$path
#> [1] "/tmp/Rtmppm7nKJ/hook-client-227a1fd7ec0e/LICENSE"
#> 
#> [[10]]$action
#> [1] "write"
#> 
#> 
#> [[11]]
#> [[11]]$file
#> [1] ".specmill/manifest.json"
#> 
#> [[11]]$path
#> [1] "/tmp/Rtmppm7nKJ/hook-client-227a1fd7ec0e/.specmill/manifest.json"
#> 
#> [[11]]$action
#> [1] "write"
#> 
#> 
#> attr(,"configuration")
#> attr(,"configuration")$files
#> attr(,"configuration")$files$`schema/openapi.json`
#> [1] "{\n  \"openapi\": \"3.0.3\",\n  \"info\": {\"title\": \"Catalogue\", \"version\": \"1\"},\n  \"paths\": {\n    \"/items/{item_id}\": {\"get\": {\"operationId\": \"get_item\", \"parameters\": [\n      {\"name\": \"item_id\", \"in\": \"path\", \"required\": true, \"schema\": {\"type\": \"string\"}},\n      {\"name\": \"language\", \"in\": \"query\", \"schema\": {\"type\": \"string\", \"enum\": [\"en\", \"fr\"]}}\n    ], \"responses\": {\"200\": {\"description\": \"Item\"}}}},\n    \"/items\": {\n      \"get\": {\"operationId\": \"list_items\", \"parameters\": [\n        {\"name\": \"page\", \"in\": \"query\", \"schema\": {\"type\": \"integer\", \"minimum\": 1}}\n      ], \"responses\": {\"200\": {\"description\": \"Items\"}}},\n      \"post\": {\"operationId\": \"create_item\", \"requestBody\": {\"required\": true, \"content\": {\n        \"application/json\": {\"schema\": {\"$ref\": \"#/components/schemas/Item\"}}\n      }}, \"responses\": {\"201\": {\"description\": \"Created\"}}}\n    },\n    \"/refresh\": {\"post\": {\"operationId\": \"refresh\", \"responses\": {\"204\": {\"description\": \"Refreshed\"}}}}\n  },\n  \"components\": {\"schemas\": {\"Item\": {\"type\": \"object\", \"required\": [\"title\"], \"properties\": {\n    \"title\": {\"type\": \"string\"}, \"count\": {\"type\": \"integer\"}\n  }}}}\n}"
#> 
#> attr(,"configuration")$files$specmill.yml
#> [1] "config_version: 1\n# Package identity; keep consistent with DESCRIPTION.\npackage: hookclient\n# Service configuration files, relative to the package root.\nservices:\n- apis/default.yml\n# Package-wide limits: services cannot re-enable these excluded methods or paths.\nselection:\n  methods:\n  - GET\n  - POST\n  - PUT\n  - PATCH\n  - DELETE\n  - HEAD\n  - OPTIONS\n  - TRACE\n  exclude: []\n# Default runtime helper; services may override it.\nhelper: api_request\n# Generate help and exports unless a service overrides this setting.\ndocumentation: yes\n# Shared settings; service defaults and individual overrides take precedence.\n# Request controls: seconds per attempt, retries after the first attempt, and explicit write replay permission.\n# Runtime package.request options override these generated defaults.\n# Keep function names and output files in service YAML.\ndefaults:\n  implementation: generated\n  request_controls:\n    timeout: 30\n    max_retries: 0\n    retry_writes: no\n  batch:\n    max_items: ~\n    max_bytes: ~\n# authentication: {} # Opt in to generated auth when the schema declares security.\n# Optional formatting: uncomment and use your exact installed air version.\n# formatter: {name: air, version: \"0.9.0\"}\n# Callback source files to fingerprint; pass their functions via callbacks, too.\ncallback_files: []"
#> 
#> attr(,"configuration")$files$`apis/default.yml`
#> [1] "id: hookclient\n# Local schema files; patterns are file globs, exclude matches basenames by regex.\n# All paths resolve from the package root.\nschemas:\n  files:\n  - schema/openapi.json\n  patterns: []\n  exclude: []\n# An operation must pass methods AND include AND not match exclude (path regexes).\n# Keep only GET and POST below to omit PUT/PATCH/DELETE wrappers.\n# Leave their include/name entries in place; regeneration removes unchanged owned output.\n# An empty include selects nothing; remove include to allow every matching operation.\nselection:\n  methods:\n  - GET\n  - POST\n  - PUT\n  - PATCH\n  - DELETE\n  - HEAD\n  - OPTIONS\n  - TRACE\n  exclude: []\n  include:\n  - GET /items\n  - POST /items\n  - GET /items/{item_id}\n  - POST /refresh\n# Edit the public R function names here; keys stay METHOD /original/path.\nnames:\n  GET /items: list_items\n  POST /items: create_item\n  GET /items/{item_id}: get_item\n  POST /refresh: refresh\n# Shared operation settings. Per-operation settings below override these.\n# file groups wrappers in one R file; omit it for one file per function.\n# Example: add file: R/endpoints.R under defaults.\n# docs can set title, description, return, parameters, examples, tags and lifecycle.\ndefaults: {}\n# Optional overrides keyed by METHOD /original/path. Replace {} with entries.\n# Each entry can set file, helper, parameters, parameter_order and docs.\n# parameters keys use the original location and name, e.g. \"query limit\".\n# Example parameter setting: {name: max_results, default: 10, description: Maximum results.}\n# Advanced facades use inputs, extra_parameters and request.arguments mappings.\noperations: {}\n# Inherited from specmill.yml; uncomment to override for this service:\n# helper: api_request\n# documentation: true\n# Optional hooks: define client functions before enabling these settings.\n# hooks: {} # Public wrapper name -> pre_request/post_response hook-name sequences.\n# hook_callback: run_hook\n# hook_config: inst/hooks.yml # Alternative to inline hooks, not both.\n# prepare: prepare_operation # Development callback; pass an explicit callbacks environment.\n# policy_version: \"1\" # Your review label, recorded in generation metadata.\n# Optional fixed request expectations for generated tests:\n# contracts: {} # Public wrapper name -> fixed request expectations.\n# contracts_file: tests/testthat/contracts.rds\n# response_fixture: {} # Mock response used by inline single-call contracts.\n# Full configuration examples: https://seanthimons.github.io/specmill/articles/configuration.html"
#> 
#> 
#> attr(,"configuration")$operations
#> attr(,"configuration")$operations[[1]]
#> attr(,"configuration")$operations[[1]]$key
#> [1] "GET /items"
#> 
#> attr(,"configuration")$operations[[1]]$tag
#> [1] "default"
#> 
#> attr(,"configuration")$operations[[1]]$group
#> [1] "default"
#> 
#> attr(,"configuration")$operations[[1]]$name
#> [1] "list_items"
#> 
#> 
#> attr(,"configuration")$operations[[2]]
#> attr(,"configuration")$operations[[2]]$key
#> [1] "POST /items"
#> 
#> attr(,"configuration")$operations[[2]]$tag
#> [1] "default"
#> 
#> attr(,"configuration")$operations[[2]]$group
#> [1] "default"
#> 
#> attr(,"configuration")$operations[[2]]$name
#> [1] "create_item"
#> 
#> 
#> attr(,"configuration")$operations[[3]]
#> attr(,"configuration")$operations[[3]]$key
#> [1] "GET /items/{item_id}"
#> 
#> attr(,"configuration")$operations[[3]]$tag
#> [1] "default"
#> 
#> attr(,"configuration")$operations[[3]]$group
#> [1] "default"
#> 
#> attr(,"configuration")$operations[[3]]$name
#> [1] "get_item"
#> 
#> 
#> attr(,"configuration")$operations[[4]]
#> attr(,"configuration")$operations[[4]]$key
#> [1] "POST /refresh"
#> 
#> attr(,"configuration")$operations[[4]]$tag
#> [1] "default"
#> 
#> attr(,"configuration")$operations[[4]]$group
#> [1] "default"
#> 
#> attr(,"configuration")$operations[[4]]$name
#> [1] "refresh"
#> 
#> 
#> 
#> attr(,"configuration")$diagnostics
#> attr(,"configuration")$diagnostics[[1]]
#> attr(,"configuration")$diagnostics[[1]]$key
#> [1] "GET /items"
#> 
#> attr(,"configuration")$diagnostics[[1]]$code
#> [1] "missing_tag"
#> 
#> attr(,"configuration")$diagnostics[[1]]$message
#> [1] "Assigned to default"
#> 
#> 
#> attr(,"configuration")$diagnostics[[2]]
#> attr(,"configuration")$diagnostics[[2]]$key
#> [1] "POST /items"
#> 
#> attr(,"configuration")$diagnostics[[2]]$code
#> [1] "missing_tag"
#> 
#> attr(,"configuration")$diagnostics[[2]]$message
#> [1] "Assigned to default"
#> 
#> 
#> attr(,"configuration")$diagnostics[[3]]
#> attr(,"configuration")$diagnostics[[3]]$key
#> [1] "GET /items/{item_id}"
#> 
#> attr(,"configuration")$diagnostics[[3]]$code
#> [1] "missing_tag"
#> 
#> attr(,"configuration")$diagnostics[[3]]$message
#> [1] "Assigned to default"
#> 
#> 
#> attr(,"configuration")$diagnostics[[4]]
#> attr(,"configuration")$diagnostics[[4]]$key
#> [1] "POST /refresh"
#> 
#> attr(,"configuration")$diagnostics[[4]]$code
#> [1] "missing_tag"
#> 
#> attr(,"configuration")$diagnostics[[4]]$message
#> [1] "Assigned to default"
proposal <- specmill::configure_hooks(root)
proposal$changes
#> [[1]]
#> [[1]]$file
#> [1] "R/hook_registry.R"
#> 
#> [[1]]$action
#> [1] "create"
#> 
#> [[1]]$before
#> NULL
#> 
#> [[1]]$after
#> [1] "# Client-owned hook executor. Edit this file; regeneration preserves it.\nread_hook_config <- function() {\n  # ponytail: read once per stage; cache with an explicit reload if profiling warrants it.\n  path <- system.file('hooks.yml', package = \"hookclient\", mustWork = TRUE)\n  config <- yaml::read_yaml(path, eval.expr = FALSE)\n  if (\n    !is.list(config) ||\n      (length(config) &&\n        (is.null(names(config)) || anyDuplicated(names(config))))\n  ) {\n    stop('hooks.yml must map public function names to hook stages')\n  }\n  config\n}\n\nrun_hook <- function(fn_name, hook_type, data) {\n  if (\n    length(hook_type) != 1L ||\n      is.na(hook_type) ||\n      !hook_type %in% c('pre_request', 'post_response')\n  ) {\n    stop('Unsupported hook stage')\n  }\n  entry <- read_hook_config()[[fn_name]]\n  if (\n    !is.null(entry) &&\n      (!is.list(entry) ||\n        is.null(names(entry)) ||\n        anyDuplicated(names(entry)) ||\n        any(!names(entry) %in% c('pre_request', 'post_response')))\n  ) {\n    stop('Invalid hook stages for ', fn_name)\n  }\n  chain <- entry[[hook_type]]\n  if (is.null(chain) || !length(chain)) {\n    return(if (hook_type == 'post_response') data$result else data)\n  }\n  if (\n    !(is.character(chain) || is.list(chain)) ||\n      !is.null(names(chain)) ||\n      !all(vapply(\n        chain,\n        function(x) {\n          is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)\n        },\n        logical(1)\n      ))\n  ) {\n    stop('Hook chain must be a sequence of function names for ', fn_name)\n  }\n  for (hook_name in chain) {\n    data <- tryCatch(\n      {\n        hook <- get(hook_name, envir = environment(run_hook), inherits = FALSE)\n        if (!is.function(hook)) {\n          stop('Configured hook is not a function')\n        }\n        hook(data)\n      },\n      error = function(parent) {\n        stop(errorCondition(\n          paste(\n            fn_name,\n            hook_type,\n            hook_name,\n            conditionMessage(parent),\n            sep = ': '\n          ),\n          class = 'client_hook_error',\n          parent = parent,\n          function_name = fn_name,\n          hook_name = hook_name,\n          stage = hook_type\n        ))\n      }\n    )\n  }\n  data\n}"
#> 
#> 
#> [[2]]
#> [[2]]$file
#> [1] "inst/hooks.yml"
#> 
#> [[2]]$action
#> [1] "create"
#> 
#> [[2]]$before
#> NULL
#> 
#> [[2]]$after
#> [1] "# Public wrapper names map to ordered pre_request/post_response chains.\n# Define hook functions in R/ before enabling them here.\n# Example:\n# get_item:\n#   pre_request: [normalize_item_id]\n#   post_response: [extract_item]\n{}"
proposal$missing_imports
#> [1] "yaml"
```

Planning does not write files. The proposed executor reads YAML using
`yaml`, so add that package to the client’s `DESCRIPTION` under
`Imports`. Keep all existing imports. In this disposable example we make
the metadata edit programmatically:

``` r

metadata <- read.dcf(file.path(root, 'DESCRIPTION'))
metadata[1, 'Imports'] <- paste(metadata[1, 'Imports'], 'yaml', sep = ', ')
write.dcf(metadata, file.path(root, 'DESCRIPTION'))
specmill::configure_hooks(root, mode = 'apply')
#> $files
#> $files$`R/hook_registry.R`
#> [1] "# Client-owned hook executor. Edit this file; regeneration preserves it.\nread_hook_config <- function() {\n  # ponytail: read once per stage; cache with an explicit reload if profiling warrants it.\n  path <- system.file('hooks.yml', package = \"hookclient\", mustWork = TRUE)\n  config <- yaml::read_yaml(path, eval.expr = FALSE)\n  if (\n    !is.list(config) ||\n      (length(config) &&\n        (is.null(names(config)) || anyDuplicated(names(config))))\n  ) {\n    stop('hooks.yml must map public function names to hook stages')\n  }\n  config\n}\n\nrun_hook <- function(fn_name, hook_type, data) {\n  if (\n    length(hook_type) != 1L ||\n      is.na(hook_type) ||\n      !hook_type %in% c('pre_request', 'post_response')\n  ) {\n    stop('Unsupported hook stage')\n  }\n  entry <- read_hook_config()[[fn_name]]\n  if (\n    !is.null(entry) &&\n      (!is.list(entry) ||\n        is.null(names(entry)) ||\n        anyDuplicated(names(entry)) ||\n        any(!names(entry) %in% c('pre_request', 'post_response')))\n  ) {\n    stop('Invalid hook stages for ', fn_name)\n  }\n  chain <- entry[[hook_type]]\n  if (is.null(chain) || !length(chain)) {\n    return(if (hook_type == 'post_response') data$result else data)\n  }\n  if (\n    !(is.character(chain) || is.list(chain)) ||\n      !is.null(names(chain)) ||\n      !all(vapply(\n        chain,\n        function(x) {\n          is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)\n        },\n        logical(1)\n      ))\n  ) {\n    stop('Hook chain must be a sequence of function names for ', fn_name)\n  }\n  for (hook_name in chain) {\n    data <- tryCatch(\n      {\n        hook <- get(hook_name, envir = environment(run_hook), inherits = FALSE)\n        if (!is.function(hook)) {\n          stop('Configured hook is not a function')\n        }\n        hook(data)\n      },\n      error = function(parent) {\n        stop(errorCondition(\n          paste(\n            fn_name,\n            hook_type,\n            hook_name,\n            conditionMessage(parent),\n            sep = ': '\n          ),\n          class = 'client_hook_error',\n          parent = parent,\n          function_name = fn_name,\n          hook_name = hook_name,\n          stage = hook_type\n        ))\n      }\n    )\n  }\n  data\n}"
#> 
#> $files$`inst/hooks.yml`
#> [1] "# Public wrapper names map to ordered pre_request/post_response chains.\n# Define hook functions in R/ before enabling them here.\n# Example:\n# get_item:\n#   pre_request: [normalize_item_id]\n#   post_response: [extract_item]\n{}"
#> 
#> 
#> $changes
#> $changes[[1]]
#> $changes[[1]]$file
#> [1] "R/hook_registry.R"
#> 
#> $changes[[1]]$action
#> [1] "create"
#> 
#> $changes[[1]]$before
#> NULL
#> 
#> $changes[[1]]$after
#> [1] "# Client-owned hook executor. Edit this file; regeneration preserves it.\nread_hook_config <- function() {\n  # ponytail: read once per stage; cache with an explicit reload if profiling warrants it.\n  path <- system.file('hooks.yml', package = \"hookclient\", mustWork = TRUE)\n  config <- yaml::read_yaml(path, eval.expr = FALSE)\n  if (\n    !is.list(config) ||\n      (length(config) &&\n        (is.null(names(config)) || anyDuplicated(names(config))))\n  ) {\n    stop('hooks.yml must map public function names to hook stages')\n  }\n  config\n}\n\nrun_hook <- function(fn_name, hook_type, data) {\n  if (\n    length(hook_type) != 1L ||\n      is.na(hook_type) ||\n      !hook_type %in% c('pre_request', 'post_response')\n  ) {\n    stop('Unsupported hook stage')\n  }\n  entry <- read_hook_config()[[fn_name]]\n  if (\n    !is.null(entry) &&\n      (!is.list(entry) ||\n        is.null(names(entry)) ||\n        anyDuplicated(names(entry)) ||\n        any(!names(entry) %in% c('pre_request', 'post_response')))\n  ) {\n    stop('Invalid hook stages for ', fn_name)\n  }\n  chain <- entry[[hook_type]]\n  if (is.null(chain) || !length(chain)) {\n    return(if (hook_type == 'post_response') data$result else data)\n  }\n  if (\n    !(is.character(chain) || is.list(chain)) ||\n      !is.null(names(chain)) ||\n      !all(vapply(\n        chain,\n        function(x) {\n          is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)\n        },\n        logical(1)\n      ))\n  ) {\n    stop('Hook chain must be a sequence of function names for ', fn_name)\n  }\n  for (hook_name in chain) {\n    data <- tryCatch(\n      {\n        hook <- get(hook_name, envir = environment(run_hook), inherits = FALSE)\n        if (!is.function(hook)) {\n          stop('Configured hook is not a function')\n        }\n        hook(data)\n      },\n      error = function(parent) {\n        stop(errorCondition(\n          paste(\n            fn_name,\n            hook_type,\n            hook_name,\n            conditionMessage(parent),\n            sep = ': '\n          ),\n          class = 'client_hook_error',\n          parent = parent,\n          function_name = fn_name,\n          hook_name = hook_name,\n          stage = hook_type\n        ))\n      }\n    )\n  }\n  data\n}"
#> 
#> 
#> $changes[[2]]
#> $changes[[2]]$file
#> [1] "inst/hooks.yml"
#> 
#> $changes[[2]]$action
#> [1] "create"
#> 
#> $changes[[2]]$before
#> NULL
#> 
#> $changes[[2]]$after
#> [1] "# Public wrapper names map to ordered pre_request/post_response chains.\n# Define hook functions in R/ before enabling them here.\n# Example:\n# get_item:\n#   pre_request: [normalize_item_id]\n#   post_response: [extract_item]\n{}"
#> 
#> 
#> 
#> $missing_imports
#> character(0)
#> 
#> $collisions
#> named list()
```

The setup creates two files:

| File | Responsibility |
|----|----|
| `R/hook_registry.R` | Client-owned `read_hook_config()` and `run_hook()` executor |
| `inst/hooks.yml` | Ordered chains keyed by public wrapper name |

No endpoint is enabled automatically. Setup refuses to overwrite
customized files or add a second executor when it finds those function
names elsewhere. If you already have a ComptoxR-style executor, keep it
and configure its callback and YAML path instead. You do not need this
scaffold.

The generated executor adds a `yaml` runtime dependency. It adds no
dependency on specmill, ComptoxR, or a separate hook framework. Commit
the executor and edit it as ordinary client code. It reads the installed
YAML on each stage, without a cache. If this becomes measurable
overhead, add a cache and an explicit reload function in the client.

## Enable pre-request and post-response hooks

In `apis/default.yml`, add these fields at service level:

``` yaml
hook_callback: run_hook
hook_config: inst/hooks.yml
```

For a multi-API configuration, place them inside each participating
entry under `groups`, alongside that group’s `names` and `operations`.
They are not API container or project-level fields. Each group can
reference the same registry. Hook keys are the final public R names,
including any API prefix or rename.

``` r

service_path <- file.path(root, 'apis/default.yml')
service <- yaml::read_yaml(service_path, handlers = list(seq = function(x) x))
service$hook_callback <- 'run_hook'
service$hook_config <- 'inst/hooks.yml'
yaml::write_yaml(service, service_path)
```

Write the declarations in `inst/hooks.yml`:

``` r

writeLines(c(
  'get_item:',
  '  pre_request: [normalize_item_id]',
  '  post_response: [extract_item]'
), file.path(root, 'inst/hooks.yml'))
```

Define those functions in a separate client-owned file. This example
trims the identifier, rejects an empty identifier, and unwraps a
response’s `data` field. The post-hook preserves prepared requests
returned by the client’s dry-run mode.

``` r

writeLines(c(
  'normalize_item_id <- function(state) {',
  '  id <- trimws(state$params$item_id)',
  '  if (length(id) != 1L || is.na(id) || !nzchar(id)) stop("Supply an item ID")',
  '  state$params$item_id <- id',
  '  state',
  '}',
  '',
  'extract_item <- function(state) {',
  '  if (inherits(state$result, "httr2_request")) return(state$result)',
  '  state$result$data',
  '}'
), file.path(root, 'R/hooks_items.R'))
```

Define functions before generating wrappers. Generation validates
referenced hook names and stages. Keep these functions out of generated
endpoint files.

You can instead use inline `hooks` in the service configuration:

``` yaml
hook_callback: run_hook
hooks:
  get_item:
    pre_request: [normalize_item_id]
    post_response: [extract_item]
```

Choose `hooks` or `hook_config`, never both. Inline configuration tells
the **generator** which stages to emit; it does not supply the runtime
executor’s registry. The scaffold reads `inst/hooks.yml`, so using that
same file through `hook_config` avoids maintaining two declarations. A
custom executor may store its policy in R instead.

## Understand the call contract

The generated flow is:

``` text
public input validation
  -> run_hook(name, "pre_request", list(params = params))
  -> update public parameters from returned state$params
  -> request helper
  -> run_hook(name, "post_response", list(result = result, params = params))
  -> final return value
```

Hooks run once around the helper call. They do not run once per internal
retry, page, or batch. Transport errors propagate; `post_response` is
not an error or finally handler and does not receive failed HTTP
responses automatically.

Each hook receives one argument. Pre-hooks return a list containing
`params`. Only returned parameter names matching public inputs replace
those inputs. To remove a value, retain its name with a `NULL` value,
for example `state$params['language'] <- list(NULL)`. Dropping a name
leaves the original public value unchanged. New internal request values
require explicit mappings.

Chains run in declaration order, with each return value passed to the
next hook. In a post-chain, keep returning state until the final hook
returns the public result, or deliberately make later hooks accept the
earlier hook’s result type. The scaffold supplies no automatic wrapping
between hooks and does not inject ComptoxR’s `fn_name` or `hook_type`
fields into state.

Schema-derived public inputs are validated before the pre-hook. A hook
cannot repair an input already rejected by that validation. Use explicit
`inputs` and request mappings when you need a different public contract;
see [operation
settings](https://seanthimons.github.io/specmill/articles/configuration.html#operation-settings).
After transformation, hooks own validation of their constructed values;
there is no second schema validation gate. Request-helper transport
checks still apply.

## Generate and test offline

Preview, inspect the generated source, then apply:

``` r

plan <- specmill::generate_client(root, config = 'specmill.yml', mode = 'plan')
plan
#> Selected operations (4)
#>   hookclient: GET /items/{item_id} -> get_item
#>   hookclient: GET /items -> list_items
#>   hookclient: POST /items -> create_item
#>   hookclient: POST /refresh -> refresh
#> 
#> Excluded operations (0)
#> 
#> Files to remove
#> Server selection requires an explicit override at runtime:
#>   GET /items/{item_id}: Relative server URL requires a recorded origin or explicit base URL override
#>   GET /items: Relative server URL requires a recorded origin or explicit base URL override
#>   POST /items: Relative server URL requires a recorded origin or explicit base URL override
#>   POST /refresh: Relative server URL requires a recorded origin or explicit base URL override
specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
#> Selected operations (4)
#>   hookclient: GET /items/{item_id} -> get_item
#>   hookclient: GET /items -> list_items
#>   hookclient: POST /items -> create_item
#>   hookclient: POST /refresh -> refresh
#> 
#> Excluded operations (0)
#> 
#> Files to remove
#> Server selection requires an explicit override at runtime:
#>   GET /items/{item_id}: Relative server URL requires a recorded origin or explicit base URL override
#>   GET /items: Relative server URL requires a recorded origin or explicit base URL override
#>   POST /items: Relative server URL requires a recorded origin or explicit base URL override
#>   POST /refresh: Relative server URL requires a recorded origin or explicit base URL override
wrapper <- readLines(file.path(root, 'R/get_item.R'))
cat(grep('run_hook|skip_request|changed|result <- api_request', wrapper, value = TRUE), sep = '\n')
#>   state <- run_hook("get_item", "pre_request", base::list(params = params))
#>   if (base::isTRUE(state$skip_request)) base::return(state$result)
#>   changed <- base::intersect(base::names(params), base::names(state$params))
#>   params[changed] <- state$params[changed]
#>   result <- api_request(method = "GET", path = "/items/{item_id}", path_params = base::list("item_id" = params[["item_id"]]), query = base::list("language" = params[["language"]]), body = NULL, request_controls = base::evalq(list(timeout = 30L, max_retries = 0L, retry_writes = FALSE), envir = base::baseenv()), server = base::evalq(list(diagnostic = "Relative server URL requires a recorded origin or explicit base URL override"), envir = base::baseenv()))
#>   result <- run_hook("get_item", "post_response", base::list(result = result, params = params))
```

This check loads client functions into an isolated environment and
replaces the HTTP helper with a recording function. It also points the
config reader at the source YAML. That replacement is for this
source-level test only; the installed executor uses
[`system.file()`](https://rdrr.io/r/base/system.file.html) to find its
own package’s registry.

``` r

client <- new.env(parent = baseenv())
for (path in list.files(file.path(root, 'R'), '\\.R$', full.names = TRUE)) {
  sys.source(path, envir = client)
}
client$read_hook_config <- function() yaml::read_yaml(file.path(root, 'inst/hooks.yml'))
calls <- list()
client$api_request <- function(...) {
  calls[[length(calls) + 1L]] <<- list(...)
  list(data = list(id = 'abc', title = 'Example'))
}
stopifnot(identical(client$get_item(' abc ')$id, 'abc'))
stopifnot(identical(calls[[1]]$path_params$item_id, 'abc'))
error <- tryCatch(client$get_item('   '), error = identity)
stopifnot(inherits(error, 'client_hook_error'), length(calls) == 1L)
stopifnot(identical(error$hook_name, 'normalize_item_id'))
specmill::check_client_hooks(
  root, yaml::read_yaml(file.path(root, 'inst/hooks.yml')),
  hooks = client
)
specmill::generate_client(root, config = 'specmill.yml', mode = 'check')
#> Selected operations (4)
#>   hookclient: GET /items/{item_id} -> get_item
#>   hookclient: GET /items -> list_items
#>   hookclient: POST /items -> create_item
#>   hookclient: POST /refresh -> refresh
#> 
#> Excluded operations (0)
#> 
#> Files to remove
#> Server selection requires an explicit override at runtime:
#>   GET /items/{item_id}: Relative server URL requires a recorded origin or explicit base URL override
#>   GET /items: Relative server URL requires a recorded origin or explicit base URL override
#>   POST /items: Relative server URL requires a recorded origin or explicit base URL override
#>   POST /refresh: Relative server URL requires a recorded origin or explicit base URL override
```

Keep an equivalent check in your client’s tests. Test chain order,
representative results, empty/invalid inputs, and any skip behavior you
implement. Generated request contract tests cover helper calls; they do
not establish that your response transformation is correct. A failed
hook stops the chain and carries its original condition in
`error$parent`, plus the function, stage, and hook name.

Before distributing the package, install it and exercise the executor
from the installed namespace. This catches missing `inst/hooks.yml`,
missing runtime imports, and accidental development dependencies:

``` r

# Run in a shell, replacing the path with your client root:
# R CMD INSTALL path/to/client
# R CMD build path/to/client
# R CMD check --no-manual hookclient_0.0.0.9000.tar.gz

library(hookclient)
stopifnot(file.exists(system.file('hooks.yml', package = 'hookclient')))
hookclient::hookclient_dry_run(TRUE)
request <- hookclient::get_item(' abc ')
stopifnot(inherits(request, 'httr2_request'))
hookclient::hookclient_dry_run(FALSE)
```

## Pass extra state or skip a request

A pre-hook can return `state$skip_request <- TRUE` and a `state$result`
value. By default the wrapper returns that result immediately, without a
helper or post-hook call. To format cached or locally computed results
through the post-chain, configure the operation:

``` yaml
operations:
  GET /items/{item_id}:
    post_on_skip: true
    post_state: hook_state
```

`post_on_skip` and `post_state` are independent options. Both require a
configured pre-hook. `post_state: hook_state` passes the entire
pre-state to the post-hook, with `result` replaced by the helper result
or skipped result. It is useful for metadata such as the original
identifier or a local lookup outcome.

For example, replace the pre-hook above with this version and regenerate
after adding the operation settings:

``` r

normalize_item_id <- function(state) {
  state$original_id <- state$params$item_id
  state$params$item_id <- trimws(state$params$item_id)
  id <- state$params$item_id
  if (length(id) != 1L || is.na(id) || !nzchar(id)) stop('Supply an item ID')
  if (identical(state$params$item_id, 'local')) {
    state$skip_request <- TRUE
    state$result <- list(data = list(id = 'local', title = 'Local item'))
  }
  state
}
```

The skipped result deliberately has the same shape as the helper result,
so `extract_item()` handles both. The wrapper does not stop a pre-chain
early when a hook sets `skip_request`; later pre-hooks still run.

To send data constructed outside `params`, provide explicit helper
mappings:

``` yaml
operations:
  POST /items:
    request:
      arguments:
        method: {value: POST}
        path: {value: /items}
        path_params: {value: {}}
        query: {value: {}}
        body: {from: [hook_state, request, body]}
```

This requires a pre-hook on `create_item` that sets
`state$request$body`. `request.arguments` specifies the helper call, so
include all arguments your helper requires. For additional public
options use `extra_parameters` in the operation configuration, not
ComptoxR’s legacy `extra_params` inside hook YAML. See [request
bindings](https://seanthimons.github.io/specmill/articles/configuration.md)
for authentication, headers, body, and options mappings. Hook
configuration alone does not change a signature.

## Regeneration and ownership

Commit the schema, project/service YAML, runtime YAML, hook functions,
executor, generated wrappers, documentation, tests, and
`.specmill/manifest.json` together. Use
[`configure_hooks()`](https://seanthimons.github.io/specmill/reference/configure_hooks.md)
for initial setup only. It refuses to overwrite edits. Use
[`generate_client()`](https://seanthimons.github.io/specmill/reference/generate_client.md)
to reconcile wrappers after configuration changes.

| Change | Required development step |
|----|----|
| Edit a hook function body | Run its tests; reinstall or reload client code |
| Reorder or replace names in an already emitted stage | Validate and regenerate/check; reinstall to ship the updated YAML |
| Add the first hook or remove the last hook for a stage | Regenerate; the wrapper must gain or lose that stage call |
| Change parameters, request mappings, skip behavior, or post-state settings | Regenerate and test the resulting helper calls and hook state |
| Rename a public wrapper | Update the hook YAML key and service names together, then regenerate |
| Update a schema | Review schema and configuration differences, regenerate, then run checks |
| Update the executor template in specmill | Review and manually adopt changes in the client-owned executor |

The executor reads the installed registry. Editing `inst/hooks.yml` in a
source checkout does not change an already installed package. Reinstall
and start a fresh R session when verifying shipped behavior. Do not edit
the installed library as your development workflow.

``` r

specmill::generate_client(root, config = 'specmill.yml', mode = 'plan')
# Review the proposed changes and diagnostics.
specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
specmill::generate_client(root, config = 'specmill.yml', mode = 'check')
```

`check` makes no changes and fails for stale or protected generated
output. Normal generation retains the client-owned executor, hook
functions, and runtime YAML. If a generated file was edited by hand,
move that customization into hooks or operation configuration and follow
the [ownership
workflow](https://seanthimons.github.io/specmill/articles/maintenance.md).
Do not bypass protection by deleting the manifest.

Declarations for missing wrappers in an external `hook_config` file
appear in `unused_hooks`. Review them after renaming or removing
operations; they can be intentional when several services share one
registry. Referenced hook functions must exist in client source.
Generation validates wiring, not the behavior of every possible return
value.

For a ComptoxR migration, keep its existing executor, merge rules, error
classes, and state conventions. Set `hook_callback` to that executor and
`hook_config` to its registry. Specmill reads pre/post declarations from
that file; legacy extra parameters and request templates need
corresponding operation configuration. See [adopt an existing
client](https://seanthimons.github.io/specmill/articles/existing-clients.md).
