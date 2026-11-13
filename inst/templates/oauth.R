# Appended to R/api_auth.R when a credential uses OAuth.
#' Sign in with OAuth 2.0
#'
#' Opens the provider's sign-in page in a browser and completes an
#' authorization-code login with PKCE through a local loopback listener.
#' @param credential OAuth credential name; optional when only one is configured.
#' @param origin Optional HTTP(S) origin, such as an institutional proxy, that
#'   may also receive the token. Tokens are otherwise sent only to the origins
#'   of the servers the credential's operations call.
#' @return Invisibly TRUE.
#' @details Needs an interactive session and the httpuv package (httr2 runs
#'   the loopback listener with it). The client ID
#'   is read from the configured environment variable; no client secret is
#'   used. The token is kept for this session and in a per-user cache file
#'   (mode 0600) under `tools::R_user_dir()`, and is refreshed when it expires.
#'   `api_logout()` removes it. Tokens are never printed or returned.
#' @export
api_login <- function(credential = NULL, origin = NULL) {
  setting <- api_oauth_setting(credential)
  client_id <- Sys.getenv(setting$client_id, unset = '')
  if (!nzchar(trimws(client_id))) {
    api_oauth_stop('Set ', setting$client_id, ' to the OAuth client ID')
  }
  origins <- unlist(setting$origins)
  if (!is.null(origin)) {
    if (
      !is.character(origin) ||
        length(origin) != 1L ||
        is.na(origin) ||
        !grepl('^https?://[^/?#@]+/?$', origin)
    ) {
      api_oauth_stop(
        'origin must be an HTTP(S) origin such as https://example.org'
      )
    }
    origin <- sub('/$', '', origin)
    origins <- unique(c(origins, origin))
  }
  if (!length(origins)) {
    api_oauth_stop(
      'No server origin is known for ',
      setting$credential,
      '; supply origin'
    )
  }
  endpoints <- list(
    auth_url = setting$auth_url,
    token_url = setting$token_url,
    auth_params = list()
  )
  if (!is.null(setting$discovery)) {
    discover <- get(
      setting$discovery,
      mode = 'function',
      envir = topenv(environment(api_login))
    )
    # Client-owned: returns any of auth_url, token_url and auth_params.
    found <- discover(
      setting$credential,
      endpoints,
      if (is.null(origin)) origins[[1L]] else origin
    )
    if (
      !is.list(found) ||
        length(setdiff(names(found), c('auth_url', 'token_url', 'auth_params')))
    ) {
      api_oauth_stop(
        'Discovery must return a list of auth_url, token_url and auth_params'
      )
    }
    endpoints[names(found)] <- found
  }
  api_oauth_url(endpoints$auth_url, 'authorization URL')
  api_oauth_url(endpoints$token_url, 'token URL')
  client <- httr2::oauth_client(
    id = client_id,
    token_url = endpoints$token_url,
    auth = 'body'
  )
  scopes <- unlist(setting$scopes)
  token <- httr2::oauth_flow_auth_code(
    client,
    auth_url = endpoints$auth_url,
    scope = if (length(scopes)) paste(scopes, collapse = ' '),
    pkce = TRUE,
    auth_params = as.list(endpoints$auth_params),
    redirect_uri = setting$redirect_uri
  )
  api_oauth_write(
    setting$credential,
    list(
      token = token,
      token_url = endpoints$token_url,
      client_id = setting$client_id,
      scopes = scopes,
      origins = origins
    )
  )
  invisible(TRUE)
}

#' Sign out of OAuth
#' @param credential OAuth credential name; optional when only one is configured.
#' @return Invisibly NULL. Removes the stored token from this session and the
#'   per-user cache. Does not revoke it or end the provider's browser session.
#' @export
api_logout <- function(credential = NULL) {
  setting <- api_oauth_setting(credential)
  api_oauth_forget(setting$credential)
  invisible(NULL)
}
