\name{review_recordings}
\alias{review_recordings}
\title{Check recorded responses against the OpenAPI response schema}
\description{Validate each declared scenario's recorded response bodies against the response schema its operation declares, and report the result for review. No file is changed.}
\usage{
review_recordings(root, config = "specmill.yml", callbacks = new.env(parent = emptyenv()))
}
\arguments{
\item{root}{Explicit existing client root directory.}
\item{config}{Project YAML path relative to root.}
\item{callbacks}{Explicit environment containing named development callbacks.}
}
\value{A list keyed by service ID, then scenario ID. Each entry holds the \code{route}, the \code{cassette} path and a \code{status}: \code{agrees}, \code{disagrees} with \code{errors} (instance paths and messages, never recorded values, although a path can name a key from the recorded body), or \code{unchecked} with a \code{reason}. \code{placeholders} lists any testing filter placeholders found in the recording.}
\details{Only interactions whose method and path match the scenario's operation are checked. The schema for the recorded status is used, then its \code{2XX}-style range, then \code{default}; OpenAPI 3 uses the JSON media type and Swagger 2 the response schema; shared responses (\code{$ref} into the document's responses) are followed. Bodies vcr kept as base64 (raw or gzip) are decoded first. Internal references resolve against the schema document's component schemas or definitions; examples, defaults and \code{x-} extensions are ignored. OpenAPI 3.0 and Swagger 2 validate as JSON Schema draft 4, with \code{nullable} honored, and OpenAPI 3.1 as draft 2020-12. A disagreement means review the recording or the schema; it never marks either as correct, and it never re-records. Values replaced by testing filters read as placeholders and can disagree.}
\seealso{\code{\link{propose_testing}}, \href{https://seanthimons.github.io/specmill/articles/testing.html}{Step-by-step guide}.}
