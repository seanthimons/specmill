# Recreates the v0.1.0 to v0.2.3 version tags locally so autonewsmd can split
# NEWS.md by release. Those tag names can no longer be used on GitHub, so the
# release workflow runs this before NEWS generation and never pushes the tags.
# Run from the package root: Rscript dev/release_tags.R
local({
  tags <- utils::read.csv('dev/release_tags.csv', colClasses = 'character')
  existing <- system2('git', 'tag', stdout = TRUE)
  for (i in seq_len(nrow(tags))) {
    tag <- tags$tag[i]
    commit <- tags$commit[i]
    if (tag %in% existing) {
      at <- system2(
        'git',
        c('rev-parse', paste0(tag, '^{commit}')),
        stdout = TRUE
      )
      if (!identical(at, commit)) {
        stop(
          'Tag ',
          tag,
          ' points at ',
          at,
          ', expected ',
          commit,
          call. = FALSE
        )
      }
    } else if (system2('git', c('tag', tag, commit)) != 0L) {
      stop('Cannot tag ', tag, ' at ', commit, call. = FALSE)
    }
  }
})
