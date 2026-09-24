# Build and release workflows

The R CMD check caller runs on main pushes, pull requests, and manual dispatch.
It checks Windows and Linux with Air installed. The pkgdown caller builds the
site on pull requests and deploys after main pushes or published releases.

Shared checks use caller stubs from [baseline v1.0.0](https://github.com/seanthimons/baseline/tree/0a2a80a6d045ffbdacedd59e35dce1497e2acfc1), pinned to that full commit:

- `gitleaks.yaml`: full-history scans on main pushes, main pull requests, manual runs, and Mondays at 06:43 UTC. The default-rule `.gitleaks.toml` is copied from baseline; the existing narrow `.gitleaksignore` stays in use.
- `commit-lint.yaml`: commit subjects, PR titles, and branch names on all pull requests.
- `lint-workflows.yaml`: actionlint and zizmor on workflow changes.
- `r-cmd-check.yaml`: automatic and manual Windows/Linux package checks.
- `pkgdown.yaml`: site build on pull requests, Pages deployment on main and release events.
- `release-r-package.yaml`: manual release build, check, and publication.
- `.github/dependabot.yml`: weekly grouped action updates after a seven-day cooldown.

Before the pkgdown caller can deploy, set Settings > Pages > Source to GitHub
Actions. The repository still uses the legacy `gh-pages` source until the
caller is merged. The release caller requires a `RELEASE_PAT` repository secret
with Contents read/write permission on specmill. Its account must be able to
push to main. No release run can succeed until that secret is added.

The shared release job builds one archive from a Git snapshot, checks that
archive, and verifies `SHA256SUMS` before publication. The old local
`dev/build_release.R` helper remains available for builds that need
`release.json` provenance; the shared release does not publish that file.

A clean toolkit check does not certify generated-client archives. The fresh-client
regression runs in the toolkit suite, but release certification must also build
and check generated clients. The documentation-fix certification and its five
client checks are retained under `artifacts/release-candidate-docs-20260924/`.

## Test a build

Run **Release** in GitHub Actions, select a version bump, and leave dry-run
enabled. Download the source artifact from the run. Dry runs do not push
commits, create remote tags, or publish releases. The repository secret is
still required for checkout.

For the same check locally, commit source changes first, then run from the repo:

```r
source('dev/build_release.R')
build_release(output = 'artifacts/my-build')
```

Use a fresh output directory for each run. The helper is development tooling and
requires pkgbuild and rcmdcheck in addition to specmill's package dependencies.

The release workflow uses autonewsmd and Quarto, then runs
`Rscript dev/build_news.R` to format `NEWS.md` from Conventional Commits and
version tags using [autonewsmd](https://github.com/kapsner/autonewsmd).
It includes NEWS in the release commit before building the checked archive.
You can run the same script locally
to refresh NEWS; untagged commits appear under the development heading.
The script normalizes autonewsmd headings for the pkgdown changelog page.
GitHub release descriptions use the generated NEWS section.

## Corpus diagnostics

`audit_testing_specs()` writes `DIAGNOSTICS.md` alongside its CSV results when
`report = TRUE`, including native runs. The report identifies blocked operations,
source locations, guidance, and document failures. Missing request media requires
contract review; invalid declarations require corrected upstream schemas. Neither
is repaired automatically. Counts reflect the first parser blocker per operation,
so resolving media alone does not establish a valid upload contract.

AMOS issues #26 and #27 remain open pending authoritative contracts. They do not
justify schema coercion or guessed request encodings. Existing generation previews
also print diagnostic classifications, source locations, and guidance.

Check reporting offline with `Rscript dev/check_testing_report.R`.

## Publish

Run the workflow on main, choose patch/minor/major/dev, and disable dry-run.
An existing tag blocks publication. The workflow commits the version and NEWS
locally before building, then pushes main and the new version tag atomically
only after the archive passes checks. A concurrent main change causes the normal Git push
to fail; no force push is used. Branch protection still applies.

All assets are attached to a draft before publication because releases become
[immutable](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository).
A failed upload leaves a draft for inspection. Do not retag or replace a published
archive; use a new version for corrections. The `RELEASE_PAT` push triggers the
automatic package check and documentation workflows.

Specmill has manually maintained help pages. Automatic roxygen regeneration,
rolling releases, and ComptoxR's database/schema schedules remain excluded.

## Try a different schema

For the full 19-endpoint configuration demonstration, including pet/store/user
names, parameter renaming, grouped source and help, explicit mappings, and
retained client functions, see [petstore/README.md](petstore/README.md).
Run source('dev/build_petstore.R') and build_petstore() for that example.
The three-operation smoke trial below remains a smaller separate example.

The Petstore trial downloads the [live service's schema](https://petstore3.swagger.io/api/v3/openapi.json),
records its retrieval time and checksum, and builds a client for three GET operations:
findPetsByStatus, getPetById, and getInventory. It supplies independent offline
contracts, verifies an unchanged second generation, checks the archive, and
installs it into a separate library. The installed functions then retrieve real
data and compare their results with direct HTTP requests to the same endpoints.

```r
source('dev/try_petstore.R')
try_petstore(output = 'artifacts/petstore-live')
```

The output contains the schema and its provenance, generated petstoretrial
package, selected and full-schema generation plans, installable source archive,
check logs, live-responses.rds, and result.json. Unsupported operations remain
visible in full-schema-plan.rds; this is a three-operation client, not full API coverage.
Package checks use offline fixtures; the subsequent live check requires internet
access and can fail if the shared demo data changes between requests. It checks
selected fields and exact response equivalence, not every OpenAPI constraint.
Records violating the checked Pet fields are reported in live.schema_invalid_pet_ids;
the live demo can return data that violates its own schema. Those findings are
separate from the assertions that the client returns the same data as direct HTTP.
No live write operations are performed.

To use the built client in a new R session from the repository root:

```r
library(petstoretrial, lib.loc = 'artifacts/petstore-live/library')
pets <- findPetsByStatus('available')
getPetById(pets[[1]]$id)
getInventory()
```

To repeat just the live check after loading the client, source dev/try_petstore.R
and call check_live_petstore(). The archived schema is the exact downloaded JSON;
the old illustrative /v1/pets schema is no longer used.
