\name{validate_schema}
\alias{validate_schema}
\title{Validate a local API schema against its OpenAPI specification}
\description{Check a local JSON or YAML document against the official Swagger 2.0, OpenAPI 3.0 or OpenAPI 3.1 JSON Schema. Validation runs locally; nothing is uploaded.}
\usage{
validate_schema(file)
}
\arguments{
\item{file}{Existing local JSON or YAML OpenAPI document.}
}
\value{A list containing \code{status}, \code{reason}, source path and SHA-256, schema version, \code{validator}, operation identities, and normalized \code{findings}. Status is \code{passed}, \code{invalid}, or \code{unsupported}.}
\details{
The document is checked with the ajv build shipped in \pkg{jsonvalidate}, run
through \pkg{V8}, against the OpenAPI Initiative schemas bundled in
\code{inst/validation}. OAS 3.1 Schema Objects are checked against the default
OAS 3.1 JSON Schema 2020-12 dialect; a document declaring another
\code{jsonSchemaDialect} is still checked against the default one.

Structural checks catch wrong types, missing required fields, unknown fields and
invalid keywords. They do not cover rules the specification states only in
prose, such as unique operation IDs or resolvable internal references.
Unparseable documents, non-object roots and duplicate keys are invalid. Other
versions and schemas with external references, including local sibling files,
are unsupported; bundle them into one document first. Reference detection is
conservative: external \code{$ref} keys in example data also require review.

Each finding carries a JSON pointer. Pointers under an operation block that
operation; pointers under a path item block every operation on that path. Shared
components and root-level errors block the whole document. The original schema
is neither repaired nor replaced. Passing this check does not establish generator
support or live API compatibility.
}
\examples{
\dontrun{
report <- validate_schema("schema/openapi.json")
report$status
report$findings
}
}
\seealso{\code{\link{generate_client}}}
