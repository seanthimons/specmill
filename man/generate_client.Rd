\name{generate_client}
\alias{generate_client}
\alias{print.specmill_generation}
\title{Plan, generate, and check client output}
\description{Generate wrappers, documentation, and supplied fixed contract tests from YAML or a legacy R-list specification.}
\usage{
generate_client(root, spec = NULL, mode = c("check", "plan", "apply"),
    config = NULL, callbacks = new.env(parent = emptyenv()),
    adopt = list(), artifacts = c("wrappers", "tests", "documentation"),
    validation = NULL,
    deferrals = NULL, prune = NULL, confirm = NULL)
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
\item{deferrals}{Optional list with \code{enroll} (a named character vector of one-line reasons keyed by operation identity, \verb{<service id> <METHOD> <path>}) and \code{clear} (operation identities to retry). Enrollment is recorded on apply only; plan and check never write it. See the maintenance vignette.}
\item{prune}{Optional, opt-in removal of owned output; the default preserves it. Operation identities (\verb{<service id> <METHOD> <path>}) remove that operation's R file, tests and help page, regenerate \code{NAMESPACE} when documentation is generated, and drop its ownership records; the identity may name a service since removed from the configuration, and an enrolled deferral identity also matches the retired owner of the same route. An operation that is still generated, owns no output, or shares a file with other operations is refused. \code{"all"} removes every manifest-owned, unmodified output after an \verb{Are you sure? [y/N]} prompt. Edited and unowned files are never deleted. Plan and check never write. See the maintenance vignette.}
\item{confirm}{Only for \code{prune = "all"}: \code{TRUE} skips the prompt (needed in non-interactive sessions), \code{FALSE} cancels, \code{NULL} (default) asks interactively and aborts when not interactive.}

\item{validation}{\code{TRUE} or \code{FALSE}. By default, use project YAML or legacy specification \code{validation}, falling back to required validation. \code{FALSE} explicitly skips validation and is recorded in the result.}
}
\value{A list of class \code{specmill_generation} with files (file/path/action records), schema_changes (changed source hashes, added endpoints, unselected additions, removed endpoints and their previous configured functions), configured operations, excluded operations with reasons, drift, diagnostics, server_diagnostics, mapping_diagnostics, retained_diagnostics, unused_hooks, inventory, retained_sources, and manifest (toolkit version, input hashes, policy versions). Printing separates selected and excluded operations and reports removals and protections. Operations outside a service's include list remain in inventory but are omitted from the excluded summary to avoid repeating other services' endpoints. File actions include write, unchanged, protected, remove, and retained. Check errors on actions other than unchanged or retained.}
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
\section{Required schema validation}{
Check mode warns before translation when a current schema differs from the last
applied manifest's input hash. The warning identifies the schema and previous
and current SHA-256 hashes. When an endpoint inventory is recorded, it lists added
and removed method/path pairs, additions outside current selection policy, and
previous configured function names affected by removals. The same report is
available in \code{schema_changes} and printed with a plan. Parameter and response
compatibility are not inferred. Removed endpoints do not authorize deleting functions.
Newly referenced schemas report an unrecorded previous
hash. First generation and manifests without input hashes have no comparison
baseline. Check never rebuilds functions; review plan file actions before apply.
Successful application records the new baseline. Hash changes need not change
generated functions. These warnings require calling the generation check and
are not automatically attached to package build or check commands.

The manifest stores the endpoint inventory and configured function names with
its existing hashes. Older manifests need a reviewed apply to record this
inventory. Until then, a changed schema reports that endpoint comparison is
unavailable. Schema files removed from configuration or renamed are not paired
automatically. Check and plan never update this baseline.

Every source schema is checked with \code{\link{validate_schema}} before
operation translation. Validation runs locally and uploads nothing.
Plans expose reports in \code{validation} and blockers in existing diagnostics;
apply and check refuse validation blockers. Located errors block affected
operations. Shared or unlocated errors and unsupported coverage
block the source document, even when its operations were policy-excluded.
Explicit request mappings and retained implementations cannot bypass this gate.

Plans and checks do not write client output. Schemas with external references
must be bundled first. An explicit
\code{validation = FALSE} is an auditable escape for reviewed legacy workflows,
not a declaration that the schema is compliant.
}
\seealso{\href{https://seanthimons.github.io/specmill/articles/maintenance.html}{Step-by-step guide}.}
