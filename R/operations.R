# Public compatibility entry point. Selection and naming remain reviewed policy;
# OpenAPI-specific document and request reading lives in the native importer.
#' Read and compare local schema operations
#'
#' Extract operation records from local OpenAPI 3.0, 3.1 or 3.2 or Swagger 2.0 JSON or YAML schemas, or reviewed ArcGIS service captures and compare their input contracts.
#'
#' @param files Local JSON, YAML, or YML schema paths.
#' @param policy A list with optional service identity, methods allowlist, include allowlist of exact METHOD /path keys, path exclude regexes, names keyed by METHOD /path, and override_keys for declared operation settings. When include is supplied, an operation must match it as well as the method and path filters; an empty include selects nothing. Unknown included keys are errors. For GraphQL introspection results, keys are \code{query <field>} or \code{mutation <field>}, and the policy may also carry `graphql_fields` and `graphql_documents` keyed by operation and a `graphql_path`.
#' @param format Optional registered source format override: `openapi`, `swagger`, `arcgis-rest`, `google-discovery`, or `graphql`. NULL detects the format from content.
#' @return read_operations() returns named operations and unsupported_operations plus diagnostic, body_diagnostics, server_diagnostics, and inventory lists. body_diagnostics contains nonblocking opaque request-body reviews with reference URL, SHA-256, reason and source location. Supply operation reviews through policy$opaque_bodies, keyed by method/path, each containing reference and reason. Path-name mismatches produce one diagnostic per unmatched declaration or missing placeholder, with the existing code, reason, stable method/path key, source file and JSON Pointer. Multiple diagnostics can share an operation ID; inventory remains one row per operation and summarizes the first diagnostic. Missing declarations point to the path item because no parameter object exists. These checks run after parameter parsing; earlier errors can still prevent them. Every operation carries server metadata containing a resolved URL or a selection diagnostic; runtime overrides may resolve the latter. Effective server changes are reported for review. compare_operations() returns change records with key, status (added, breaking, review, or unknown), and reason; no changes returns an empty list.
#' @details The supported subset includes scalar and supported flat array/object parameters in path, query, header and cookie locations; JSON scalar/nested-object/array bodies with supported composition and bounded local recursion; binary string bodies sent as application/octet-stream; and supported URL-encoded and multipart form bodies. Binary inputs are raw vectors; multipart files also accept curl::form_file values. JSON is selected when offered unless policy selects another supported media type. Same-document and local-file references are resolved; remote references are not downloaded. Unsupported references, media, constraints and parameter/body shapes are diagnosed. See the configuration guide for serialization styles and limits. Structurally valid unsupported metadata is returned separately for reviewed client mapping. Effective security requirements and resolved security schemes are retained for generation. Authentication changes are reported for review. Generated authentication is enabled by the project's authentication environment-variable map; existing client helpers remain responsible when that map is omitted. This is not a full schema validator. Comparison classifies input changes conservatively and cannot prove HTTP or response compatibility.
#' @seealso [Step-by-step guide](https://seanthimons.github.io/specmill/articles/troubleshooting.html).
#' @examples
#' schema <- system.file('catalogue/schema.json', package = 'specmill')
#' parsed <- read_operations(schema)
#' names(parsed$operations)
#' stopifnot(length(compare_operations(parsed, parsed)) == 0L)
#' @export
read_operations <- function(files, policy = list(), format = NULL) {
  policy <- prepare_operation_policy(policy)
  finish_operation_policy(
    importer_records(files, operation_review_context(policy), format),
    policy
  )
}

#' @rdname read_operations
#' @param old Results from `read_operations`.
#' @param new Results from `read_operations`.
#' @export
compare_operations <- function(old, new) {
  identity <- function(op) {
    paste(op$service %or% basename(op$source %or% ''), op$key)
  }
  old <- setNames(
    old$operations,
    vapply(old$operations, identity, character(1))
  )
  new <- setNames(
    new$operations,
    vapply(new$operations, identity, character(1))
  )
  out <- list()
  add <- function(key, status, reason) {
    out[[length(out) + 1L]] <<- list(
      key = key,
      status = status,
      reason = reason
    )
  }
  for (key in setdiff(names(old), names(new))) {
    add(key, 'breaking', 'Operation removed')
  }
  for (key in setdiff(names(new), names(old))) {
    add(key, 'added', 'Operation added')
  }
  for (key in intersect(names(old), names(new))) {
    a <- old[[key]]
    b <- new[[key]]
    ids <- function(ps) {
      setNames(
        ps,
        vapply(ps, function(p) paste(p$location, p$name), character(1))
      )
    }
    ap <- ids(a$parameters)
    bp <- ids(b$parameters)
    for (id in setdiff(names(bp), names(ap))) {
      add(
        key,
        if (isTRUE(bp[[id]]$required)) 'breaking' else 'added',
        paste('Parameter added:', id)
      )
    }
    if (length(setdiff(names(ap), names(bp)))) {
      add(key, 'breaking', 'Parameter removed')
    }
    for (id in intersect(names(ap), names(bp))) {
      if (!identical(ap[[id]], bp[[id]])) {
        add(key, 'review', paste('Parameter contract changed:', id))
      }
    }
    if (
      !identical(a$body, b$body) ||
        !identical(a$body_required, b$body_required) ||
        !identical(a$body_media, b$body_media) ||
        !identical(a$body_encoding, b$body_encoding) ||
        !identical(a$text_encoding, b$text_encoding)
    ) {
      add(key, 'review', 'Body changed')
    }
    if (!identical(a$server, b$server)) {
      add(key, 'review', 'Effective server changed')
    }
    if (!identical(a$response, b$response)) {
      add(key, 'unknown', 'Response compatibility is not classified')
    }
    if (
      !identical(a$security, b$security) ||
        !identical(a$security_schemes, b$security_schemes)
    ) {
      add(key, 'review', 'Authentication requirements changed')
    }
  }
  out
}
