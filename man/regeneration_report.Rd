\name{regeneration_report}
\alias{regeneration_report}
\title{Review what a clean regeneration would add, change or remove}
\description{Plan generation in memory and compare it with the checked-in tree, the ownership manifest and unowned files, without writing anything.}
\usage{
regeneration_report(root, config = "specmill.yml", callbacks = new.env(parent = emptyenv()), validation = NULL)
}
\arguments{
\item{root}{Explicit existing client root directory.}
\item{config}{Project YAML path relative to root.}
\item{callbacks}{Explicit environment containing named development callbacks.}
\item{validation}{Passed to \code{generate_client()}; \code{NULL} keeps its default.}
}
\value{A \code{specmill_regeneration_report} whose \code{files} data frame has columns \code{file}, \code{category}, \code{reason}, \code{prune_eligible} and \code{owner}. Categories: \code{added}, \code{changed}, \code{unchanged}, \code{edited_conflict} and \code{unowned_collision} (a hand-written file at a generated path), \code{kept} (lifecycle badge, existing implementation, deferral or \file{NAMESPACE}), \code{would_remove} (owned but no longer generated; \code{prune_eligible} is \code{FALSE} when \code{prune} would refuse an edited file), \code{unowned_generated} and \code{hand_written}.}
\details{Nothing is written to the working tree or manifest. The comparison is the in-memory plan against the current disk, not a purge followed by a rebuild: deferrals, existing implementations, adopted hashes and lifecycle badges keep their current placement, and the plan reads current sources. Plan mode still stops on an unresolved recovery journal, a blocked rename, or a hand-edited file that mixes other code into a generated file; the error names the file.}
\seealso{\code{\link{generate_client}}, \code{\link{inspect_client}}.}
