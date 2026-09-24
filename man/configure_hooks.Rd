\name{configure_hooks}
\alias{configure_hooks}
\title{Scaffold a client-owned runtime hook executor}
\description{Preview or create an optional YAML hook registry and base R executor in an existing client package. Specmill remains a development dependency.}
\usage{configure_hooks(root, mode = c("plan", "apply"))}
\arguments{
\item{root}{Existing client package directory containing DESCRIPTION.}
\item{mode}{Preview by default; apply creates absent files only.}
}
\value{A list containing proposed text in files, changes with file/action/before/after, missing_imports, and collisions with existing executor definitions.}
\details{Creates R/hook_registry.R and inst/hooks.yml. Add yaml to the client's DESCRIPTION Imports before applying. This function does not modify metadata or service configuration. Set hook_config: inst/hooks.yml in each participating service or API group, and define the referenced functions in client R source. The empty registry enables no hooks.

Existing differing files and executor definitions in other R files block application. Matching files are left alone. Ordinary generate_client regeneration preserves these client-owned files. Rerunning this setup command is not a runtime upgrade mechanism.

The executor reads the installed hooks.yml on each stage, resolves functions only in its own environment, executes chains in order, and reports failures with class client_hook_error and parent, function_name, hook_name and stage fields. Pre-hooks return state; the last post-hook returns the wrapper result. An absent chain returns pre-state or data$result for a post-stage. YAML expression evaluation is disabled. No specmill runtime dependency or global registration API is introduced.}
\seealso{\code{initialize_client}, \code{generate_client}, \code{check_client_hooks}, \href{https://seanthimons.github.io/specmill/articles/hooks.html}{Configure and maintain runtime hooks}}
\examples{
\dontrun{
proposal <- configure_hooks('path/to/client')
proposal$changes
proposal$missing_imports
# Add yaml to DESCRIPTION Imports, then:
configure_hooks('path/to/client', mode = 'apply')
}
}
