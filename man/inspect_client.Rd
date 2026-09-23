\name{inspect_client}
\alias{inspect_client}
\title{Inspect implementation and fixed-contract coverage}
\description{Compare selected YAML operations with client source definitions, exports, and fixed test files.}
\usage{
inspect_client(root, config = "specmill.yml", callbacks = new.env(parent = emptyenv()))
}
\arguments{
\item{root}{Explicit existing client root directory.}
\item{config}{Project YAML path relative to root, or client hook configuration for hook validation.}
\item{callbacks}{Explicit environment containing named development callbacks.}
}
\value{A list with operations, inventory, diagnostics, manual_exports, coverage, helpers, and protected_sources. Coverage is keyed by service ID and contains total selected operations, implemented exported definitions, and declared contracts with test files.}
\details{This is a read-only structural inspection. Unsupported selections remain in coverage totals. Manual exports are listed separately. A present test file is not evidence that tests ran or passed.}
\seealso{\href{https://seanthimons.github.io/specmill/articles/testing.html}{Step-by-step guide}.}
\section{Client-owned helpers}{Newly initialized helpers retain their substituted
baseline and template hash under \file{.specmill/helpers/}. The \code{helpers}
result includes baseline, local and proposed current source for read-only review,
local/upstream change flags, and missing explicit helper arguments. Legacy helpers
have unknown baselines. Argument compatibility does not establish behavior.
Manually merge selected improvements and run request/transport checks; inspection
never adopts or overwrites a helper. \code{protected_sources} lists discovered
lifecycle-protected R files. Each operation includes specialization evidence,
configured helper/mapping/hooks and ownership separately.}
