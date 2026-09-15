\name{batched}
\alias{batched}
\title{Call a function in batches}
\description{Splits items into requests of at most \code{size} and calls \code{fn} once per batch.}
\usage{
batched(fn, items, size, ...)
}
\arguments{
\item{fn}{Function called with each batch as its first argument.}
\item{items}{Vector or list of items to split.}
\item{size}{Positive integer maximum number of items per batch.}
\item{...}{Additional arguments passed to \code{fn}.}
}
\value{A list of unmerged results, one per batch. Errors from \code{fn} propagate.}
\examples{
batched(sum, 1:5, 2)
}
