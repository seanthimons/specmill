function_name_styles_acceptance <- function() {
  schema <- tempfile(fileext = '.json')
  root <- tempfile('function-name-styles-')
  on.exit(unlink(c(schema, root), recursive = TRUE), add = TRUE)
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Naming styles', version = '1'),
      paths = list(
        '/pets/{petId}' = list(
          get = list(
            operationId = 'getPetById',
            parameters = list(list(
              name = 'petId',
              `in` = 'path',
              required = TRUE,
              schema = list(type = 'integer')
            )),
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    ),
    schema,
    auto_unbox = TRUE
  )

  plan <- specmill::configure_client(
    root,
    schema,
    package = 'namingstyles',
    naming = 'operation_id',
    name_case = 'snake_case'
  )

  stopifnot(
    !dir.exists(root),
    identical(plan$operations[[1L]]$name, 'get_pet_by_id')
  )

  camel <- specmill::configure_client(
    root,
    schema,
    package = 'namingstyles',
    name_case = 'camel_case'
  )
  stopifnot(identical(camel$operations[[1L]]$name, 'getPetById'))

  pascal <- specmill::configure_client(
    root,
    schema,
    package = 'namingstyles',
    name_case = 'pascal_case'
  )
  stopifnot(identical(pascal$operations[[1L]]$name, 'GetPetById'))

  screaming <- specmill::configure_client(
    root,
    schema,
    package = 'namingstyles',
    name_case = 'screaming_snake_case'
  )
  stopifnot(identical(screaming$operations[[1L]]$name, 'GET_PET_BY_ID'))

  dotted <- specmill::configure_client(
    root,
    schema,
    package = 'namingstyles',
    name_case = 'dot_case'
  )
  stopifnot(identical(dotted$operations[[1L]]$name, 'get.pet.by.id'))

  multi_root <- tempfile('function-name-multi-')
  dir.create(multi_root)
  on.exit(unlink(multi_root, recursive = TRUE), add = TRUE)
  file.copy(schema, file.path(multi_root, 'pets.json'))
  multi <- specmill::configure_client(
    multi_root,
    data.frame(
      schema = 'pets.json',
      api = 'catalogue',
      base_url = 'https://example.invalid',
      include = TRUE
    ),
    package = 'namingstyles',
    name_case = 'camel_case'
  )
  stopifnot(identical(multi$operations[[1L]]$name, 'catalogueGetPetById'))

  specmill::initialize_client(
    root,
    schema,
    package = 'namingstyles',
    title = 'Naming Styles',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'https://example.invalid',
    name_case = 'dot_case'
  )
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      full.names = TRUE,
      all.files = TRUE
    ))
  }
  before <- hashes()
  dry_run <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'plan'
  )
  stopifnot(
    identical(before, hashes()),
    identical(dry_run$operations[[1L]]$name, 'get.pet.by.id')
  )
  specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )

  build_dir <- tempfile('function-name-build-')
  dir.create(build_dir)
  on.exit(unlink(build_dir, recursive = TRUE), add = TRUE)
  build <- local({
    old <- setwd(build_dir)
    on.exit(setwd(old))
    system2(
      file.path(R.home('bin'), 'R'),
      c('CMD', 'build', '--no-manual', '--no-build-vignettes', root),
      stdout = TRUE,
      stderr = TRUE,
      env = 'R_TESTS='
    )
  })
  if (!is.null(attr(build, 'status'))) {
    stop(paste(build, collapse = '\n'))
  }
  cat(
    'Function name styles: dry-run casing, multi-API prefixes and R package build passed.\n'
  )
}

if (sys.nframe() == 0L) {
  function_name_styles_acceptance()
}
