\name{validate_schema}
\alias{validate_schema}
\title{Validate a local API schema with Swagger Validator}
\description{Upload original JSON or YAML bytes to a configured Swagger Validator and cache a report tied to those bytes and the validation policy.}
\usage{
validate_schema(file,
    validator_url = "https://validator.swagger.io/validator",
    cache_dir = tools::R_user_dir("specmill", "cache"),
    timeout = 30, refresh = FALSE)
}
\arguments{
\item{file}{Existing local JSON or YAML OpenAPI document.}
\item{validator_url}{Base URL of a Swagger Validator exposing \code{/debug} and \code{/openapi.json}. Credentials, query strings and fragments are prohibited.}
\item{cache_dir}{Directory for cached JSON reports. Defaults to the user's Specmill cache outside the client. Use \code{NULL} to disable caching.}
\item{timeout}{Finite positive timeout in seconds per HTTP request.}
\item{refresh}{Ignore a matching cached report and contact the validator again.}
}
\value{A list containing \code{status}, \code{reason}, \code{coverage}, source path and SHA-256, schema and validator versions, timestamp, operation identities, normalized \code{findings}, raw \code{responses}, and \code{cached}. Hosted reports also contain effective \code{options} and a cache \code{identity}. Status is \code{passed}, \code{invalid}, \code{unverified}, or \code{unsupported}.}
\details{
OpenAPI 3.0 uses both legacy and alternate validation engines; Swagger 2.0 uses
the alternate engine because the tested legacy engine missed structural errors.
Both semantic messages and schema-validation messages are checked. Warnings are
retained; unclassified semantic messages conservatively require review.
Unknown reports, HTTP failures, redirects, and timeouts never pass validation.
Transport failures are not cached.

A clean OAS 3.1 report remains unsupported because the tested service lacks
structural validation coverage for that version. Schemas with external references,
including local sibling files, require a self-contained bundle. Specmill does not
upload an incomplete reference graph or silently rewrite the source document.
Reference detection is conservative: external \code{$ref} keys in example data
also require review.

Instance pointers locate operations or shared path items. Shared-component errors
and messages without a usable pointer conservatively block the whole document.
The original schema is neither repaired nor replaced. Passing this check does
not establish generator support or live API compatibility.

Cached outcomes are reconstructed from raw reports rather than trusting a stored
status. Identities include original bytes, input format, validator URL,
engine options, and report-policy version. Validator version and timestamp record
the service used at validation time; cache reuse does not contact the service to
check for a newer deployment. Use \code{refresh = TRUE} after validator upgrades.

Uncached validation needs the suggested \pkg{httr2} package. The public default
uploads the complete schema, including examples. Configure a self-hosted URL for
private definitions. Cache reports can contain excerpts returned by the validator.
}
\examples{
\dontrun{
report <- validate_schema("schema/openapi.json")
report$status
report$findings
}
}
\seealso{\code{\link{generate_client}}}
