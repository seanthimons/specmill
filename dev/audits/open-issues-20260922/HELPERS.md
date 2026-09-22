# Client-owned helpers and specialized implementations

Initialization records the exact substituted helper baseline and template hash
under `.specmill/helpers/`. `inspect_client(root)$helpers` returns baseline, local,
and proposed current text for comparison. URLs, initialization overrides, dry-run
environment names and per-API helper names are substituted before comparison.
Unknown legacy or independently authored helpers stay unknown. Comparison does not
write any file, and ordinary generation does not refresh helpers.

Review `comparison$baseline` against `comparison$proposed` for upstream changes,
and `comparison$baseline` against `comparison$local` for client changes. Manually
merge selected changes into the client helper. Run relevant request, response,
authentication and transport checks. Repeated inspection is read-only; accepting
`...` does not establish support for timeout, retry, authentication or other
controls. The report lists missing explicit arguments and labels behavior unverified.

For example, a client's newline-delimited text handling must survive adoption of
the template's authentication lookup fix. The fixed template reports missing auth
scaffolding clearly and avoids the undefined `api_auth` package-check NOTE in
anonymous clients. Tests compare the actual earlier direct-call implementation
with this proposal, retain local source, then check manually adopted behavior.

Operation settings accept a `specialization` explanation for quirks the schema
cannot express. `inspect_client()` reports that explanation with configured
helper, request mapping, hooks and generated/retained ownership. Configured
handling is not evidence of tested behavior. Parser diagnostics remain independent.
A retained wrapper can use the existing complete public-input/request contract:

```yaml
names:
  POST /search: search_exact
operations:
  POST /search:
    specialization: Service expects newline-delimited exact-search terms.
    helper: search_request
    implementation: existing
    inputs:
      terms:
        type: character
        required: true
    request:
      arguments:
        body: {from: [params, terms]}
```

Use the actual helper and mapping required by the client, and retain public
formals including order/defaults. See `vignettes/existing-clients.Rmd` for the
complete existing-implementation configuration. Hooks own their transformations
and validation; these notes add no outgoing-contract requirement.

Existing lifecycle badges protect their containing source file, including stable,
maturing, superseded, deprecated and defunct states. Independent outputs may still
proceed. No second source marker or YAML protection list is needed. Ownership/hash
checks still reject unmarked customized output, and inseparable grouped-source or
rename conflicts still stop generation. A badge protects source, not correctness.
