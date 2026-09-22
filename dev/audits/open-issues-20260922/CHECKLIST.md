# Open issue checklist

Live bodies and comments fetched 2026-09-22. Base commit `84125df`; branch `feat/resolve-open-issues`. #4 excluded; #29 remains unsupported. Latest #34 decisions supersede historical #32/#40 validation proposals.

| Issue | Acceptance and dependency | Status |
|---|---|---|
| #25 fix: generate scalar numeric fixtures within declared bounds | Verify existing numeric fixture tests; no duplicate implementation | Closed; existing implementation reverified |
| #26 docs: establish request media policies for 26 AMOS operations | 26 media dispositions; five independent upload defects | Blocked; individual dispositions verified, kept open |
| #27 docs: resolve AMOS parameter defects and latent upload contracts | Six visible and five masked defects; service-owned corrections required | Blocked; individual dispositions verified, kept open |
| #28 docs: resolve binary-query upload contracts for 18 operations | 18 binary query contracts, 11 overlaps with #31 | Blocked; individual dispositions verified, kept open |
| #30 feat: support finite recursive request payloads for ProtocolRecord | Verify existing finite recursion and four exact keys | Closed; existing implementation reverified |
| #31 feat: support explicitly reviewed nested query-object contracts | Two pageable encodings and 11 overlaps require authoritative evidence | Blocked; individual dispositions verified, kept open |
| #32 milestone: harden generated R clients and request contracts | Integrate #33–#40 and corpus comparison | Closed; corpus check 0 errors/warnings/notes, report complete |
| #33 fix: enforce consistent schema validation across request inputs | Public input validation parity before hooks and HTTP | Closed; acceptance verified |
| #34 docs: clarify client-owned pre-request hook responsibility | Client-owned transformations; preserve skip/state/order/exceptions | Closed; acceptance verified |
| #35 fix: diagnose contradictory parameter constraints at their source | Source-located contradictions; optional omission remains valid | Closed; acceptance verified |
| #36 fix: keep generated package file paths portable | Portable byte-limited filenames; stable ownership-preserving renames | Closed; acceptance verified |
| #37 fix: escape non-ASCII literals in generated R source | Escaped executable literals preserve Unicode bytes | Closed; acceptance verified |
| #38 fix: honor parameter examples and clarify optional fixture failures | Fixture precedence; explicit minimal mode; no invented defaults | Closed; acceptance verified |
| #39 feat: track request-helper provenance and offer reviewed upgrades | Read-only helper provenance/comparison and lifecycle protection | Closed; acceptance verified |
| #40 test: verify hardened generated clients with exact localhost requests | Installed exact-wire, auth/no-auth checks, rebuild and comparison | Closed; corpus check 0 errors/warnings/notes, report complete |
