# Query credentials with a small maintenance surface

Research for [#264](https://github.com/seanthimons/specmill/issues/264), 2026-10-29.
Proposal only. No runtime or configuration changes are implemented.

## Recommendation

Settle credential ownership, collision handling, and diagnostic guarantees before
expanding authentication scaffolding. Do not make the whole #264 implementation
a prerequisite for [#251](https://github.com/seanthimons/specmill/issues/251).
HTTP query bindings are not a suitable foundation for SOAP or gRPC authentication.
The shared decisions are source lookup and sensitivity, not query serialization.

For AQS, first use the existing scheme mapping and reviewed operation corrections.
An offline synthetic client confirms that this can remove the duplicated key
argument without adding a setting. Keep email as an ordinary required argument
unless its independent environment-binding requirement is confirmed. This solves
the immediate duplication, but does not provide protected query printing.

Defer a general environment-binding policy until the AQS workflow demonstrates
that the existing configuration is too repetitive or cannot express a required
ordinary value. Do not ship an option called "protected" while returning an
ordinary credential-bearing httr2 request and promising safe downstream printing.

## What already works

The project configuration can map the declared scheme directly to the variable
the user already has. There is no need to copy `AQS_KEY` through another variable
or call `set_api_token()` after R has loaded it:

```yaml
# specmill.yml
authentication:
  aqs_api_auth: AQS_KEY
```

For each reviewed operation that requires that credential, the existing service
YAML can remove the redundant ordinary key argument and declare the effective
requirement. Replace the illustrative route with its exact schema route:

```yaml
operations:
  GET /reviewed-data-route:
    exclude_parameters: [key]
    security_correction:
      requirements:
      - aqs_api_auth: []
      reason: Reviewed endpoint requires the declared query API key.
```

Operations already declaring the correct requirement need only the exclusion.
Do not apply this to key-registration, public, or unrelated operations. Exclusions
are currently name-based across supported locations, so inspect same-name header
or cookie parameters before using them. Corrections and exclusions are deliberately
per operation; maintaining up to 13 reviewed corrections has a cost, but so does
introducing a second credential configuration system.

This is appropriate when a declared security scheme describes the real API
contract. It is not a way to label an email address as authentication, invent an
undeclared scheme, or remove a business parameter merely because it is named key.
The upstream schema stays unchanged. Reviewed YAML changes the generated public
signature, which needs a compatibility decision for an already-published client.

Local implementation evidence: `R/authentication.R`, `R/generation.R`,
`R/operations.R`, `inst/templates/authentication.R`, and the authentication and
parameter-exclusion sections of `vignettes/configuration.Rmd`. Upstream semantics
and diagnostic experiments are in [the source research](issue-264-upstream.md).

## If ordinary bindings are still needed

Keep the first version per operation and query-only. This makes the destination
explicit and avoids package-wide injection into unrelated APIs or public routes.
An illustrative, unimplemented shape is:

```yaml
operations:
  GET /reviewed-data-route:
    query_credentials:
      key: AQS_KEY
      email: AQS_EMAIL
```

Each selected existing scalar string query parameter has one environment source.
The map itself marks the values sensitive; no separate flag, file path, provider,
setter, or precedence switch is needed. Keep this independent of schema security.
Start without inherited defaults, selectors, or API-wide matching. Add shared
scope only after real configuration establishes that repetition is the problem.

The smallest proposed contract is:

- Remove bound values from the generated public signature. The environment is
  their only source, so there is no explicit-argument precedence to configure.
  Passing the removed named argument must fail; custom mappings need separate
  support or a generation-time rejection.
- Resolve on every call before required-value and schema validation. Do not read
  environment values during generation or store them in defaults or manifests.
- Required unset, empty, or whitespace-only values fail before HTTP. Optional
  unset or blank values are omitted, without falling back to schema defaults.
  Preserve nonblank values exactly; reject line breaks. These are proposed rules,
  not existing parameter behavior.
- Reject unknown names, unsupported shapes, renamed wire-identity confusion,
  and overlapping exclusions at generation time. Never infer from key/email names.
- Initially reject a binding overlapping any effective declared-auth destination.
  Tell the maintainer to choose the auth correction/exclusion path or the ordinary
  binding. This is simpler than merging OR/AND alternatives and comparing two
  credential sources. An operation may still use auth for other destinations.
- Emit exactly one value through the existing serializer. Preserve declaration
  provenance so ordinary bindings do not masquerade as schema security.

This deliberately gives up ad hoc per-call credential overrides. Multiple accounts
in one process would need a later reviewed design or a client-owned helper. That
is preferable to adding override modes before a concrete use case needs them.

## Protection is the expensive part

Installed httr2 1.3.0 prints query values in request URLs and verbose request lines.
Header redaction does not protect queries. httr2 error conditions can retain raw
requests and responses even when their messages look safe. See the reproducible
fake-secret probes and primary links in [the source research](issue-264-upstream.md).

specmill's normal verbose messages already omit query values. Its default helper
restricts transport/status error messages, but raw errors can be requested with
`preserve_errors`; response policies and custom hooks also receive sensitive data.
The current specmill dry run returns a real prepared httr2 request containing the
credential. Regeneration preserves client-owned request helpers, so template
changes alone cannot guarantee protection in existing clients.

Choose an honest boundary before implementation:

- Environment-backed injection can preserve today's dry-run API if the docs say
  that requests, responses, hooks, recordings, and raw errors remain sensitive.
  This does not satisfy #264's stronger dry-run/printing protection acceptance.
- To claim safe dry-run output, return an inert sanitized summary for sensitive
  requests. Do not disguise it as a sendable httr2 request. That is a deliberate
  behavior change requiring caller migration and tests, not a redaction flag.

A custom print method only conceals one presentation; it does not solve httr2
verbose output, direct URL access, serialization, or retained conditions. Do not
maintain a patched httr2 request class for an unbounded protection promise.
Query transport also remains visible to the receiving server and infrastructure.
Recordings and third-party loggers require their own explicit filtering policies.

## Environment files

Use the process environment only. R already handles `.Renviron` at startup, with
project-versus-home selection rules. Existing processes require a restart or an
explicit `readRenviron()` call after editing. `.env` is a separate application
workflow; do not add dotenv as an imported dependency or discover files on load.
The inspected dotenv source itself loads a current-directory `.env` on namespace
load. User-selected external loading must not become a generated-client promise.
See the official R startup links and dotenv source in the upstream findings.

## Sequencing and acceptance

1. Approve this boundary and prove the existing correction/exclusion path against
   the archived AQS schema. Review exactly which routes require key and email.
2. Decide whether safe dry-run summaries are required, including compatibility
   with current request inspection. Share that diagnostic decision with existing
   query authentication; fixing ordinary bindings alone leaves the same exposure.
3. If an ordinary binding remains necessary, implement one end-to-end scalar
   query case, with no security declaration, before adding shared configuration.
4. Continue transport-neutral auth separately, reusing credential-source and
   sensitivity concepts without making HTTP query policy its common interface.

Implementation acceptance must cover actual localhost wire values, required and
optional absence, environment changes between calls, overlap rejection, encoding,
fake-secret diagnostic surfaces, repeated generation, helper ownership/adoption,
and an installed generated client running without specmill. Also test interaction
with hooks, batching/pagination attribution, and custom request mappings rather
than assuming the ordinary helper path covers them. Shared generator/template
changes require the package check under repository rules.

## Validation performed

### AQS follow-up

The AQS client follow-up on branch `feature/issue-264-aqs-query-auth` reported
successful verification against its archived schema on 2026-10-29. All 76 data
wrappers use the existing mapping/exclusion path; 12 routes needed reviewed
security corrections. Email stayed an ordinary argument. The source schema and
client-owned request helper remained byte-for-byte unchanged. Fake-secret checks,
localhost encoding checks, environment-file startup and explicit reading,
runtime independence, repeat generation, setup, and the generated package check
passed. No new specmill setting or live EPA request was needed. Evidence source:
[Update Specmill and Rebuild Client](t3-thread://v1/78de0469-dc82-4bd3-8998-b409df133c6f).

This satisfies the duplicate-key workflow and supports documenting the existing
recipe. It does not satisfy the stronger protection criteria of #264. Keep these
follow-ups in planning:

- Query diagnostic protection needs an explicit decision about sanitized dry-run
  summaries, raw errors, recordings, and migration for existing helpers. Apply
  any eventual guarantee to declared query authentication too. Ordinary bindings
  remain deferred unless another real case cannot use existing auth policy.
- The intentionally public status route still triggers the missing-security
  warning. Investigate whether an existing explicit empty security correction
  records the reviewed public contract and removes the warning before proposing
  another suppression option. Preserve warnings for genuinely unreviewed gaps.
- Registration retains a questionable upstream authentication requirement.
  Establish the authoritative contract before correcting it; do not infer that
  registration is public merely from its purpose. Keep this client-specific.

### Initial synthetic probe

The source research inspected primary documentation and installed httr2 code and
ran fake-secret local echo and mocked-error probes. A separate synthetic OpenAPI
3.0.3 client was generated with installed specmill 0.1.60. It had required key and
email query parameters, a declared query API-key scheme, and no operation security.
With the existing mapping, correction, and exclusion, assertions passed for:

- A key-free wrapper signature while email remains required.
- Exactly one key in the prepared request URL.
- A changed environment value appearing on the next call.
- An absent credential failing during dry run before any HTTP.

Local reproduction and output are `artifacts/issue-264/probe.R` and `probe.log`.
Those ignored artifacts are investigative evidence, not committed regression tests.
The probe used the installed package, not a fresh checkout installation. No real
AQS schema or live service was verified. No claim of complete AQS coverage follows.
No package suite or full check ran because only research Markdown changed.
