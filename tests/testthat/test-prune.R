test_that('prune removes retired generated files and keeps owned ones', {
  prune_acceptance()
  prune_retired_service_acceptance()
  prune_documentation_acceptance()
  prune_path_acceptance()
  succeed()
})
