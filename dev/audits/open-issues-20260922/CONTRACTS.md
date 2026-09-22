# Contract dispositions for #26, #27, #28 and #31

Reviewed 2026-09-22. The [individual ledger](contract-dispositions.csv) records
68 issue/defect rows covering 52 distinct schema/method/path keys. All 52 remain
blocked against the archived proving-ground inputs. Keep these four issues open.
No source snapshot, client policy or transport was changed for this review.

| Issue | Verified scope | Remaining dependency |
| --- | --- | --- |
| #26 | 26 AMOS operations without usable consumes declarations | Service-owned media and body representation for each archived operation |
| #27 | Six visible AMOS defects and five masked nested-file defects | Corrected query types/encoding, path names, and upload representation |
| #28 | 18 binary-query operations | Confirm each file representation, location, media, and relationship to metadata |
| #31 | 13 nested-query operations | Confirm nested query field names and exact encoding, including array-valued members |

Five #27 upload rows also appear in #26. Eleven #31 rows also appear in #28.
These overlaps represent independent blockers and cannot be counted as unlocks.
The two standalone #31 keys remain GET and POST `/api/stdizer/protocols/{id}`.

## Evidence and limits

The audit reads the seven relevant immutable baseline schema files under
`artifacts/proving-ground-20260921T213801Z/inputs/specmill-testing/schema`.
Each SHA-256 must match the historical
[proving-ground ledger](../proving-ground/schemas.csv). Parser diagnostics and
source pointers are recorded individually. Query parameters are checked
independently so a binary diagnostic cannot conceal the nested-object blocker.
AMOS body schemas are resolved independently of media selection to expose all
five invalid nested `file` properties. This inspection neither chooses media nor
modifies a schema.

The existing [AMOS review](../source-contracts/AMOS.md) documents upload and query
contradictions. The two path defects add separate dependencies: similar-structures
must declare the actual `identifier_type` and `identifier` placeholders, and
list-sources must declare `record_type`. A corrected parameter name alone would
not establish its supported values or service semantics.

The [Swagger 2 parameter rules](https://spec.openapis.org/oas/v2.0.html#parameter-object)
restrict file parameters to form data. They do not establish the intended upload
representation for nested file properties. The
[OpenAPI 3.1.1 parameter rules](https://spec.openapis.org/oas/v3.1.1.html#parameter-object)
do not define arbitrary nested array/object serialization through `deepObject`.
Neither a request type named Multipart nor a Spring Pageable convention is
service evidence. These primary references were checked during this review.

The existing query review's 2026-09-21 development Standardizer schema inspection
found unchanged Pageable parameters and no encoding declaration. Its
[review notes](../source-contracts/QUERY-CONTRACTS.md) remain user-owned input and
were not rewritten. No new controller, corrected schema, or independently
verified replacement wire contract was available in the reviewed artifacts.
The prior unsuccessful searches are historical evidence, not a claim that no
such contract can exist.

## Scoped AMOS development evidence

The [recorded pagination check](../pagination/amos-development.json) establishes
one filtered JSON POST to `/api/amos/method_keyset_pagination/{limit}` on
`cim-dev.sciencedataexperts.com`, using development schema SHA-256
`11bbfa8b6fcf943db4ea17c8d9b4a8ef9696064abc3d92fc0065c6d8ec2cd6a4`.
The [verification script](../../verify_amos_pagination.R) reads that environment's
schema before constructing the generated request. This is useful evidence for
that development operation and its tested input, and remains recorded separately.

The archived AMOS source is SHA-256
`0d63f7c24e6918cd1dbefa9016fd20972285118c0992434d82b0318dc80b9772`.
The development observation does not confirm that archived production contract,
other AMOS POST operations, or any upload representation. Promoting that choice
requires an explicit environment/source association and the corresponding
per-operation client policy. No baseline override is inferred here.

## Reproduce and next action

Install the branch and run `Rscript dev/verify_open_contracts.R` from the repository
root. An optional first argument selects a schema directory. If the baseline
artifact is absent, the script extracts the transfer ZIP into a temporary
directory, verifies the same source hashes, and writes only this new ledger.
It asserts 26 media rows, six visible and five masked AMOS defects, 18 binary
rows, 13 nested rows, eleven overlaps, and 52 distinct blocked operations.

For a future correction, attach the service-owned contract to its exact ledger
key, preserve the archived bytes, and use existing per-operation media policy or
client mappings/hooks where sufficient. Assert exact localhost content type,
path/query and body bytes before counting an operation as supported. Recheck its
independent blockers. No live operation was called in this review; request
construction would not establish live compatibility.
