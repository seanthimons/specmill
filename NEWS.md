


## specmill 0.1.6 (2026-09-25)

#### Bug fixes

- keep manifest-owned stable wrappers generated
  ([f3fca33](https://github.com/seanthimons/specmill/tree/f3fca3340c9ed063302320f99ec4d2e30d4bab7b))

#### Other changes

- release v0.1.6 \[skip ci\]
  ([7ad3149](https://github.com/seanthimons/specmill/tree/7ad3149d8848c973d0a124abe466acc53696482d))

Full set of changes:
[`v0.1.5...v0.1.6`](https://github.com/seanthimons/specmill/compare/v0.1.5...v0.1.6)

## specmill 0.1.5 (2026-09-25)

#### New features

- scaffold client-owned hooks and document their lifecycle
  ([a25bfdd](https://github.com/seanthimons/specmill/tree/a25bfddfd65f9eaee295b02ff34bbed0636a924c))
- add package-prefixed client session controls
  ([5909653](https://github.com/seanthimons/specmill/tree/5909653596b7fd1039b8568249fc82ae3437f719))
- compare client-owned helpers and retain lifecycle-protected files
  ([2a9720a](https://github.com/seanthimons/specmill/tree/2a9720a1e459c7965cf4e00e0539017e440b5fd8))
- add configurable function name casing
  ([c11f0e1](https://github.com/seanthimons/specmill/tree/c11f0e100a996f920108581fab05ab6900f9459e))
- support finite recursive bodies and refresh schema fixtures
  ([c30e66f](https://github.com/seanthimons/specmill/tree/c30e66ff56b06a867d6a9374e1b1a4841cca0657))
- add bounded cursor and link pagination
  ([fac8098](https://github.com/seanthimons/specmill/tree/fac80985fcf330fddf0ca2644749ffc2ca49e39c))
- expose request timeouts servers and safe retries
  ([d879f59](https://github.com/seanthimons/specmill/tree/d879f59477cf2ccbdc49f236673af0fd6d22ab90))
- harden generated request runtime
  ([ed17d1e](https://github.com/seanthimons/specmill/tree/ed17d1e74b5742897368159f8985971490cc3c81))
- add generic batched helper (#19)
  ([5ea0884](https://github.com/seanthimons/specmill/tree/5ea08841f0fc9eb767e2dc187c0356e21cc7b4d4))
- validate composed JSON request bodies (#12)
  ([c13e865](https://github.com/seanthimons/specmill/tree/c13e865219955b96716ba2eab6aa2f847df15461))
- add explicit bracketed query array serialization
  ([8d47aa6](https://github.com/seanthimons/specmill/tree/8d47aa698b866fbd9d51b854d5deb4587a7e5142))
- resolve local schema references and support form requests (#9)
  ([e9be960](https://github.com/seanthimons/specmill/tree/e9be960621e2b0d1d69fca68841c3b87b0b75351))
- load JSON and YAML API schemas natively (#18)
  ([bfb62ce](https://github.com/seanthimons/specmill/tree/bfb62cedcdec17f1dd60d1bb0e6d5202ab9eab49))
- extend OpenAPI parameter serialization (#8)
  ([c50f5ea](https://github.com/seanthimons/specmill/tree/c50f5ea8b1ad71c788a3b9215d0d6a46512e872e))
- support open JSON objects and unconstrained arrays (#14)
  ([13f07bf](https://github.com/seanthimons/specmill/tree/13f07bf961f3dc14f2dd0dafa095e8d649fb0853))
- group multi-API configuration into one file per API
  ([2b412a6](https://github.com/seanthimons/specmill/tree/2b412a6c8c67360805bc312c7c6402a6a5e7f8a1))
- review multiple APIs and generate isolated transports with batch
  limits
  ([6443b36](https://github.com/seanthimons/specmill/tree/6443b361dc28c238d555f4edb875758bcbb192e6))
- inherit project policies and explain excluded operations
  ([ec4fac6](https://github.com/seanthimons/specmill/tree/ec4fac6791b0110343dab3ab93d38198930d8213))
- expose editable configuration and reconcile excluded grouped endpoints
  ([4203a01](https://github.com/seanthimons/specmill/tree/4203a01dfa12b1688b0f97c293749b6e4323d576))
- generate configured clients with transport and authentication support
  (#5)
  ([13308cf](https://github.com/seanthimons/specmill/tree/13308cf8126c5399c7e1aab63de8df73866b7bdc))
- demonstrate full Petstore coverage and configurable naming (#2)
  ([7045586](https://github.com/seanthimons/specmill/tree/7045586f6632707e8c4e909e89e7e170c74c2361))
- generate API key and bearer authentication with credential setup
  ([5088335](https://github.com/seanthimons/specmill/tree/50883358d68b8be2f6c32f1087e7a269ebf3dcfb))
- generate headers query arrays and binary uploads
  ([1fccfda](https://github.com/seanthimons/specmill/tree/1fccfda60d762691b28ff216c8dc7d6cada1e375))
- select JSON bodies when alternative media types are offered
  ([f212312](https://github.com/seanthimons/specmill/tree/f2123125ff40ac1d9d661ef8ed5becdc94c46c40))
- scaffold editable configuration from schema tags
  ([ee7c998](https://github.com/seanthimons/specmill/tree/ee7c9983d66383b0d519b364c562314960dded36))
- demonstrate full Petstore coverage and grouped naming
  ([4aa53d8](https://github.com/seanthimons/specmill/tree/4aa53d8457e52de544ca3002c32489f172700e79))

#### Bug fixes

- document client controls and include reviewed corpus evidence
  ([a2efeea](https://github.com/seanthimons/specmill/tree/a2efeeaccdbc8c7d726acf77b76641d950c21136))
- clear inherited R test startup for nested builds
  ([fb4f814](https://github.com/seanthimons/specmill/tree/fb4f8148cbbcd7af8a0f1f9b48ff224ac328c1b2))
- reconcile corpus fixture failures and audit evidence
  ([2469955](https://github.com/seanthimons/specmill/tree/24699558e01fb702bf1cbcdc17e30ce15f244bfd))
- make duplicate operation names actionable (#43)
  ([aa58c7b](https://github.com/seanthimons/specmill/tree/aa58c7bc3c1068fa8d5309947b611ab84eb37bcc))
- use exact security lookups for Swagger schemas
  ([aa456bf](https://github.com/seanthimons/specmill/tree/aa456bf591bc68b17cb9787cdb615261c967a493))
- stop inseparable lifecycle-protected generation changes
  ([ab32802](https://github.com/seanthimons/specmill/tree/ab32802c631c7f0166efcde49e514184506f1010))
- respect enum membership for nullable fixture values
  ([d9e1558](https://github.com/seanthimons/specmill/tree/d9e1558711c3ab9de0bd6f2434ac597ebd99b636))
- inspect explicit helper mappings without partial matching
  ([727850b](https://github.com/seanthimons/specmill/tree/727850bd83f4efa3572814029d54fea62ca33305))
- validate selected body fixture hints without fallback
  ([cc5b61c](https://github.com/seanthimons/specmill/tree/cc5b61cdc96715d5a595209c339ca07e64bd52d5))
- preserve fixture evidence and report source contradictions
  ([ec11e96](https://github.com/seanthimons/specmill/tree/ec11e964dc73eb13d39f39816b3eb312b793785e))
- keep generated filenames and Unicode literals portable
  ([a9e923a](https://github.com/seanthimons/specmill/tree/a9e923a4b85d4c6b0a219eeb7b09615f116bf8df))
- validate public schema inputs before client hooks
  ([085e5da](https://github.com/seanthimons/specmill/tree/085e5da269bc35bb9a6b1a2d52f2c4d611c253d8))
- align advertised and generated HTTP methods
  ([4c48e1f](https://github.com/seanthimons/specmill/tree/4c48e1fb9edebd6704749ecdb7dd810cafe41bb1))
- merge versioned request body semantics (#24)
  ([3ac0fa0](https://github.com/seanthimons/specmill/tree/3ac0fa04664672132dd499d8799cf3a3240e178b))
- respect versioned request body semantics (#24)
  ([706a573](https://github.com/seanthimons/specmill/tree/706a57392aec7acc033ed434c6afd5dc322603d3))
- merge request schema directionality (#22)
  ([f1f7503](https://github.com/seanthimons/specmill/tree/f1f7503978443c68e76625f6bed3f6c1f3b35109))
- apply read-only request semantics (#22)
  ([54ee5a2](https://github.com/seanthimons/specmill/tree/54ee5a282782f9ce775656d0f55a82689e28e4b8))
- merge Swagger consumes handling (#21)
  ([e75bdbf](https://github.com/seanthimons/specmill/tree/e75bdbfe850011a32349c9de0d595e5bdc2f4f10))
- merge parameter contract validation (#20)
  ([773ba3c](https://github.com/seanthimons/specmill/tree/773ba3c7901b8db08fd3ed43c65f3631855f6333))
- honor Swagger body consumes (#21)
  ([c529051](https://github.com/seanthimons/specmill/tree/c529051242ac5c3ae14336408bbcad79ecf2a0b1))
- validate parameter contracts (#20)
  ([13a9b16](https://github.com/seanthimons/specmill/tree/13a9b163a39ffea701120504243b4471727e8694))
- preserve reviewed operation names (#17)
  ([1ddfd30](https://github.com/seanthimons/specmill/tree/1ddfd308767ac8b8405025684de7aae4c099cda8))
- distinguish schema defects from unsupported capabilities (#15)
  ([8ebbea7](https://github.com/seanthimons/specmill/tree/8ebbea70442726db3a9fd73eb74a751316d3eab4))
- apply shared batch limits only to applicable bodies
  ([ee2dafc](https://github.com/seanthimons/specmill/tree/ee2dafcaacbcef37e4e5a0a1c9bd7a8752000c3b))
- treat blank schema tags as untagged operations
  ([6778f1c](https://github.com/seanthimons/specmill/tree/6778f1c042277a0db27aca978fb0c0807eb5e71c))
- preserve credential backups when environment restoration fails
  ([57806dd](https://github.com/seanthimons/specmill/tree/57806dda3ed069419f28fd0af844d6d22724271b))
- preserve ownership when renaming grouped functions
  ([5f18f60](https://github.com/seanthimons/specmill/tree/5f18f6012c2aaaf9c7a0c84a28fb2b9ddd3d6a4a))
- rebuild the Petstore trial against the live service
  ([fff0e08](https://github.com/seanthimons/specmill/tree/fff0e082f5a338c6ad02a4a00c3798199a195804))
- install the trial client in a fresh R process
  ([5d8d71c](https://github.com/seanthimons/specmill/tree/5d8d71c8de6edd9178af2c48f523c63b2378fb10))

#### Tests

- reproduce matching-input proving-ground rebuild and comparison
  ([93e8d4a](https://github.com/seanthimons/specmill/tree/93e8d4a148a68ba1d2a11ce055caff4579ba94de))
- assert installed request methods and content types
  ([9122950](https://github.com/seanthimons/specmill/tree/912295065fd03957b26f49550d97f30cee034b11))
- declare escaped query fixture value in local client schema
  ([b411630](https://github.com/seanthimons/specmill/tree/b411630263a097c64fef3d528d40b8f922ccc11a))
- verify installed clients and exact localhost request bytes
  ([b053cda](https://github.com/seanthimons/specmill/tree/b053cda80e91dd33ae2e8215a41640b652da632f))
- preserve valid boundary fixtures and document transport nulls
  ([919d248](https://github.com/seanthimons/specmill/tree/919d24847bebda313c2be89d810f72a4b54f6668))
- preserve custom text requests during manual helper adoption
  ([6b470ad](https://github.com/seanthimons/specmill/tree/6b470adf0e76704871206465c374d1901a1af13a))
- align retained diagnostics with request body semantics (#24)
  ([4a74669](https://github.com/seanthimons/specmill/tree/4a74669944059923b9af49cae97c9d5ad92fbde1))
- reject invalid generated-client credentials (#7)
  ([c55360d](https://github.com/seanthimons/specmill/tree/c55360d47b8e9831a3c5583fc33e51f207ffc574))
- verify ComptoxR request acceptance (#7)
  ([35462b1](https://github.com/seanthimons/specmill/tree/35462b19736a230e8485af7301a4d723b5f88d69))
- add extended schema corpus sources
  ([721b890](https://github.com/seanthimons/specmill/tree/721b890cb0b2169bcdd0f1d181d5781db459c013))
- record composition verification and operation deltas (#12)
  ([e248191](https://github.com/seanthimons/specmill/tree/e24819143fca860636f44de49e1f741d1ffbb654))
- record native schema gap verification and operation deltas (#9)
  ([e67fa8f](https://github.com/seanthimons/specmill/tree/e67fa8f2405138c76f10a8390180e10b8a1a79bb))
- verify native YAML ingestion against both schema corpora (#18)
  ([db76be3](https://github.com/seanthimons/specmill/tree/db76be33e00c603e13c170e7adfcb835d5d98d01))
- audit the additional schema corpus
  ([f823a16](https://github.com/seanthimons/specmill/tree/f823a166717c6ae238fb4fcae792fd8d7ca8be5d))

#### CI

- allow verified schema hashes in audit ledger
  ([212f465](https://github.com/seanthimons/specmill/tree/212f4650e298296b86c8bb7a251a7a36327f44fb))
- pin corrected baseline R check workflow
  ([f25fdee](https://github.com/seanthimons/specmill/tree/f25fdeea9c89a2fa6229f909db9bb45aee529def))
- migrate workflows to baseline callers
  ([25827e1](https://github.com/seanthimons/specmill/tree/25827e1f0797b6c4bbb37a500c88bc2f456a1cba))
- exclude verified schema hash false positive from secret scan
  ([9fcd6e0](https://github.com/seanthimons/specmill/tree/9fcd6e0bd448c89ee045c9551efa3bf116d168e1))
- make platform checks manual during early development (#3)
  ([91d8c63](https://github.com/seanthimons/specmill/tree/91d8c637f5b53fedd7afb08cb079a3c666e9876c))
- add checked release artifacts and a new-schema trial (#1)
  ([384e914](https://github.com/seanthimons/specmill/tree/384e914a255563bdbacd3a245fa1ee71b4d8d00d))
- add checked release artifacts and a new-schema trial
  ([1b8009a](https://github.com/seanthimons/specmill/tree/1b8009a891f3fcfe8d2d3cd05e7c3ad4ad930ebb))

#### Docs

- make client guides independent of ComptoxR
  ([23355ea](https://github.com/seanthimons/specmill/tree/23355eac94ea8ccf36447c17a72b18a7ff46055b))
- refresh client workflows and add hex logo
  ([13b14b8](https://github.com/seanthimons/specmill/tree/13b14b86090c207b2fe5c84eee8c15f52d7e1b82))
- include multi-api configuration in reference index
  ([5d07118](https://github.com/seanthimons/specmill/tree/5d0711821f033f47921b85f35699407df6bf98d4))
- finalize verified issue status and preserve contract blockers
  ([8b93d9b](https://github.com/seanthimons/specmill/tree/8b93d9b90ca98984fef3a5aae819e299150d2b60))
- record verified issue outcomes and matching-input corpus comparison
  ([03aa43f](https://github.com/seanthimons/specmill/tree/03aa43fae1ad57847d3a262663e8d81eb517611f))
- attribute new fixture failures to incompatible declared examples
  ([0a6ba35](https://github.com/seanthimons/specmill/tree/0a6ba358badc701d0cb0dbe7f59915d6f09da43a))
- verify individual unresolved source contracts for open issues
  ([2fb077e](https://github.com/seanthimons/specmill/tree/2fb077ed3892f779c675fbf97238ac7343cc4996))
- explain function naming conventions
  ([84125df](https://github.com/seanthimons/specmill/tree/84125df7a9af1012d62af41483dac9dfed6f8dcd))
- record unsupported resolver GET-body disposition
  ([071267d](https://github.com/seanthimons/specmill/tree/071267df1118aa71ef68e6f68f1043887742c464))
- audit generated client capabilities (#6)
  ([a45d73a](https://github.com/seanthimons/specmill/tree/a45d73af51596b148a9138f014cd3077f73b7889))
- trim ComptoxR verification artifact
  ([107e0dd](https://github.com/seanthimons/specmill/tree/107e0dda8287c7af546f9acfcaba528ba93a803b))
- record unresolved source contracts and audit verification (#16)
  ([76de348](https://github.com/seanthimons/specmill/tree/76de3482aa76a3791ff16fe9bf3215de95633612))
- apply and record ComptoxR proving-ground selection policy
  ([61e2ccc](https://github.com/seanthimons/specmill/tree/61e2ccc0dd9fe4d3d44de17cdd2756fe299a3b07))
- crosswalk capability issues and expand implementation handoff
  ([337d83d](https://github.com/seanthimons/specmill/tree/337d83de337f6e5a689af4aa7bbd23e9abd1eb0b))
- classify proving-ground schema blockers and rank coverage fixes
  ([006885d](https://github.com/seanthimons/specmill/tree/006885d262df8d3908996c324103a5b095a547e4))
- explain endpoint naming and family configuration
  ([db6a828](https://github.com/seanthimons/specmill/tree/db6a828c294d8087195fac3c3b85ffb353496dc4))

#### Style

- normalize fixture evidence line endings
  ([1446d6c](https://github.com/seanthimons/specmill/tree/1446d6c029c7ed06d11e4686802fca9cb9877a28))

#### Other changes

- release v0.1.5 \[skip ci\]
  ([93fa257](https://github.com/seanthimons/specmill/tree/93fa257c82eac712d8eff8396233f83207b35f55))
- package base proving-ground schemas for transfer
  ([d800dc2](https://github.com/seanthimons/specmill/tree/d800dc20c9f36fc62471d9a5d1ff91b20f61d9fd))
- retire the Petstore build script
  ([fba499b](https://github.com/seanthimons/specmill/tree/fba499bbe5a8922ce72f89fc6f0464d877144a74))
- download additional testing schemas and relative references
  ([e2f94b1](https://github.com/seanthimons/specmill/tree/e2f94b14df671497f890d37c13663a0432d6306d))
- sync manual platform check policy
  ([031a1ad](https://github.com/seanthimons/specmill/tree/031a1ad62d3bbe90b98a3dc7c724a87af9a877ae))

Full set of changes:
[`v0.1.4...v0.1.5`](https://github.com/seanthimons/specmill/compare/v0.1.4...v0.1.5)

## specmill 0.1.4 (2026-09-10)

#### Bug fixes

- declare JSON runtime dependency in initialized clients
  ([af66d3c](https://github.com/seanthimons/specmill/tree/af66d3c95d7356651539253dba4c01972972d7ef))

#### Refactorings

- rename the generated runtime template to specmill
  ([fce7a11](https://github.com/seanthimons/specmill/tree/fce7a11fc2afd17254c7ebf727dddbd036c32672))

#### Build

- release specmill with the renamed runtime template
  ([a35ab1e](https://github.com/seanthimons/specmill/tree/a35ab1ef1032c1044f49a1d8686dc35e9f80d4a2))

#### Docs

- record specmill migration validation
  ([42e2374](https://github.com/seanthimons/specmill/tree/42e2374c1c15f2f3311d1987ca174eeaec694fed))

Full set of changes:
[`v0.1.3...v0.1.4`](https://github.com/seanthimons/specmill/compare/v0.1.3...v0.1.4)

## specmill 0.1.3 (2026-09-10)

#### Breaking changes

- rename package and client tooling to specmill
  ([e876984](https://github.com/seanthimons/specmill/tree/e876984b69e06d10d09dd3b3314f20a8d749795b))

#### Tests

- record migration parity and schema stress evidence
  ([78ef38b](https://github.com/seanthimons/specmill/tree/78ef38b86a3b7d048a3b809384fc0d7040da8da8))

#### Docs

- add client setup guides and package website
  ([f200247](https://github.com/seanthimons/specmill/tree/f2002479df7a39a54293de3f4b99a47ef631278d))
- record completed maintenance migration gates
  ([4adb754](https://github.com/seanthimons/specmill/tree/4adb7546ee232ed36048219f596c07d402831666))

Full set of changes:
[`v0.1.2...v0.1.3`](https://github.com/seanthimons/specmill/compare/v0.1.2...v0.1.3)

## specmill 0.1.2 (2026-09-09)

#### Bug fixes

- preserve portable metadata and complete alias policies
  ([8da0f99](https://github.com/seanthimons/specmill/tree/8da0f990e650eb918a98f1851ed63926c88df46d))
- order generation metadata independently of locale
  ([05df627](https://github.com/seanthimons/specmill/tree/05df627fb602b4654b69f6d617692bedcee80241))

Full set of changes:
[`v0.1.1...v0.1.2`](https://github.com/seanthimons/specmill/compare/v0.1.1...v0.1.2)

## specmill 0.1.1 (2026-09-09)

#### Bug fixes

- format owned files without formatter skip directives
  ([8627b81](https://github.com/seanthimons/specmill/tree/8627b8176969476a983e080b06753cf1bb679f60))

## specmill 0.1.0 (2026-09-09)

#### New features

- unify generation commands and schema coverage reports
  ([59f21db](https://github.com/seanthimons/specmill/tree/59f21dbe40a127cd6b2509e85d2aaea7046062c3))
- extract readiness and public maintenance checks
  ([e3e477a](https://github.com/seanthimons/specmill/tree/e3e477acd8cff20d1fbdc447c2bab22aec1f9d92))
- preserve client layouts and verify complete fixed contracts
  ([c21bfae](https://github.com/seanthimons/specmill/tree/c21bfaec670b05f6fe438bd03540660407eeb36b))
- verify public resolver POST mapping and per-contract fixtures
  ([014df22](https://github.com/seanthimons/specmill/tree/014df2271eff14a8da7e8eb8f99d66c35fd6f480))
- retain schema limitations for explicit client request mappings
  ([edff590](https://github.com/seanthimons/specmill/tree/edff590b2279df7ff1d764615a8b4c80ee236a60))
- support ordered array request bindings and verify EPI batch mapping
  ([9f8f7df](https://github.com/seanthimons/specmill/tree/9f8f7dfbe234d1c6dea4a0b0e096e92d0f4886ca))
- support nested payloads and explicit client interfaces
  ([0098221](https://github.com/seanthimons/specmill/tree/0098221f4a7004cebbd3592345ada9e1caff53f7))
- add declarative helper mappings and documentation policy
  ([f101c22](https://github.com/seanthimons/specmill/tree/f101c22f37db2158fa13dab33da50b667cd4ed24))
- add YAML generation and recoverable client initialization
  ([96034d3](https://github.com/seanthimons/specmill/tree/96034d33767f6c95e7e00a54d77c2ad6ad584793))
- verify reusable schema generation and isolated client contracts
  ([aae88f9](https://github.com/seanthimons/specmill/tree/aae88f99f6bd355a06d3404fd100b86620609e83))
- extract local wrapper maintenance tools and catalogue checks
  ([d2be109](https://github.com/seanthimons/specmill/tree/d2be109bb089a13b9313147c7bf2c6cd2348049c))

#### Bug fixes

- keep scoped ownership metadata deterministic
  ([c6ff795](https://github.com/seanthimons/specmill/tree/c6ff795e3e0a03431d0513138d956c45b45e0442))
- report metadata drift and validate owned output recovery
  ([9fc002c](https://github.com/seanthimons/specmill/tree/9fc002c6004e5a01d74cdd7836e16a23be119df2))
- preserve required-input validation by client hooks
  ([e68b957](https://github.com/seanthimons/specmill/tree/e68b957cba98a404d08b6fe80d6cd4cc53915df1))

#### Refactorings

- rename maintenance toolkit to apipak
  ([fc574ca](https://github.com/seanthimons/specmill/tree/fc574ca5c180c75ce875ca0877f5963116d54654))

#### Build

- exclude worktree metadata from source archives
  ([4178b3a](https://github.com/seanthimons/specmill/tree/4178b3adaec0a350d4e0ad38ef28af1199eb4a22))

#### Docs

- resolve final handoff scope and verification gaps
  ([4722e0e](https://github.com/seanthimons/specmill/tree/4722e0eb7b3c029ae1ef3112969e8073a113e747))
- scope Natural Products work to schema validation
  ([0349ab6](https://github.com/seanthimons/specmill/tree/0349ab6b4a2712ccd15ca6bc2b556df5ab716413))
- record diff-based review of generated customizations
  ([a281982](https://github.com/seanthimons/specmill/tree/a281982622231de0ae0724034c308eb86b1386aa))
- record approved configuration and callback boundary
  ([8b05117](https://github.com/seanthimons/specmill/tree/8b051174f5a0da06bfd6eb8006a397610eb2eaca))
- require diagnosis of wrapper generation and endpoint failures
  ([33e7607](https://github.com/seanthimons/specmill/tree/33e760723f51ac2ba887304bb1470e620abe9f60))
- record production baseline planning assumption
  ([35b0ac8](https://github.com/seanthimons/specmill/tree/35b0ac882d03a45f26287dbe667cbd273eb0f0da))
- harden apipak handoff with reproducible audit cases
  ([2053d3f](https://github.com/seanthimons/specmill/tree/2053d3f4dc7ce4d362f96c4bbabb8daec6d39f07))
- record apipak generalization handoff
  ([d367e31](https://github.com/seanthimons/specmill/tree/d367e3177cc2ba805cd125bf5849d39d58bab455))

Full set of changes:
[`d2be109...v0.1.0`](https://github.com/seanthimons/specmill/compare/d2be109...v0.1.0)
