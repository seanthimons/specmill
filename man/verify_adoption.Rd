\name{verify_adoption}
\alias{verify_adoption}
\title{Verify configured operations against hand-written wrappers}
\description{Check that each configured operation would replace its existing hand-written wrapper without changing formals, helper calls, results, or documentation.}
\usage{
verify_adoption(root, config = "specmill.yml", callbacks = new.env(parent = emptyenv()), wrappers = NULL)
}
\arguments{
\item{root}{Explicit existing client root directory.}
\item{config}{Project YAML path relative to root.}
\item{callbacks}{Explicit environment containing named development callbacks.}
\item{wrappers}{Optional wrapper names to check. By default every configured, generated operation with a hand-written definition outside manifest-owned files is checked.}
}
\value{A list with \code{operations} (per wrapper: \code{file}, \code{status} \code{"verified"} or \code{"failed"}, and \code{reason}), \code{contracts} (fixed contracts for verified wrappers, in the \code{contracts_file} format), and \code{files} (SHA-256 hashes of source files whose every definition verified).}
\details{Nothing in \code{root} is written. Generation runs on a temporary copy with the candidate definitions removed, so the check covers exactly the code \code{generate_client()} would write. Both wrappers run with the configured helper replaced by a recording stub: with required inputs only, with every input explicit, with each optional input explicit, \code{FALSE}, and \code{0}, and with no arguments. Helper calls, arguments, and results (or error messages) must be identical. Documentation is compared as Rd rendered by \code{roxygen2::roc_proc_text()}, ignoring the source-file header.

To adopt verified wrappers, save the contracts to the service \code{contracts_file}, delete the listed \code{files}, and apply. Adoption hashes do not lift lifecycle protection, so deletion is the adoption step. A file with other code or unverified wrappers fails; separate it first.}
\seealso{\href{https://seanthimons.github.io/specmill/articles/existing-clients.html}{Step-by-step guide}.}
