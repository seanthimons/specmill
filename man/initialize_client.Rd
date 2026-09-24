\name{initialize_client}
\alias{initialize_client}
\title{Initialize a new client package}
\description{Create absent package scaffold files, a local schema copy, project policy, a client-owned httr2 request helper, and session controls.}
\usage{
initialize_client(root, schema, package = NULL, title = NULL, author = NULL,
    license = NULL, base_url = NULL,
    naming = c("operation_id", "tag_prefix"), group_by = c("tag", "none"),
    name_case = c("asis", "snake_case", "camel_case", "pascal_case",
        "screaming_snake_case", "dot_case"))
}
\arguments{
\item{root}{Destination client directory; it may be created when absent.}
\item{schema}{Local JSON, YAML, or YML schema, or a reviewed data frame returned by configure_apis for multiple APIs. Multi-API setup requires an existing root containing those schemas, and a new package. Each included API receives a separate request helper, namespaced function names and credential identities.}
\item{package}{New R package name, for example \code{catalogueclient}. Must agree with an existing DESCRIPTION when supplied.}
\item{title}{Human-readable package title, required for a new package.}
\item{author}{Named list with \code{given}, \code{family}, and \code{email} strings, required for a new package.}
\item{license}{Explicit license string for a new package. \code{MIT + file LICENSE} also creates an MIT license metadata file.}
\item{base_url}{Optional absolute HTTP(S) override for all operations in the new client-owned transport. Overrides schema servers; a runtime option can override it.}
\item{naming}{Preserve operationId names by default, or propose tag-prefixed snake_case names. See configure_client.}
\item{group_by}{Group operations by first tag (default), or use one default group with none. Multi-API initialization writes one YAML file per API with nested groups; single-schema initialization keeps flat group files.}
\item{name_case}{Case convention for proposed names. Choices are as-is, snake_case, camelCase, PascalCase, SCREAMING_SNAKE_CASE, and dot.case. See configure_client.}
}
\value{A list of applied file records, each containing file, path, and action. The configuration attribute contains proposed files, operation assignments, and diagnostics. Stops before application for invalid metadata, tag filename collisions, or conflicting scaffold paths.}
\details{This function writes immediately and refuses any existing-file conflict. Supply package, title, author (given, family, email), and license for a new package. Existing DESCRIPTION metadata is retained; it must already declare httr2 and jsonlite, which the default transport needs for HTTP and JSON. Adding a new default transport also requires curl for form uploads. Without an explicit override, generated wrappers use operation, path, then root servers, resolving variable defaults. Ambiguous or unsupported selection produces server_diagnostics and fails before HTTP unless a runtime override is supplied. Baseline YAML defaults.request_controls exposes timeout, max_retries, and retry_writes. Regeneration passes these inherited defaults into helper calls without editing the client-owned helper. Runtime options override these fields. The helper reads the lowercase dry-run prefix plus .request as an R option containing base_url, timeout (default 30 seconds per attempt), max_retries (default 0), and retry_writes (default FALSE). Enabled retries cover transient HTTP responses for GET, HEAD, OPTIONS, PUT and DELETE; other methods need explicit write permission. Retry-After is honored. Normal generation never updates this helper. Initialization does not generate wrappers or tests: follow with generate_client(). The helper is client runtime code and does not import specmill.

New clients also receive client-owned \code{R/api_options.R} with
\code{<package>_run_verbose(verbose = FALSE)} and
\code{<package>_dry_run(enabled = FALSE)}. Function prefixes preserve the exact
package name; no unprefixed control aliases are exported.
These set package-prefixed \code{run_verbose} and \code{dry_run} R options.
Both default to off. An explicit dry-run option overrides the legacy dry-run
environment flag. Dry runs return prepared httr2 requests without sending them;
input validation and authentication still apply, and returned requests may
contain credentials. Verbose messages contain method and HTTP status only.
Multi-API clients share one set of controls. Existing helpers and clients require
manual adoption; regeneration never overwrites client-owned runtime files.}
\seealso{\code{configure_hooks} for optional client-owned pre/post execution. \href{https://seanthimons.github.io/specmill/articles/specmill.html}{Step-by-step guide}.}

\note{Service YAML includes explicit operation allowlists and editable names, including unsupported operations. Name collisions and unsupported transports require review before wrapper generation; initialization does not resolve them. Inspect attr(result, 'configuration')$diagnostics, or preview with configure_client() before initialization.}
