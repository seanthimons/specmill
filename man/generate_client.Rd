\name{generate_client}
\alias{generate_client}
\alias{print.specmill_generation}
\title{Plan, generate, and check client output}
\description{Generate wrappers, documentation, and supplied fixed contract tests from YAML or a legacy R-list specification.}
\usage{
generate_client(root, spec = NULL, mode = c("check", "plan", "apply"),
    config = NULL, callbacks = new.env(parent = emptyenv()),
    adopt = list(), artifacts = c("wrappers", "tests", "documentation"))
\method{print}{specmill_generation}(x, ...)
}
\arguments{
\item{root}{Explicit existing client root directory.}
\item{x}{A generation result.}
\item{...}{Unused additional print arguments.}
\item{spec}{Client specification with files, helper, optional hooks and renderer.}
\item{mode}{Check or plan without writes; apply validated output.}
\item{config}{Project YAML path relative to root, or client hook configuration for hook validation.}
\item{callbacks}{Explicit environment containing named development callbacks.}
\item{adopt}{Reviewed legacy files as a named list of relative paths and SHA-256 hashes of UTF-8/LF text without a final newline. Changed hashes fail; lifecycle and mixed-file protection still apply.}
\item{artifacts}{Output kinds to reconcile. Defaults to all; thin wrapper/test commands can select their own artifacts while retaining one generation contract.}
}
\value{A list of class \code{specmill_generation} with files (file/path/action records), configured operations, excluded operations with reasons, drift, diagnostics, server_diagnostics, mapping_diagnostics, retained_diagnostics, unused_hooks, inventory, retained_sources, and manifest (toolkit version, input hashes, policy versions). Printing separates selected and excluded operations and reports removals and protections. Operations outside a service's include list remain in inventory but are omitted from the excluded summary to avoid repeating other services' endpoints. File actions include write, unchanged, protected, remove, and retained. Check errors on actions other than unchanged or retained.}
\details{Supply exactly one of spec and config. Check is the default and errors when reconciled output is stale or protected; plan returns file actions without modifying the client; apply reconciles verified owned output. Both read-only modes stage candidate output. Development callbacks must be deterministic and are resolved only in callbacks. Unsupported operations remain diagnostics and never authorize removal. Check success does not establish complete schema support or passing tests. Adoption accepts only individually reviewed current hashes and does not override lifecycle or mixed-file protection.}
\section{Portable generated output}{
Generated R, Rd and contract-test filenames are limited to 100 bytes including the
package archive prefix. Long stems receive a deterministic 16-digit SHA-256
suffix. Public function names and help aliases stay unchanged. Short explicit
API names or output filenames remain supported. A package name too long to leave
space for a filename fails with a diagnostic.

Existing generated files move only when their manifest hashes still match;
client edits and protected lifecycle badges block a move. Repeated generation
uses the same filenames. Unicode in executable schema literals uses R escapes
that preserve the original runtime strings; documentation text remains UTF-8.
}
\seealso{\href{https://seanthimons.github.io/specmill/articles/maintenance.html}{Step-by-step guide}.}
