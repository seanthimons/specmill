\name{configure_apis}
\alias{configure_apis}
\title{Review and save names and servers for multiple APIs}
\description{Discover local schemas and review API names, server URLs and inclusion in one table. Names are proposed from schema titles rather than filenames.}
\usage{configure_apis(root, schemas = NULL, origins = NULL, choices = NULL,
    review = NULL, mode = c("plan", "apply"))}
\arguments{
\item{root}{Existing project directory.}
\item{schemas}{Local schema paths inside root. Discovery includes JSON, YAML, GraphQL, protobuf, WSDL, RAML and API Blueprint extensions directly inside root, excluding specmill project and catalogue configuration files.}
\item{origins}{Optional character vector of download URLs, named by schema path relative to root. Used to resolve relative servers.}
\item{choices}{Optional data frame keyed by schema with api, base_url, include or format columns for scripted review. A format override is resolved before review; blank means automatic detection. Registered formats currently include openapi, swagger, arcgis-rest, and google-discovery. Local ArcGIS directory captures expand into service rows with source diagnostics for inaccessible or unsupported entries. Recognition of other formats reports an unimplemented importer.}
\item{review}{Open the table in R's data editor for one review of names, base URLs and include flags. Requires an interactive session. NULL opens the editor only for new or changed schemas in an interactive session; saved unchanged choices do not prompt again.}
\item{mode}{Plan returns the table without writing. Apply saves validated selections to specmill-apis.yml.}
}
\value{A data frame with schema, title, api, base_url, include, origin, hash, format, source_format, importer_version and status columns.}
\details{Saved selections are reused by schema path, or by canonical content hash after renaming a file. Equivalent JSON and YAML documents with reordered object keys have the same identity. New duplicate content is deselected; distinct schemas with duplicate titles receive hash suffixes for review. Ambiguous or missing servers require an explicit choice. Explicit format overrides are saved and copied into API configuration during initialization. The detected source format and importer version are recorded in the catalogue and generated ownership provenance. Third-party registration remains internal while the contract settles. This catalogue prepares multi-API setup; it does not itself generate wrappers or request helpers.}
