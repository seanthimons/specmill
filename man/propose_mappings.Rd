\name{propose_mappings}
\alias{propose_mappings}
\title{Propose operation mappings for hand-written wrappers}
\description{Screen hand-written wrappers, propose explicit \code{inputs}, \code{request}, and \code{docs} mappings for one service, and keep only the proposals that \code{verify_adoption()} confirms are equivalent.}
\usage{
propose_mappings(root, files, service, config = "specmill.yml", callbacks = new.env(parent = emptyenv()), route = NULL, bindings = NULL, prelude = NULL)
}
\arguments{
\item{root}{Explicit existing client root directory.}
\item{files}{Source files to screen, relative to root.}
\item{service}{ID of the service whose helper and selected operations the wrappers map to. The service must be defined in its own service file.}
\item{config}{Project YAML path relative to root.}
\item{callbacks}{Explicit environment containing named development callbacks.}
\item{route}{Optional \code{function(name, call)} returning the operation key, such as \code{"GET /items/{item_id}"}, for a wrapper's helper call. By default, literal \code{method} and \code{path} helper arguments must match a selected operation exactly.}
\item{bindings}{Optional \code{function(expr)} returning a request binding (for example \code{list(callback = "batch_limit")}) for a helper argument expression, or \code{NULL} when it does not apply.}
\item{prelude}{Optional \code{function(code)} receiving the wrapper's body statements. It returns \code{NULL}, or a list with \code{statements} (how many leading statements it accounts for) and \code{arguments} (request bindings for the helper arguments those statements build).}
}
\value{A list with \code{operations} (per wrapper: \code{file}, \code{status} \code{"proposed"} or \code{"retained"}, \code{reason}, and the matched operation \code{key}), \code{proposals} (verified mappings keyed by operation), \code{yaml} (the proposals as a service \code{operations:} map), and \code{contracts} and \code{files} as returned by \code{verify_adoption()}.}
\details{Nothing in \code{root} is written. A wrapper is proposed when its body is a single call to the service helper (optionally \code{result <- helper(...); result} or \code{return(result)}), after any statements the \code{prelude} callback accounts for. Its defaults must be plain data literals, and its roxygen block may use only a title, a lifecycle badge and description, \code{@param}, \code{@return}, \code{@export}, and \code{@examples} that call the wrapper with literal inputs. Helper arguments bind a formal to \code{from}, a data literal to \code{value}, and a \code{list()} of those to \code{object} or \code{array}; the \code{bindings} callback handles anything else. Every other wrapper is retained with a reason, as is any proposal that fails verification against the staged service configuration.

Review \code{yaml}, copy it into the service file, and adopt as described in \code{verify_adoption()}.}
\examples{
# Recognize `query <- list(); if (!is.null(x)) query$key <- x; ...` before the helper call.
# The optional values it collects are exactly a compact_object binding.
query_prelude <- function(code) {
  if (!length(code) || !identical(code[[1L]], quote(query <- list()))) {
    return(NULL)
  }
  fields <- list()
  for (statement in code[-1L]) {
    assignment <- if (is.call(statement) && identical(statement[[1L]], as.name('if'))) statement[[3L]]
    target <- if (is.call(assignment) && identical(assignment[[1L]], as.name('<-'))) assignment[[2L]]
    value <- if (!is.null(target)) assignment[[3L]]
    if (
      !is.call(target) || !identical(target[[1L]], as.name('$')) ||
        !identical(target[[2L]], as.name('query')) || !is.symbol(value) ||
        !identical(statement[[2L]], call('!', call('is.null', value)))
    ) {
      break
    }
    fields[[as.character(target[[3L]])]] <- list(from = list('params', as.character(value)))
  }
  list(statements = 1L + length(fields), arguments = list(query = list(compact_object = fields)))
}
\dontrun{
proposal <- specmill::propose_mappings(root, 'R/items.R', 'catalogue', prelude = query_prelude)
proposal$operations
cat(proposal$yaml)
}
}
\seealso{\href{https://seanthimons.github.io/specmill/articles/existing-clients.html}{Step-by-step guide}.}
