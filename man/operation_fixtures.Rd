\name{operation_fixtures}
\alias{operation_fixtures}
\title{Choose candidate operation inputs}
\description{Choose fixture values using reviewed overrides followed by parameter or media examples, schema examples, defaults, enums, and type fixtures.}
\usage{
operation_fixtures(operations, overrides = list(), mode = c("default", "minimal"))
}
\arguments{
\item{operations}{Supported operation record or named list of records.}
\item{overrides}{Reviewed per-operation fixture input values.}
\item{mode}{Default exercises optional inputs. Explicit minimal mode omits optional parameters and optional bodies unless overridden, and records their names in each input list's \code{omitted_inputs} attribute.}
}
\value{A named list of per-operation input lists. Stops when a fixture cannot be selected or fails supported constraints.}
\details{The selected value must satisfy supported type, enum, numeric, string-length, and pattern constraints. An invalid selected candidate raises an error rather than falling through to a lower-priority source. Automatic selection uses the singular example field; plural examples collections require a reviewed override to select a member. Empty query values require allowEmptyValue, matching generated wrapper validation. Examples never become public function defaults. Minimal mode reduces coverage; omission can activate a wrapper default and does not guarantee wire omission. Explicit NULL, empty strings, FALSE, and zero are selected values and remain subject to validation. Contradictory declarations are separately available from \code{read_operations()} as \code{fixture_diagnostics}; optional contradictions do not prevent rendering. Schema examples are never executed. Candidate inputs are not independent expected request or response contracts.}
\seealso{\href{https://seanthimons.github.io/specmill/articles/testing.html}{Step-by-step guide}.}
\examples{
schema <- system.file('catalogue/schema.json', package = 'specmill')
operation_fixtures(read_operations(schema)$operations)
}
