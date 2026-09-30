\name{batched}
\alias{batched}
\title{Call a function in batches}
\description{Splits items into requests of at most \code{size} and calls \code{fn} once per batch.}
\usage{
batched(fn, items, size, ..., policy = list())
}
\arguments{
\item{fn}{Function called with each batch as its first argument.}
\item{items}{Vector or list of items to split.}
\item{size}{Positive integer maximum number of items per batch.}
\item{...}{Additional arguments passed unchanged to \code{fn}.}
\item{policy}{Named list of explicit client choices: \code{normalize(items)},
\code{build(chunk, index)}, and \code{merge(results)} functions;
\code{on_error} set to \code{stop} by default, or \code{drop}/\code{keep}
for recovery with warnings; \code{error_result} retained by keep;
and \code{first_batch_only = TRUE} for explicit legacy pagination compatibility.
Normalization, construction and merging errors always propagate.}
}
\value{A named list of unmerged results, one per batch, unless a merge function is selected.}
\details{Inputs and order are preserved by default. Every chunk calls the supplied
function through its existing authentication, query, retry and response policy.
The companion performs no HTTP or response decoding. Optional normalization may
remove duplicates, missing and empty values. Optional construction may preserve
singleton JSON arrays with as.list or join raw text explicitly.}
\examples{
batched(sum, 1:5, 2)
}
