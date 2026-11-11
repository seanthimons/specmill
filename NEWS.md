## specmill 0.2.5 (2026-11-11)

#### New features

- support mapped batches, setup scripts and opaque JSON bodies (#299)
  ([565448a](https://github.com/seanthimons/specmill/tree/565448a374f51fcb00d6866b3db4d616fd77a3e3))
- allow reviewed opaque recursive JSON request bodies (#294)
  ([c4dbe1b](https://github.com/seanthimons/specmill/tree/c4dbe1b991c1f877f73fa2abfa1e71e9964fad57))
- emit client development scripts and offer prompted setup (#289)
  ([9eb8fd7](https://github.com/seanthimons/specmill/tree/9eb8fd74287b4e878cfc5d909c76d244d7238f05))

#### Bug fixes

- escape reviewed body references in generated documentation (#294)
  ([4beebdb](https://github.com/seanthimons/specmill/tree/4beebdbc9cb4d904a65ec1272fdbd39a840ff92b))
- prepare explicit request mappings for concurrent batches (#297)
  ([2aa5782](https://github.com/seanthimons/specmill/tree/2aa5782ee3d826dbd1f4b448a8371a13b76010f7))

#### Docs

- distinguish USGS response recursion from unmapped dependencies (#294)
  ([2974295](https://github.com/seanthimons/specmill/tree/29742957a084eadc86d8bc5ccf5391f7a9a73c11))

Full set of changes:
[`v0.2.4...v0.2.5`](https://github.com/seanthimons/specmill/compare/v0.2.4...v0.2.5)

## specmill 0.2.4 (2026-11-10)

#### Build

- restore pre-rewrite version tags in the release runner so NEWS keeps
  per-version sections
  ([e625d11](https://github.com/seanthimons/specmill/tree/e625d11986588a03c10b637b4f744eec201ced96))

#### CI

- pin R CMD check to baseline v1.4.1 instead of a commit outside its
  main history
  ([f2eaae6](https://github.com/seanthimons/specmill/tree/f2eaae63a78cc81cb031da13cc0801fb83dd9952))

Full set of changes:
[`v0.2.3...v0.2.4`](https://github.com/seanthimons/specmill/compare/v0.2.3...v0.2.4)

## specmill 0.2.3 (2026-11-05)

#### New features

- add explicit freeze_references() acquisition helper (#293)
  ([e11c50a](https://github.com/seanthimons/specmill/tree/e11c50a7c3f4dedc91d39c2bdc482bb02f00c39f))
- resolve reviewed remote schema copies
  ([41b136a](https://github.com/seanthimons/specmill/tree/41b136a8d8265ab389ab8b58ee228db8945101a0))
- add bounded parallel request batches (#287)
  ([705c19b](https://github.com/seanthimons/specmill/tree/705c19bec27cd12439b4d8909449836f8fdf7617))

#### Bug fixes

- roll back freeze_references() writes when a copy fails (#293)
  ([f9eb2ed](https://github.com/seanthimons/specmill/tree/f9eb2ed121ac53c36a8fadc294875b9452862b5e))
- bypass combined hooks for prepared batches (#287)
  ([6de2e72](https://github.com/seanthimons/specmill/tree/6de2e72092842b52d4c006227ab79e9e2119842d))
- decode parallel responses before completion hooks (#287)
  ([dcbe303](https://github.com/seanthimons/specmill/tree/dcbe30357dce5b4dcf034bd141f26d4bd2522820))

#### Build

- drop release commits and empty sections from generated NEWS
  ([1d31c15](https://github.com/seanthimons/specmill/tree/1d31c1557a228468c3da832bb1881ecac437a8c9))

#### Docs

- describe lock-resolved validation in validate_schema (#291)
  ([f89ac4c](https://github.com/seanthimons/specmill/tree/f89ac4c21de12e68cf820d7a6a2f63d9af530e63))

#### Other changes

- ignore root dot-directories and markdown files except required ones
  ([4526e0e](https://github.com/seanthimons/specmill/tree/4526e0ef94788b8fbcc9be704dfb2962dfa24ccc))
- remove duplicate root logo and move testing spec list into dev
  ([4e91bf2](https://github.com/seanthimons/specmill/tree/4e91bf28c7307317a0e5d6050d2f7f23c17635e7))
- ignore R session and planning files as in baseline
  ([5f769d7](https://github.com/seanthimons/specmill/tree/5f769d797c5714b2ef02194b1d807d3f213cfe5a))

Full set of changes:
[`v0.2.2...v0.2.3`](https://github.com/seanthimons/specmill/compare/v0.2.2...v0.2.3)

## specmill 0.2.2 (2026-11-04)

#### Docs

- document legacy debug and verbose integration (#285) (#288)
  ([9c2d55a](https://github.com/seanthimons/specmill/tree/9c2d55a7cc5c720dc95ce4944131d747e7a452ca))

#### Other changes

- restore published patch version 0.2.1
  ([2249510](https://github.com/seanthimons/specmill/tree/2249510c951959140b22e5a1f7e6627d1db725f3))
- retain development version after v0.2.1 release
  ([e1bdae0](https://github.com/seanthimons/specmill/tree/e1bdae0accfbd9d04d19c56c9309009a47cc76e2))

Full set of changes:
[`v0.2.1...v0.2.2`](https://github.com/seanthimons/specmill/compare/v0.2.1...v0.2.2)

## specmill 0.2.1 (2026-11-04)

#### New features

- append configured hints to server and transport errors (#280)
  ([f398b40](https://github.com/seanthimons/specmill/tree/f398b406c63dd420dbbbb6646272fd08a505a94e))

#### Other changes

- begin development version 0.2.1.9000
  ([b09ac60](https://github.com/seanthimons/specmill/tree/b09ac608938f86075ec6dbddb287dd3795b52e76))
- remove proving-ground schema copies now kept in specmill-schemas
  ([7137685](https://github.com/seanthimons/specmill/tree/71376859b6f5e05406ef91f9f2193e08e3a0c6be))

Full set of changes:
[`v0.2.0...v0.2.1`](https://github.com/seanthimons/specmill/compare/v0.2.0...v0.2.1)

## specmill 0.2.0 (2026-11-04)

## specmill 0.1.65 (2026-11-04)

#### Bug fixes

- keep non-transport errors from req_perform distinct from connection
  failures (#275)
  ([f2ac5de](https://github.com/seanthimons/specmill/tree/f2ac5dea5a35bad710dc2a3eadcdddb90ab9883d))

Full set of changes:
[`v0.1.64...v0.1.65`](https://github.com/seanthimons/specmill/compare/v0.1.64...v0.1.65)

## specmill 0.1.64 (2026-11-04)

#### New features

- declare yaml and withr with testthat and vcr in new clients’ Suggests
  (#262)
  ([165aedf](https://github.com/seanthimons/specmill/tree/165aedfc335deb5734eaae2eba9fffb653b527f8))
- keep env-bound arguments out of recordings and harden recording scans
  found in the AQS trial (#262)
  ([9641566](https://github.com/seanthimons/specmill/tree/964156626bf850f60166e07d046473042c842cab))
- report verification layers and scenarios affected by changes since
  recording (#261)
  ([9ce0345](https://github.com/seanthimons/specmill/tree/9ce034583ee20371cb0f92b88d3004da7d14c937))
- propose scenarios and docs example stubs, and review recordings
  against response schemas (#273)
  ([b685200](https://github.com/seanthimons/specmill/tree/b685200aedc6eb6f7379a5c1301871d95eb4be59))
- resolve scenario inputs from reviewed docs examples and schema
  examples (#272)
  ([ef75bad](https://github.com/seanthimons/specmill/tree/ef75badf4cbc29c0a9e00db280d6b6455c22791d))
- generate reviewed hook cases and wrapper integrations (#260)
  ([61267bb](https://github.com/seanthimons/specmill/tree/61267bbad3ba87f886372a8c7f6c5d856a9f833c))
- require approval for write recordings and scan new recordings for
  leaked values (#259)
  ([d2cd7cf](https://github.com/seanthimons/specmill/tree/d2cd7cf6fa878f71a1e9062ee26607a40ccb2ab8))
- generate cassette scenario tests that replay reviewed recordings
  offline (#258)
  ([7d676a7](https://github.com/seanthimons/specmill/tree/7d676a73e11cd70fd619e99f05dd2ab75ae4107a))
- declare reviewed cassette scenarios, contract gaps and unrecorded
  routes (#257)
  ([9281a58](https://github.com/seanthimons/specmill/tree/9281a58cbdda33052cf666b2aa690157eceeddf0))

#### Build

- require vcr 2.0.0 or later in new clients’ Suggests (#262)
  ([99a7b10](https://github.com/seanthimons/specmill/tree/99a7b10799a2595df7ec2e924b0f0d5e2e187137))

#### Tests

- certify offline replay of a generated Swagger 2 client and refuse
  multipart scenarios (#262)
  ([eb319fa](https://github.com/seanthimons/specmill/tree/eb319fa221e2ab76c21db32964cb3c37435f2a85))

#### Docs

- note the vcr 2.0.0 minimum for clients created before it was declared
  (#262)
  ([e303c03](https://github.com/seanthimons/specmill/tree/e303c039acb18536939b63aaa465efab25da65a0))

#### Other changes

- update maintainer email in the catalogue fixture (#274)
  ([68ba993](https://github.com/seanthimons/specmill/tree/68ba993beaedc4f460f1c458dc5890eae5d1feaa))
- update maintainer email (#274)
  ([68c9861](https://github.com/seanthimons/specmill/tree/68c9861d1da58e33ee2881fd8a7586ca08b37da2))

Full set of changes:
[`v0.1.63...v0.1.64`](https://github.com/seanthimons/specmill/compare/v0.1.63...v0.1.64)

## specmill 0.1.63 (2026-11-02)

#### Bug fixes

- configure_client keeps the first reviewed name when groups wrap one
  route twice (#270)
  ([fc0ca9f](https://github.com/seanthimons/specmill/tree/fc0ca9fba3d8a8568a073de4daa442befa996e32))

Full set of changes:
[`v0.1.62...v0.1.63`](https://github.com/seanthimons/specmill/compare/v0.1.62...v0.1.63)

## specmill 0.1.62 (2026-11-02)

#### New features

- opt-in absent_overrides = ‘warn’ skips overrides for operations
  missing from the schema (#266)
  ([1c639be](https://github.com/seanthimons/specmill/tree/1c639be69f9bd9bdee494aacc25b4ff90e2be5d2))

Full set of changes:
[`v0.1.61.9000...v0.1.62`](https://github.com/seanthimons/specmill/compare/v0.1.61.9000...v0.1.62)

## specmill 0.1.61.9000 (2026-10-29)

#### Docs

- explain adapting inconsistent API authentication (#264)
  ([bebdebe](https://github.com/seanthimons/specmill/tree/bebdebe45e4a7258515c0ac8505ac617663a7b05))
- research query credential policy and maintenance tradeoffs (#264)
  ([92d4e96](https://github.com/seanthimons/specmill/tree/92d4e96ba7a2f1a4263e50e1a715e0511cb0fc67))

Full set of changes:
[`v0.1.61...v0.1.61.9000`](https://github.com/seanthimons/specmill/compare/v0.1.61...v0.1.61.9000)

## specmill 0.1.61 (2026-10-29)

#### Bug fixes

- dispatch site builds after package publication
  ([81d80dd](https://github.com/seanthimons/specmill/tree/81d80dd50baca3bef1854308f4ad9807f909ea75))

#### Docs

- refresh installation and current client workflows
  ([bceb2db](https://github.com/seanthimons/specmill/tree/bceb2db591e05eb0d8befa2492813af40c44cf75))

Full set of changes:
[`v0.1.60...v0.1.61`](https://github.com/seanthimons/specmill/compare/v0.1.60...v0.1.61)

## specmill 0.1.60 (2026-10-29)

#### New features

- allow docs.parameters to document the request body argument (#221)
  ([907bed5](https://github.com/seanthimons/specmill/tree/907bed5d9b05c3802e368ad392c8eeb408411be7))

Full set of changes:
[`v0.1.59...v0.1.60`](https://github.com/seanthimons/specmill/compare/v0.1.59...v0.1.60)

## specmill 0.1.59 (2026-10-28)

#### Bug fixes

- handle titles and manual test scaffolding
  ([4aa799c](https://github.com/seanthimons/specmill/tree/4aa799ce66dfe1895f3057b6b68483be5c7620e3))

Full set of changes:
[`v0.1.58...v0.1.59`](https://github.com/seanthimons/specmill/compare/v0.1.58...v0.1.59)

## specmill 0.1.58 (2026-10-28)

#### Bug fixes

- resolve path-name doubling, owned-file splits and coverage service
  exclusion (#212, #213, #214)
  ([d2c2c70](https://github.com/seanthimons/specmill/tree/d2c2c7042acd647534b0622a667c3e97ba14b3e9))

Full set of changes:
[`v0.1.57...v0.1.58`](https://github.com/seanthimons/specmill/compare/v0.1.57...v0.1.58)

## specmill 0.1.57 (2026-10-26)

#### New features

- accept readable YAML or JSON contracts_file keyed by METHOD /path
  (#207)
  ([aa19caf](https://github.com/seanthimons/specmill/tree/aa19cafe1eab32509337dec2522933d0439fbe66))
- add route-derived names with naming = ‘path’ and reported collision
  resolution (#206)
  ([aad2edc](https://github.com/seanthimons/specmill/tree/aad2edc8151d6a7e8cb4acd5d33dcb5fad04d87c))
- add regeneration_report for a read-only clean-regeneration and
  hand-built inventory (#201, #197)
  ([e8ccf39](https://github.com/seanthimons/specmill/tree/e8ccf39df812f6009de377f27a2b06cdc9a1fce2))
- accept a manifest file path to prune stale entries that own no
  operations (#203)
  ([e207ac7](https://github.com/seanthimons/specmill/tree/e207ac7eb6ff1bb93a9037549d0ee62da815c85c))

#### Bug fixes

- find prune fixtures when run from tests/ under R CMD check
  ([f9be47e](https://github.com/seanthimons/specmill/tree/f9be47ee97e9b70e57a244f1494bf022ad6ad3b0))
- expect every path-parameter contradiction in the correction test
  ([340cc0a](https://github.com/seanthimons/specmill/tree/340cc0a096538c9d2937092797b6f455ed5f2ff9))
- expect every path-parameter contradiction in the capability audit
  ([536033b](https://github.com/seanthimons/specmill/tree/536033bdf9742251b637e1c81ed11e879f029cd2))
- report all path parameter name contradictions
  ([8950b82](https://github.com/seanthimons/specmill/tree/8950b82bb13f4469365e7f14aef6f98f6ee7c285))

#### Docs

- refresh audit header, print per-finding output, assert plan diagnostic
  codes (#208)
  ([7e0f433](https://github.com/seanthimons/specmill/tree/7e0f433aaeb57e39ead13bd5a28d5d3cabef2b46))
- document upstream schema publication gate and AMOS findings
  ([91ee6f6](https://github.com/seanthimons/specmill/tree/91ee6f6d1fef626e86bf163d12a7ccd8311eed9d))
- name the manifest-recorded owner service in prune IDs
  ([072d142](https://github.com/seanthimons/specmill/tree/072d14260fab13bed0cba3c451a7af915c48c7b8))

Full set of changes:
[`v0.1.56...v0.1.57`](https://github.com/seanthimons/specmill/compare/v0.1.56...v0.1.57)

## specmill 0.1.56 (2026-10-21)

#### New features

- opt-in removal of retired operation outputs and purge of owned output
  (#196)
  ([4a106aa](https://github.com/seanthimons/specmill/tree/4a106aa79ae7d50a33fb30b9439e1daefdf92844))

#### Tests

- cover retired-service and deferral-ID prune; clarify prune scope in
  docs (#196)
  ([7516143](https://github.com/seanthimons/specmill/tree/75161434f3c4a0d5c66a873821c3c7d7417f10d8))

#### Docs

- add worked deferral and exclusion vignette
  ([840267e](https://github.com/seanthimons/specmill/tree/840267e99873ba49656f1c47308b04b4517c34ce))

#### Other changes

- merge deferral vignette (#199) into prune branch
  ([f75ad34](https://github.com/seanthimons/specmill/tree/f75ad34baed34a9fcadd935b53bec08046cdb1b4))

Full set of changes:
[`v0.1.55...v0.1.56`](https://github.com/seanthimons/specmill/compare/v0.1.55...v0.1.56)

## specmill 0.1.55 (2026-10-21)

#### New features

- validate minimum, maximum and items on extra_parameters (#194)
  ([079613c](https://github.com/seanthimons/specmill/tree/079613c7f15abfddef764bb04bf3acad7b28ea3f))

Full set of changes:
[`v0.1.54...v0.1.55`](https://github.com/seanthimons/specmill/compare/v0.1.54...v0.1.55)

## specmill 0.1.54 (2026-10-20)

#### Bug fixes

- count unclaimed claims from services on the same server (#192)
  ([2b120fa](https://github.com/seanthimons/specmill/tree/2b120fa0770cef7ec224ec2762740339909a9ea5))

Full set of changes:
[`v0.1.53...v0.1.54`](https://github.com/seanthimons/specmill/compare/v0.1.53...v0.1.54)

## specmill 0.1.53 (2026-10-20)

#### New features

- method-qualified exclusions and unclaimed services (#189, #190)
  ([0b7c7a7](https://github.com/seanthimons/specmill/tree/0b7c7a7d35c5761d15c70e118a2a8bd0226b719c))

Full set of changes:
[`v0.1.52...v0.1.53`](https://github.com/seanthimons/specmill/compare/v0.1.52...v0.1.53)

## specmill 0.1.52 (2026-10-20)

#### New features

- defer one enrolled contract revision until its schema changes
  ([1d9163f](https://github.com/seanthimons/specmill/tree/1d9163fbc09433725361a0b6771e9aec98d2d773))
- report added and removed endpoints with affected functions
  ([28dad03](https://github.com/seanthimons/specmill/tree/28dad03a8b439daa88db460dfe4079b8d96df555))
- warn when checked schemas differ from last apply
  ([75c661c](https://github.com/seanthimons/specmill/tree/75c661cc88eb9539da932315499bb3e9ef005a61))

#### Docs

- explain contract deferrals and schema drift
  ([ba3e8f4](https://github.com/seanthimons/specmill/tree/ba3e8f49051f976467d3f9193d2d4fa67a655d28))
- document contract-change deferral in README and troubleshooting
  ([70fe5e6](https://github.com/seanthimons/specmill/tree/70fe5e63c56ee7383e2dacf34e8cb6e54f5760a8))

Full set of changes:
[`v0.1.51...v0.1.52`](https://github.com/seanthimons/specmill/compare/v0.1.51...v0.1.52)

## specmill 0.1.51 (2026-10-19)

#### Bug fixes

- store project-relative response source paths (#186)
  ([96ea5a8](https://github.com/seanthimons/specmill/tree/96ea5a8caaffcb35abe57b2064341cc690327cce))

#### Tests

- compare source identities independently of schema order (#186)
  ([6d3f9f0](https://github.com/seanthimons/specmill/tree/6d3f9f082c5e50d44a0cdff631ae2875e5bc756b))

Full set of changes:
[`v0.1.50...v0.1.51`](https://github.com/seanthimons/specmill/compare/v0.1.50...v0.1.51)

## specmill 0.1.50 (2026-10-19)

Full set of changes:
[`v0.1.49...v0.1.50`](https://github.com/seanthimons/specmill/compare/v0.1.49...v0.1.50)

## specmill 0.1.49 (2026-10-19)

Full set of changes:
[`v0.1.48...v0.1.49`](https://github.com/seanthimons/specmill/compare/v0.1.48...v0.1.49)

## specmill 0.1.48 (2026-10-19)

Full set of changes:
[`v0.1.47...v0.1.48`](https://github.com/seanthimons/specmill/compare/v0.1.47...v0.1.48)

## specmill 0.1.47 (2026-10-19)

Full set of changes:
[`v0.1.46...v0.1.47`](https://github.com/seanthimons/specmill/compare/v0.1.46...v0.1.47)

## specmill 0.1.46 (2026-10-19)

Full set of changes:
[`v0.1.45...v0.1.46`](https://github.com/seanthimons/specmill/compare/v0.1.45...v0.1.46)

## specmill 0.1.45 (2026-10-18)

#### New features

- split reviewed explicit client inputs (#181)
  ([4c332e1](https://github.com/seanthimons/specmill/tree/4c332e1c4be6f424f25ef859c6f3139ac5cf0a3f))
- preserve reviewed session cache lifecycles (#174)
  ([ece9732](https://github.com/seanthimons/specmill/tree/ece9732d82d5fba6762041e7429e2102d1514522))

#### Bug fixes

- reconcile reviewed shared schema contracts (#61)
  ([6351745](https://github.com/seanthimons/specmill/tree/63517454b244630663dca1a4c983a56dd19c9fb4))

#### Tests

- publish ready server ports atomically (#177)
  ([15ac3d3](https://github.com/seanthimons/specmill/tree/15ac3d3260b8225728cf86ca33ea8c58e98a3ec2))
- publish ready server ports atomically (#177)
  ([585da27](https://github.com/seanthimons/specmill/tree/585da27da150638b99e50134a262825e4cb7e389))
- validate reviewed response fixtures and filtering (#61)
  ([140d826](https://github.com/seanthimons/specmill/tree/140d82641223f05d47ab837813e4f4f547189b50))
- expect schema boolean query encoding (#177)
  ([b23330d](https://github.com/seanthimons/specmill/tree/b23330de7ee0cf08092e8b59cb4a788973fedd1b))

Full set of changes:
[`v0.1.44...v0.1.45`](https://github.com/seanthimons/specmill/compare/v0.1.44...v0.1.45)

## specmill 0.1.44 (2026-10-18)

#### Bug fixes

- preserve hook controls and dynamic page limits (#173)
  ([b8d15b4](https://github.com/seanthimons/specmill/tree/b8d15b4d614e0fccf1cde2a7a4b330c48c2f7053))

Full set of changes:
[`v0.1.43...v0.1.44`](https://github.com/seanthimons/specmill/compare/v0.1.43...v0.1.44)

## specmill 0.1.43 (2026-10-18)

#### New features

- preserve facade hooks around native body offsets (#173)
  ([ae62c1f](https://github.com/seanthimons/specmill/tree/ae62c1f081fe6b28976fc5bca2e2dbcd27414b8a))

#### Bug fixes

- encode declared free-form scalar fields (#178)
  ([ec43b6e](https://github.com/seanthimons/specmill/tree/ec43b6ee627fa312955cd472d9521b64df0854f1))

#### Tests

- expect native boolean query encoding (#177)
  ([f6c9304](https://github.com/seanthimons/specmill/tree/f6c9304ff58af44ce0351f0a9aef3118ae3ee6ee))

Full set of changes:
[`v0.1.42...v0.1.43`](https://github.com/seanthimons/specmill/compare/v0.1.42...v0.1.43)

## specmill 0.1.42 (2026-10-18)

#### New features

- select initial hook params independently (#173)
  ([bf15fa5](https://github.com/seanthimons/specmill/tree/bf15fa595478dba498a0dc4943b52ffaff91b669))
- configure shared native request throttling (#175)
  ([1e627d7](https://github.com/seanthimons/specmill/tree/1e627d73c5c60d1bca4e6d5ba0fa20f9438fc9ae))
- format unbatched results with client callbacks (#157)
  ([0a64366](https://github.com/seanthimons/specmill/tree/0a643669ecd9d84847d20852ac37ac323365d1e1))
- validate full inputs before permissive fan out (#166)
  ([b7586c1](https://github.com/seanthimons/specmill/tree/b7586c13067b73f160b6c499d8ce460b1c9c758b))

#### Bug fixes

- encode native scalar query booleans (#177)
  ([26596e7](https://github.com/seanthimons/specmill/tree/26596e77831fc98e78b87b760bf93d5e22ff1524))
- reconcile restored desired output hashes (#170)
  ([a0b5c19](https://github.com/seanthimons/specmill/tree/a0b5c19f711586b71fdb5f2812db794f78e1d774))

#### Tests

- retain formatter in visibility regression
  ([56358d1](https://github.com/seanthimons/specmill/tree/56358d169134794570e1108af33fafc3ec06c5f5))

#### Docs

- retain unresolved production similarity list (#165)
  ([3a346c1](https://github.com/seanthimons/specmill/tree/3a346c1fed5f7a9d22c93f112a81db731156ad34))

Full set of changes:
[`v0.1.41...v0.1.42`](https://github.com/seanthimons/specmill/compare/v0.1.41...v0.1.42)

## specmill 0.1.41 (2026-10-18)

#### CI

- build documentation after publication or on demand
  ([d0c096c](https://github.com/seanthimons/specmill/tree/d0c096c8aca04f1c4729cf8ca782de8bf5da4b61))

Full set of changes:
[`v0.1.40...v0.1.41`](https://github.com/seanthimons/specmill/compare/v0.1.40...v0.1.41)

## specmill 0.1.40 (2026-10-18)

#### New features

- run post response once after final formatting (#162)
  ([4bbe804](https://github.com/seanthimons/specmill/tree/4bbe80405f4463951fbdb50d16f16cee92f78e60))

#### CI

- exclude verified historical schema hashes
  ([8110b6e](https://github.com/seanthimons/specmill/tree/8110b6e304a031f9c0c2810c0cd292666393498a))

#### Docs

- describe manual platform checks
  ([9c6057f](https://github.com/seanthimons/specmill/tree/9c6057f5a112cd0f5db53702482a4eeb9259adb1))

Full set of changes:
[`v0.1.39...v0.1.40`](https://github.com/seanthimons/specmill/compare/v0.1.39...v0.1.40)

## specmill 0.1.39 (2026-10-18)

#### New features

- expose the generated response decoder (#156)
  ([202bad7](https://github.com/seanthimons/specmill/tree/202bad70a8fd4029efafdaa2b0ba4b29e0e3058a))
- preserve private initial and selected post params (#158)
  ([494890f](https://github.com/seanthimons/specmill/tree/494890f5f4ad85825497e38a7a0853fd0d864d2c))
- preserve typed request errors when selected (#156)
  ([9bd95ff](https://github.com/seanthimons/specmill/tree/9bd95ffdb210a8f74735a3e3990193b19ad70141))

#### CI

- run platform package checks only on demand
  ([9e4d2e9](https://github.com/seanthimons/specmill/tree/9e4d2e9c5236fec3c939b6f46d19e99cfd9d1dc6))

Full set of changes:
[`v0.1.38...v0.1.39`](https://github.com/seanthimons/specmill/compare/v0.1.38...v0.1.39)

## specmill 0.1.38 (2026-10-18)

#### New features

- preserve final client formatting conditions (#154)
  ([f84f525](https://github.com/seanthimons/specmill/tree/f84f525e168a5871ad0f0d5a482689dd492432bb))

Full set of changes:
[`v0.1.37...v0.1.38`](https://github.com/seanthimons/specmill/compare/v0.1.37...v0.1.38)

## specmill 0.1.37 (2026-10-18)

#### Other changes

- finalize released pagination integration (#152)
  ([2d3a784](https://github.com/seanthimons/specmill/tree/2d3a784389e0e89040ffc0e58dc3ef1af56db5f1))
- integrate reviewed generator policies (#152)
  ([09e8eb9](https://github.com/seanthimons/specmill/tree/09e8eb9d3bf483ebac3ff02e3832b9cbe3e89d38))

Full set of changes:
[`v0.1.36...v0.1.37`](https://github.com/seanthimons/specmill/compare/v0.1.36...v0.1.37)

## specmill 0.1.36 (2026-10-18)

#### Other changes

- integrate released client policies (#149)
  ([a630ec9](https://github.com/seanthimons/specmill/tree/a630ec954448293ce2a0dfa420b5f49b4891828f))

Full set of changes:
[`v0.1.35...v0.1.36`](https://github.com/seanthimons/specmill/compare/v0.1.35...v0.1.36)

## specmill 0.1.35 (2026-10-18)

#### Other changes

- integrate released error and warning policies (#147)
  ([9977a2f](https://github.com/seanthimons/specmill/tree/9977a2fbba66d14caca423a10af95722fce7b251))

Full set of changes:
[`v0.1.34...v0.1.35`](https://github.com/seanthimons/specmill/compare/v0.1.34...v0.1.35)

## specmill 0.1.34 (2026-10-18)

#### Bug fixes

- resolve reviewed callbacks outside generated locals (#149)
  ([2db1912](https://github.com/seanthimons/specmill/tree/2db19121955a370f5455c8b9f70790c8b935799a))
- resolve warning formatters outside generated locals (#145)
  ([b7bb10f](https://github.com/seanthimons/specmill/tree/b7bb10f3a5d1494f39ca7859e0fdaf7d2b691ed5))

#### Other changes

- integrate released batch and line policies (#147)
  ([bcf8c12](https://github.com/seanthimons/specmill/tree/bcf8c1267597983401adc87f8319a41b53ded372))
- integrate released metadata and line policies (#145)
  ([c44cc13](https://github.com/seanthimons/specmill/tree/c44cc13f99b0444e53b507db65519e17ebc04e0f))

Full set of changes:
[`v0.1.33...v0.1.34`](https://github.com/seanthimons/specmill/compare/v0.1.33...v0.1.34)

## specmill 0.1.33 (2026-10-18)

#### New features

- preserve reviewed dropped-request warnings (#145)
  ([f0e0714](https://github.com/seanthimons/specmill/tree/f0e0714b9cd4cefff369a7b75217aec08763cbef))

Full set of changes:
[`v0.1.32...v0.1.33`](https://github.com/seanthimons/specmill/compare/v0.1.32...v0.1.33)

## specmill 0.1.32 (2026-10-18)

Full set of changes:
[`v0.1.31...v0.1.32`](https://github.com/seanthimons/specmill/compare/v0.1.31...v0.1.32)

## specmill 0.1.31 (2026-10-18)

Full set of changes:
[`v0.1.30...v0.1.31`](https://github.com/seanthimons/specmill/compare/v0.1.30...v0.1.31)

## specmill 0.1.30 (2026-10-18)

#### Bug fixes

- forget explicitly retired missing outputs (#152)
  ([2a53eec](https://github.com/seanthimons/specmill/tree/2a53eec09818e05dfd5c0259c15f7091f4942332))

#### Other changes

- integrate reviewed visibility and response policies (#147)
  ([f665ad8](https://github.com/seanthimons/specmill/tree/f665ad868575d0c039618cc91e1d4ca12d465c13))
- integrate reviewed return visibility policies (#145)
  ([bb57db8](https://github.com/seanthimons/specmill/tree/bb57db8a74d49d045f0fa1e7c453c28fc8ec0732))
- integrate reviewed visibility and response policies (#142)
  ([af33b32](https://github.com/seanthimons/specmill/tree/af33b32585a3f5fc4e0f81cd2862745038b41480))

Full set of changes:
[`v0.1.29...v0.1.30`](https://github.com/seanthimons/specmill/compare/v0.1.29...v0.1.30)

## specmill 0.1.29 (2026-10-18)

#### New features

- generate reviewed cursor pagination wrappers (#149)
  ([68e41e2](https://github.com/seanthimons/specmill/tree/68e41e2c71b11db9e84e853bcf102924431eef98))

#### Bug fixes

- continue across reviewed empty result pages (#149)
  ([1a451f1](https://github.com/seanthimons/specmill/tree/1a451f1dfdfe4dc3c4e4dcd0b70483c8907f5969))
- allow generated pagination controls in examples (#149)
  ([d1fef8b](https://github.com/seanthimons/specmill/tree/d1fef8b41132649a23ee5d8b4bd81e06896be0b7))

#### Other changes

- integrate reviewed response and paging policies (#31)
  ([6d8b62f](https://github.com/seanthimons/specmill/tree/6d8b62fc73a61cc5da7fb367978234f5e5d2b47e))
- integrate released pagination policies (#142)
  ([baea339](https://github.com/seanthimons/specmill/tree/baea3390cd59bb4a599f201fbb06fe1b23a38fa7))

Full set of changes:
[`v0.1.28...v0.1.29`](https://github.com/seanthimons/specmill/compare/v0.1.28...v0.1.29)

## specmill 0.1.28 (2026-10-18)

#### New features

- defer reviewed response-only facade arguments (#147)
  ([a2e355b](https://github.com/seanthimons/specmill/tree/a2e355bfda0d83f9d5207ee28672f32f1375538b))

#### Other changes

- integrate released bodyless operation baseline (#129)
  ([ff93785](https://github.com/seanthimons/specmill/tree/ff93785db84137d1d99d1c2b6f45e03b6b9a656e))

Full set of changes:
[`v0.1.27...v0.1.28`](https://github.com/seanthimons/specmill/compare/v0.1.27...v0.1.28)

## specmill 0.1.27 (2026-10-18)

#### New features

- select error policy by effective request count (#145)
  ([1d7f40d](https://github.com/seanthimons/specmill/tree/1d7f40dec482ec03107748322453045a0e28032a))
- allow plain failure result attributes by policy (#142)
  ([04705de](https://github.com/seanthimons/specmill/tree/04705de79d9aa1dd8e0a23910b718bc9ab2c6d8b))

#### Other changes

- retain reviewed responses and bodyless subsets (#26)
  ([cf7cb3e](https://github.com/seanthimons/specmill/tree/cf7cb3e32e29f45779ccbd2398273d92544e03fa))
- retain visibility with bodyless operation policy (#31)
  ([98aa781](https://github.com/seanthimons/specmill/tree/98aa781b57ae6f1d00d1e9b2372ae85311fd5a76))
- integrate reviewed operation policies (#129)
  ([29c46ff](https://github.com/seanthimons/specmill/tree/29c46ffecbc00ac81773935581fb2be0e0c3d665))
- integrate released reviewed path baseline (#29)
  ([12190c6](https://github.com/seanthimons/specmill/tree/12190c65b8b314afb938fc85b4447899b9e73928))

Full set of changes:
[`v0.1.26...v0.1.27`](https://github.com/seanthimons/specmill/compare/v0.1.26...v0.1.27)

## specmill 0.1.26 (2026-10-17)

#### Bug fixes

- retain line entries for response callbacks (#140)
  ([601896a](https://github.com/seanthimons/specmill/tree/601896ab8027f511170ca2d942057fef711a79c5))

#### Other changes

- combine response declarations with reviewed paths (#26)
  ([49e74f7](https://github.com/seanthimons/specmill/tree/49e74f77883e4933eb2af4d8d511e3f1db9ee663))
- retain visibility alongside reviewed paths (#31)
  ([ef7ed59](https://github.com/seanthimons/specmill/tree/ef7ed5987a26c69c0fc0e15df7628811346a9d2a))
- combine reviewed paths and bodyless subsets (#29)
  ([59ee8ab](https://github.com/seanthimons/specmill/tree/59ee8ab288872c52de7d327d6567ce05e6aa9523))
- integrate released normalization baseline (#27)
  ([2471767](https://github.com/seanthimons/specmill/tree/24717674be0b46ad4a09c6bed8b0c7959aa0ed52))

Full set of changes:
[`v0.1.25...v0.1.26`](https://github.com/seanthimons/specmill/compare/v0.1.25...v0.1.26)

## specmill 0.1.25 (2026-10-17)

#### New features

- preserve single helper return visibility by policy (#31)
  ([8517c72](https://github.com/seanthimons/specmill/tree/8517c72ebdf81c932454f4e15f3d0895894d532b))
- normalize selected client values before validation and iteration
  (#135)
  ([5209bf5](https://github.com/seanthimons/specmill/tree/5209bf5963de083bf0b85891f9e789f55829bf66))

#### Bug fixes

- trim trailing blanks from emitted validators (#138)
  ([a57431d](https://github.com/seanthimons/specmill/tree/a57431d8a74c3620b3c1456aced988374469fd26))

#### Other changes

- combine input normalization and return visibility (#31)
  ([8a04b82](https://github.com/seanthimons/specmill/tree/8a04b8214fa2402e30263c3f3dbc6f251aea3226))
- retain contract corrections with input normalization (#26)
  ([4907a47](https://github.com/seanthimons/specmill/tree/4907a479876fb40ea56004d6092032b3d69ebc74))
- retain bodyless subsets with input normalization (#29)
  ([1e2045f](https://github.com/seanthimons/specmill/tree/1e2045f1dc84c11082d340da0690e4b187ce02e7))
- retain reviewed paths with input normalization (#27)
  ([f5ab279](https://github.com/seanthimons/specmill/tree/f5ab279556d6af744c1ce70dad41fe83f2e983bd))
- integrate released batch support baseline (#135)
  ([8ff3b55](https://github.com/seanthimons/specmill/tree/8ff3b55f18d5b626c206691814173b7d49f3f50b))

Full set of changes:
[`v0.1.24...v0.1.25`](https://github.com/seanthimons/specmill/compare/v0.1.24...v0.1.25)

## specmill 0.1.24 (2026-10-17)

#### New features

- review empty response declarations per operation (#26)
  ([9656ed1](https://github.com/seanthimons/specmill/tree/9656ed15421cd0faa63b1981e184815b8792f7cd))

#### Tests

- account for empty environment values on Windows (#128)
  ([7f36b17](https://github.com/seanthimons/specmill/tree/7f36b178edae7d2498d6e8b9b32cff2a4c298776))

#### Other changes

- preserve reviewed corrections with security policy (#26)
  ([dbcea94](https://github.com/seanthimons/specmill/tree/dbcea940d3dfc3e954b899854bed1ed9f2df41d5))
- integrate released security policy (#29)
  ([4754d4d](https://github.com/seanthimons/specmill/tree/4754d4d22f24c2d82166014963ead29f14c79828))
- integrate released security corrections (#27)
  ([d7b3f83](https://github.com/seanthimons/specmill/tree/d7b3f834fbe883f661f51177d4091290121e9bd9))

Full set of changes:
[`v0.1.23...v0.1.24`](https://github.com/seanthimons/specmill/compare/v0.1.23...v0.1.24)

## specmill 0.1.23 (2026-10-17)

#### New features

- declare reviewed missing Swagger JSON media (#26)
  ([d528d21](https://github.com/seanthimons/specmill/tree/d528d21023a44c75aa938dbdc252f3d2cc8d7c31))
- allow plain result attributes by policy (#129)
  ([a233d3c](https://github.com/seanthimons/specmill/tree/a233d3cdf95a05a99ea6f445877e8f13d290b3bf))
- support reviewed bodyless GET subsets (#29)
  ([e8dbec5](https://github.com/seanthimons/specmill/tree/e8dbec55c2f4d1fb9e2947aa3bf6253bdf15c592))
- support reviewed path declarations (#27)
  ([17243ff](https://github.com/seanthimons/specmill/tree/17243ffdaab6c957d2107d0224d7bd505101445b))
- resolve reviewed batch limits at call time (#128)
  ([e007d3a](https://github.com/seanthimons/specmill/tree/e007d3a83ccf236d42b190adde724965a6b58017))

#### Other changes

- integrate security correction before batch release
  ([3f90763](https://github.com/seanthimons/specmill/tree/3f9076333c71960e4ab062c43935941c5d9b6724))

Full set of changes:
[`v0.1.22...v0.1.23`](https://github.com/seanthimons/specmill/compare/v0.1.22...v0.1.23)

## specmill 0.1.22 (2026-10-17)

#### New features

- allow reviewed operation security corrections (#108)
  ([78e1a36](https://github.com/seanthimons/specmill/tree/78e1a3653ebcdab75fb2b2082e11232b2d530e12))

#### Other changes

- integrate released transport changes
  ([697baef](https://github.com/seanthimons/specmill/tree/697baefe8aaee929f73c9f9f1c3158e73ab62bbc))

Full set of changes:
[`v0.1.21...v0.1.22`](https://github.com/seanthimons/specmill/compare/v0.1.21...v0.1.22)

## specmill 0.1.21 (2026-10-17)

#### New features

- correct reviewed text media and split line batches (#125)
  ([6f492e7](https://github.com/seanthimons/specmill/tree/6f492e760b12143705d4695b26ff40bd0d752aa3))
- allow request bodies in parameter_order (#123)
  ([259c931](https://github.com/seanthimons/specmill/tree/259c9313b76492fb07c950162c1df9523c078ddd))

#### Bug fixes

- render line body examples as character vectors (#125)
  ([add4df5](https://github.com/seanthimons/specmill/tree/add4df55699d63138c5662b3c5076a13811f6b40))

Full set of changes:
[`v0.1.20...v0.1.21`](https://github.com/seanthimons/specmill/compare/v0.1.20...v0.1.21)

## specmill 0.1.20 (2026-10-17)

#### New features

- let the batching option lower a split wrapper’s chunk size at runtime
  (#121)
  ([3a81aa0](https://github.com/seanthimons/specmill/tree/3a81aa04b9e45c7e1959a8e7ee859af3b0b7d449))

Full set of changes:
[`v0.1.19...v0.1.20`](https://github.com/seanthimons/specmill/compare/v0.1.19...v0.1.20)

## specmill 0.1.19 (2026-10-17)

#### Tests

- cover post_combine on paged fan-out and the ignored legacy flag
  warning (#119)
  ([259f03e](https://github.com/seanthimons/specmill/tree/259f03eb93acfb200dc48e62058bedeb6f45a789))

Full set of changes:
[`v0.1.18...v0.1.19`](https://github.com/seanthimons/specmill/compare/v0.1.18...v0.1.19)

## specmill 0.1.18 (2026-10-17)

#### New features

- page each item inside batch.fan_out and batch.split (#111)
  ([1233904](https://github.com/seanthimons/specmill/tree/12339045c3a2c932f04be9d3a98eccefdddbda52))
- allow request_controls.timeout of Inf for no limit and name timeout
  failures (#110)
  ([2ee2016](https://github.com/seanthimons/specmill/tree/2ee2016bf24a0ad807d06b189ebc224319abf236))
- add empty result and stop on rejected credentials
  ([6ab331c](https://github.com/seanthimons/specmill/tree/6ab331c9e7e659ad66f4b1a31b853ac59c1ba00e))
- warn when a schema leaves security off some operations while others
  declare it (#108)
  ([630386d](https://github.com/seanthimons/specmill/tree/630386d68b11c9ae9a42ae3566da87bac5a7408b))

#### Bug fixes

- point lock errors at the guide, warn on ignored legacy flags, order
  update workflow (#114, #115, #116)
  ([345c3e6](https://github.com/seanthimons/specmill/tree/345c3e69c086b3c0b854a694e77f85a2b79073e7))
- warn about unsecured operations across tag services of one schema
  (#112)
  ([c13aeed](https://github.com/seanthimons/specmill/tree/c13aeed010e6f1b7ea738c2164019f2d8c11c735))

#### Docs

- add a typical workflow diagram with command and recovery tables
  ([f5b7cf0](https://github.com/seanthimons/specmill/tree/f5b7cf057e9d1ef994e583c94161a3834b0ec748))
- run every generated contract test after apply (#113)
  ([ed3335f](https://github.com/seanthimons/specmill/tree/ed3335f1c92484f3594f5a00aaa2fa6c4a982540))

Full set of changes:
[`v0.1.17...v0.1.18`](https://github.com/seanthimons/specmill/compare/v0.1.17...v0.1.18)

## specmill 0.1.17 (2026-10-16)

#### New features

- let api_request_table() take a client’s own table builder (#100)
  ([0e9daa1](https://github.com/seanthimons/specmill/tree/0e9daa1b16fd106ae7abb40930173fc7d76e4f63))
- let generated operations opt into paging from YAML (#101)
  ([19f8c04](https://github.com/seanthimons/specmill/tree/19f8c0427f29678a2af978ca929862d87ec3ebaf))
- measure coverage against schema operations with denominator: schema
  (#102)
  ([b42ab7a](https://github.com/seanthimons/specmill/tree/b42ab7ae2b090ac6cc9df20d9bc84bab1611f241))

#### Bug fixes

- follow a renamed body argument in contract inputs and validation
  messages (#105, #106)
  ([80104bd](https://github.com/seanthimons/specmill/tree/80104bdf66af213a66fe4f9486483e5a6b7481ad))
- count an operation once per method and path within a group (#102)
  ([0fcbd19](https://github.com/seanthimons/specmill/tree/0fcbd1903dafa3ac96d90e78917721100baf8b51))
- normalize the root for relative schema paths, and name duplicate
  runtime definitions
  ([a7617ff](https://github.com/seanthimons/specmill/tree/a7617ffc90eeb07209a49793d956d15f4dffe238))
- keep tables typed once when a policy tags the pages it returns (#100,
  #101)
  ([2dcb633](https://github.com/seanthimons/specmill/tree/2dcb6334f1889588e4f4f2ba1920020a576c4864))
- recover column types once over all requests and add a post_combine
  hook stage (#100)
  ([bf509d4](https://github.com/seanthimons/specmill/tree/bf509d4e68f8d145ae1b9d0d0481f3ae1a9beadd))
- name the wrapper’s real body argument in docs and fixtures (#99)
  ([0897ec5](https://github.com/seanthimons/specmill/tree/0897ec5566c6c7bc8f05eaa56915a226d5e2dfa1))
- stop on call-level errors when dropping failures
  ([e70b48e](https://github.com/seanthimons/specmill/tree/e70b48ee7f9e3cf8808eb892668dcffd55b673b5))

#### Docs

- note that paged endpoints pass a lone filter as context query
  ([4270307](https://github.com/seanthimons/specmill/tree/427030735e919952292ba9ac62c46bdddc3d9740))

#### Style

- format and lint the files changed by the batching, body-name and
  coverage work
  ([db84478](https://github.com/seanthimons/specmill/tree/db844784f55b277af638fa192dfeaf5f56f9dd40))

#### Other changes

- capture public EPA CAMD and Water Quality Portal specs
  ([7f9b2be](https://github.com/seanthimons/specmill/tree/7f9b2be6bf22fce7516b537676c74b0818a875cb))

Full set of changes:
[`v0.1.16...v0.1.17`](https://github.com/seanthimons/specmill/compare/v0.1.16...v0.1.17)

## specmill 0.1.16 (2026-10-08)

#### Bug fixes

- infer the type of untyped enum schemas from their values (#95)
  ([65576fa](https://github.com/seanthimons/specmill/tree/65576fa109a834f0f9e338c7034a530497e6b608))
- drop a helper’s leading dot from its option names (#94)
  ([ca9973a](https://github.com/seanthimons/specmill/tree/ca9973ad1ae8323933b91af92a87b5d9c0ac9061))
- ignore role lists on API-key and bearer security requirements (#90)
  ([cec431f](https://github.com/seanthimons/specmill/tree/cec431fe9d9fa4e606940d1f8630e899d1e5cfe8))

Full set of changes:
[`v0.1.15...v0.1.16`](https://github.com/seanthimons/specmill/compare/v0.1.15...v0.1.16)

## specmill 0.1.15 (2026-10-08)

#### Docs

- explain reviewing invalid parameter defaults
  ([d499b66](https://github.com/seanthimons/specmill/tree/d499b662567c34f70a74d543f8d76d81806aa6eb))

Full set of changes:
[`v0.1.14...v0.1.15`](https://github.com/seanthimons/specmill/compare/v0.1.14...v0.1.15)

## specmill 0.1.14 (2026-10-07)

#### New features

- parse oneOf, anyOf and allOf parameter schemas (#84)
  ([e605bd9](https://github.com/seanthimons/specmill/tree/e605bd90d206c22fec5a3620e41c62af6807d466))

#### Bug fixes

- keep schema defaults as written for review (#84)
  ([330c011](https://github.com/seanthimons/specmill/tree/330c011815ef513bf995ff1a80ce5bfb2ef6a23c))
- omit empty query defaults the request check rejects (#84)
  ([bee22e7](https://github.com/seanthimons/specmill/tree/bee22e75e492f6d3e330b10a3f6429daf642fd76))

#### Style

- simplify the empty default check
  ([1e1df2e](https://github.com/seanthimons/specmill/tree/1e1df2e49b613a37fd5668df0fe69d695a4a4c3d))

#### Other changes

- merge nullable query defaults into composed parameters (#91)
  ([3ea6a06](https://github.com/seanthimons/specmill/tree/3ea6a06630c5c2f961170691d1ac695f1f8c80b4))

Full set of changes:
[`v0.1.13...v0.1.14`](https://github.com/seanthimons/specmill/compare/v0.1.13...v0.1.14)

## specmill 0.1.13 (2026-10-07)

#### New features

- fan out vector inputs and split array bodies into max_items chunks
  (#81)
  ([4bcf937](https://github.com/seanthimons/specmill/tree/4bcf9379fae8329410d521fb72524ca601026e38))
- support nullable query scalars and validate parameter defaults
  ([dd48fbd](https://github.com/seanthimons/specmill/tree/dd48fbdb00aba8a3f1f35339c15dce28db3cc7d4))
- attribute the request input in policy context (#83)
  ([9739f2e](https://github.com/seanthimons/specmill/tree/9739f2ebeebfd371f9ed19d729231ae679614b7b))

Full set of changes:
[`v0.1.12...v0.1.13`](https://github.com/seanthimons/specmill/compare/v0.1.12...v0.1.13)

## specmill 0.1.12 (2026-10-04)

#### Breaking changes

- emit shared request validators once per client
  ([993c8f8](https://github.com/seanthimons/specmill/tree/993c8f849464f81a65c3c98596d4abdb5c47e723))

#### New features

- resolve per-service base URLs through a client server resolver
  ([6fb33fb](https://github.com/seanthimons/specmill/tree/6fb33fb01ffd6dc510ec9b44326cd2695c13131a))

#### Bug fixes

- accept atomic vectors for JSON array bodies
  ([a72bf5e](https://github.com/seanthimons/specmill/tree/a72bf5e44ac259a7e76eb2dbe2a2dbad7ebdcd18))

#### Docs

- source shared validators in the offline wrapper example
  ([0590a90](https://github.com/seanthimons/specmill/tree/0590a9086f9273ab9ef1ab12f58dc893e36fe737))

Full set of changes:
[`v0.1.11...v0.1.12`](https://github.com/seanthimons/specmill/compare/v0.1.11...v0.1.12)

## specmill 0.1.11 (2026-10-01)

#### Breaking changes

- validate schemas offline against official OpenAPI schemas
  ([5d1f78a](https://github.com/seanthimons/specmill/tree/5d1f78a5eed3da4ebc08adf30d30c69a893333de))

#### New features

- attribute shared definition errors to the operations that reference
  them
  ([cf3fbfd](https://github.com/seanthimons/specmill/tree/cf3fbfdccb2689e5ee3d85b2c456da6e3f702dbd))

#### Bug fixes

- report only the selected oneOf branch for Swagger 2.0 and OpenAPI 3.0
  ([f0d4bb9](https://github.com/seanthimons/specmill/tree/f0d4bb960cb3da9a38058ab598c89c136e771367))
- report Swagger 2.0 parameter errors for their declared location only
  ([4d366a8](https://github.com/seanthimons/specmill/tree/4d366a8872753899b4aec2e1707609f64f268f8b))

#### Build

- import jsonvalidate to satisfy the dependency check
  ([9004350](https://github.com/seanthimons/specmill/tree/9004350f45d0a2c3388d40e9f259d7d34c18f064))

#### Docs

- describe local schema validation
  ([a70c8a9](https://github.com/seanthimons/specmill/tree/a70c8a97d078ec955b7afb4314e7b4ad75a4dc1a))

#### Other changes

- remove hosted validator audit scripts
  ([b1526a6](https://github.com/seanthimons/specmill/tree/b1526a6e99c042bbf856155ed41a3345d2ee82d7))

Full set of changes:
[`v0.1.11...v0.1.11`](https://github.com/seanthimons/specmill/compare/v0.1.11...v0.1.11)

## specmill 0.1.10 (2026-09-30)

#### New features

- require cached Swagger schema validation before generation
  ([af678ff](https://github.com/seanthimons/specmill/tree/af678ffe99c394724e70bfe230f96a39a401bedb))

#### Bug fixes

- enforce schema checks on declared hook routes
  ([8a15c2c](https://github.com/seanthimons/specmill/tree/8a15c2ca0f7d38caa43066bcc5e97b746568581a))

#### Tests

- normalize cache paths in Windows assertions
  ([f4a26fc](https://github.com/seanthimons/specmill/tree/f4a26fceff692f27bd32a8067b8ffc1ff7fdbdf1))

#### Docs

- add schema validator to the reference index
  ([9082246](https://github.com/seanthimons/specmill/tree/9082246c56355a89d36515c76220ca5676c4e09b))
- widen the workflow article and fit desktop charts
  ([4808bb9](https://github.com/seanthimons/specmill/tree/4808bb9b1e5c891c4eb9fe81504af12215b749bc))
- add client workflow and pipeline flowcharts
  ([363ea12](https://github.com/seanthimons/specmill/tree/363ea125e1eb399b2c09f89b06662ce858ed3595))

Full set of changes:
[`v0.1.9...v0.1.10`](https://github.com/seanthimons/specmill/compare/v0.1.9...v0.1.10)

## specmill 0.1.9 (2026-09-30)

#### New features

- integrate request policies and client iteration (#63, #64, #65, #66,
  #67)
  ([f1893cf](https://github.com/seanthimons/specmill/tree/f1893cf2c909728a667f19928d6803ad9fb06351))
- emit owned batching and pagination companions (#64, #65)
  ([58b59bd](https://github.com/seanthimons/specmill/tree/58b59bdfcde29c7a20c53fc262a8cf88e1e3310a))
- support explicit bounded iteration policies (#65)
  ([5e66cd6](https://github.com/seanthimons/specmill/tree/5e66cd6ed870aaa7d47d92c7917e60860028f44a))
- support explicit sequential batching policies (#64)
  ([0d11dd1](https://github.com/seanthimons/specmill/tree/0d11dd18b95eba062c30cfe89d210effff4b85a0))
- select client-owned retry predicates (#67)
  ([8bb01c2](https://github.com/seanthimons/specmill/tree/8bb01c25fc2d3bd1fb48e27e79335468a8094479))
- support declared plain-text bodies (#66)
  ([fe9062a](https://github.com/seanthimons/specmill/tree/fe9062a0df27c0bf3d0b87c27332a73e35c29d7c))
- support selected response policies and decoding (#63)
  ([ee6d89e](https://github.com/seanthimons/specmill/tree/ee6d89eb7cf9bdea481fa674441e9f86f91f11e9))
- optionally guard hook-selected routes before requests (#69)
  ([4890936](https://github.com/seanthimons/specmill/tree/489093676b3821dfa2093030c4a9c3f0932038cf))
- declare schema routes for hook-owned requests
  ([7f5e7b3](https://github.com/seanthimons/specmill/tree/7f5e7b387ddc5bed5e2e1a0a30b4aa5ca5906125))
- exclude reviewed schema parameters per operation
  ([6e66091](https://github.com/seanthimons/specmill/tree/6e660910cd5534f1eab51d5b38eb006126d230f3))

#### Bug fixes

- name the input location in generated validation errors
  ([240af04](https://github.com/seanthimons/specmill/tree/240af04d04d77999ae37593545004bdb769ca9e6))
- render standalone operations without literal guards by default
  ([796b42b](https://github.com/seanthimons/specmill/tree/796b42b897a22859eaa20fdc099b26a913ce0b1c))

#### Docs

- review general request ports and client policy boundaries
  ([b6e7ee0](https://github.com/seanthimons/specmill/tree/b6e7ee0d98ac881b8b77421e97153613d949c9c7))

#### Other changes

- preserve route guards with response policies
  ([b0a0899](https://github.com/seanthimons/specmill/tree/b0a0899e8167f55231c8957e847679e071d07807))

Full set of changes:
[`v0.1.8...v0.1.9`](https://github.com/seanthimons/specmill/compare/v0.1.8...v0.1.9)

## specmill 0.1.8 (2026-09-28)

#### Refactorings

- guard generated body literals only when a constructor is shadowed
  ([3d3139a](https://github.com/seanthimons/specmill/tree/3d3139a90172c634536359b10e4e9c1d16b03789))

Full set of changes:
[`v0.1.7...v0.1.8`](https://github.com/seanthimons/specmill/compare/v0.1.7...v0.1.8)

## specmill 0.1.7 (2026-09-28)

#### New features

- propose operation mappings for hand-written wrappers
  ([3d62927](https://github.com/seanthimons/specmill/tree/3d629271d7b550719b7d2ebe5b33540d7ecea873))
- verify configured operations against hand-written wrappers
  ([1b58ac7](https://github.com/seanthimons/specmill/tree/1b58ac755750081f41425064b3ee7fddd4fe364f))

#### Bug fixes

- guard literals when the client’s imports shadow a data constructor
  ([7274315](https://github.com/seanthimons/specmill/tree/72743150cbdcaf0b88dcd9e6999331f6a99e30e5))
- render public defaults and examples as plain data literals
  ([707e3fc](https://github.com/seanthimons/specmill/tree/707e3fc9f4bd5b86fe9db9bf8c5ace42f1946dcb))
- render whole-number defaults for number parameters as doubles
  ([bd2a1d9](https://github.com/seanthimons/specmill/tree/bd2a1d94f7a8b84eb15f4f33487050b42db6d3ba))

#### CI

- cut a patch release on every merge to main
  ([5d7e998](https://github.com/seanthimons/specmill/tree/5d7e998cfb44417bd456e67ce155d04208185469))

#### Docs

- use propose_mappings and verify_adoption in the adoption guide
  ([810f9a7](https://github.com/seanthimons/specmill/tree/810f9a7a7c653143273f6ae2c227da6646a04644))

Full set of changes:
[`v0.1.6...v0.1.7`](https://github.com/seanthimons/specmill/compare/v0.1.6...v0.1.7)

## specmill 0.1.6 (2026-09-25)

#### Bug fixes

- keep manifest-owned stable wrappers generated
  ([2946ce1](https://github.com/seanthimons/specmill/tree/2946ce1f563e347b3cc80d6086cf41bc93f9f695))

Full set of changes:
[`v0.1.5...v0.1.6`](https://github.com/seanthimons/specmill/compare/v0.1.5...v0.1.6)

## specmill 0.1.5 (2026-09-25)

#### New features

- scaffold client-owned hooks and document their lifecycle
  ([86c7cec](https://github.com/seanthimons/specmill/tree/86c7cec75cc5569819890c9d79491037e551847b))
- add package-prefixed client session controls
  ([62248ec](https://github.com/seanthimons/specmill/tree/62248eca90aae38622cf5fc0e1cd71ae6fac2cda))
- compare client-owned helpers and retain lifecycle-protected files
  ([036bd17](https://github.com/seanthimons/specmill/tree/036bd171834dfd59df17d19caa5adb95ab92cf65))
- add configurable function name casing
  ([014a597](https://github.com/seanthimons/specmill/tree/014a597e131cf195d28b79dd8821cc96af9b484d))
- support finite recursive bodies and refresh schema fixtures
  ([eae918c](https://github.com/seanthimons/specmill/tree/eae918c2615c174846648bea5b4a44eaa15e51d5))
- add bounded cursor and link pagination
  ([5fb9a09](https://github.com/seanthimons/specmill/tree/5fb9a09445b133434afb3945631547fe8db02764))
- expose request timeouts servers and safe retries
  ([9965ee2](https://github.com/seanthimons/specmill/tree/9965ee28c80c68e25ff1ab425fdcefb8f9ddf396))
- harden generated request runtime
  ([249d7ce](https://github.com/seanthimons/specmill/tree/249d7cebe7dad37cc3896c019adce2fa55268534))
- add generic batched helper (#19)
  ([29a65b5](https://github.com/seanthimons/specmill/tree/29a65b585e5885a27529333ff01d0071769d09e9))
- validate composed JSON request bodies (#12)
  ([f682ef4](https://github.com/seanthimons/specmill/tree/f682ef427ffb4f34148b90572c19371d17adb1dc))
- add explicit bracketed query array serialization
  ([84ca521](https://github.com/seanthimons/specmill/tree/84ca52119d6ed22203d611e12f9361f9ffde17e9))
- resolve local schema references and support form requests (#9)
  ([8075851](https://github.com/seanthimons/specmill/tree/80758514d12a85a6a3d21a4345914ea9a2ad8215))
- load JSON and YAML API schemas natively (#18)
  ([6dfeba4](https://github.com/seanthimons/specmill/tree/6dfeba448506a0973d26727836e9350abeb7a48e))
- extend OpenAPI parameter serialization (#8)
  ([bd5b7e8](https://github.com/seanthimons/specmill/tree/bd5b7e8af696cc7cc538b9f593ca91832c8d4937))
- support open JSON objects and unconstrained arrays (#14)
  ([af6c4e4](https://github.com/seanthimons/specmill/tree/af6c4e441c1942e84499ea061ab689fb7f4bb4d2))
- group multi-API configuration into one file per API
  ([aa222d1](https://github.com/seanthimons/specmill/tree/aa222d161892f41faf2fdfba26b871b7a5b05935))
- review multiple APIs and generate isolated transports with batch
  limits
  ([a4b2af5](https://github.com/seanthimons/specmill/tree/a4b2af5c658c0915606ee9573040f0ace13cca96))
- inherit project policies and explain excluded operations
  ([46e5ad2](https://github.com/seanthimons/specmill/tree/46e5ad2296aaddd384da6fb5586e61ff90e74a2c))
- expose editable configuration and reconcile excluded grouped endpoints
  ([c765b10](https://github.com/seanthimons/specmill/tree/c765b10629d32743dcf2659d7258fc471e064ca3))
- generate configured clients with transport and authentication support
  (#5)
  ([3106e70](https://github.com/seanthimons/specmill/tree/3106e70a33ab079d17a6f67b8691e7c4c3397abb))
- demonstrate full Petstore coverage and configurable naming (#2)
  ([df05d1a](https://github.com/seanthimons/specmill/tree/df05d1a8b031f92473b5920b458172ac4d82684c))
- generate API key and bearer authentication with credential setup
  ([0542d63](https://github.com/seanthimons/specmill/tree/0542d631d4ed34eb2373d0da6c52ed28ca28fd87))
- generate headers query arrays and binary uploads
  ([2db5bdd](https://github.com/seanthimons/specmill/tree/2db5bdd1400f96c5d8f7ee1f1500a5c973354d45))
- select JSON bodies when alternative media types are offered
  ([94b2cc8](https://github.com/seanthimons/specmill/tree/94b2cc86dadcb396c3b650086e3e5966ff9a50b2))
- scaffold editable configuration from schema tags
  ([30b7d7a](https://github.com/seanthimons/specmill/tree/30b7d7a94c48e70ba3519aa49b1f13c705fe43d4))
- demonstrate full Petstore coverage and grouped naming
  ([0d8e554](https://github.com/seanthimons/specmill/tree/0d8e55412ba0c92a6fe278393e5f7a2b2ebf9257))

#### Bug fixes

- document client controls and include reviewed corpus evidence
  ([5b11bc9](https://github.com/seanthimons/specmill/tree/5b11bc91f24fdcd1df4c980217d59ceb10cdb17e))
- clear inherited R test startup for nested builds
  ([f580113](https://github.com/seanthimons/specmill/tree/f58011329877d669f58d6b6f3bfb25109e8c9ae8))
- reconcile corpus fixture failures and audit evidence
  ([6a78cde](https://github.com/seanthimons/specmill/tree/6a78cdec3110318dc37e60f5706a98971dedec7e))
- make duplicate operation names actionable (#43)
  ([1a4b460](https://github.com/seanthimons/specmill/tree/1a4b460d46765b5df230f9cb2169253b3500abf9))
- use exact security lookups for Swagger schemas
  ([fed5ac5](https://github.com/seanthimons/specmill/tree/fed5ac5a9a8bd71d5f3c603365b3c590ee35c8eb))
- stop inseparable lifecycle-protected generation changes
  ([78340ae](https://github.com/seanthimons/specmill/tree/78340aec28ecdbf2ac66a4bd955f51762a0b506f))
- respect enum membership for nullable fixture values
  ([ff1ba31](https://github.com/seanthimons/specmill/tree/ff1ba317eb54f62bdbd948cdddcf52f5b44cc8ca))
- inspect explicit helper mappings without partial matching
  ([117f6a6](https://github.com/seanthimons/specmill/tree/117f6a6c557057f8666638eee5619f6e09a14a41))
- validate selected body fixture hints without fallback
  ([b88119a](https://github.com/seanthimons/specmill/tree/b88119a88d95e5e92a3b6692e6cd399b2c8a0145))
- preserve fixture evidence and report source contradictions
  ([9dc9f86](https://github.com/seanthimons/specmill/tree/9dc9f863956be16186acada4ef0105f685642f3f))
- keep generated filenames and Unicode literals portable
  ([4e66b13](https://github.com/seanthimons/specmill/tree/4e66b132e139874f25d21a877b2d4858ffb935ef))
- validate public schema inputs before client hooks
  ([d2e5ad2](https://github.com/seanthimons/specmill/tree/d2e5ad29da23ee631940d26bf2a76865684e3724))
- align advertised and generated HTTP methods
  ([d499ab5](https://github.com/seanthimons/specmill/tree/d499ab5f1823512121d2e6fbcc9b5297ed29c347))
- merge versioned request body semantics (#24)
  ([957d810](https://github.com/seanthimons/specmill/tree/957d81059f27bd8ab251cf5fc3c9bce1457ca377))
- respect versioned request body semantics (#24)
  ([8c746a8](https://github.com/seanthimons/specmill/tree/8c746a8290e69988c584630a564f8f4066ac4fe5))
- merge request schema directionality (#22)
  ([88e0ec9](https://github.com/seanthimons/specmill/tree/88e0ec974acc746d3f20787d3adecbf08cac179e))
- apply read-only request semantics (#22)
  ([9404c78](https://github.com/seanthimons/specmill/tree/9404c78c97c44250e94b2940cce90b2581af48b5))
- merge Swagger consumes handling (#21)
  ([93ea9ef](https://github.com/seanthimons/specmill/tree/93ea9efe382ccfe5ec6779fe0ca5570c20cc191d))
- merge parameter contract validation (#20)
  ([04b8c37](https://github.com/seanthimons/specmill/tree/04b8c375bcc8da6b496086bc16a3588d72e40397))
- honor Swagger body consumes (#21)
  ([f0ff5c0](https://github.com/seanthimons/specmill/tree/f0ff5c0098e939b0e6238f6be662be54e3d35c78))
- validate parameter contracts (#20)
  ([21b1f46](https://github.com/seanthimons/specmill/tree/21b1f46c8202a9323f4894cc07aeed3683330d3b))
- preserve reviewed operation names (#17)
  ([b007592](https://github.com/seanthimons/specmill/tree/b0075921805298bc07ceb27a732ccde021fae697))
- distinguish schema defects from unsupported capabilities (#15)
  ([33516b6](https://github.com/seanthimons/specmill/tree/33516b61372e1f197993593c093de999fbe602c1))
- apply shared batch limits only to applicable bodies
  ([6e1c4f6](https://github.com/seanthimons/specmill/tree/6e1c4f6391dbbd6982fd418b8774c8694cab6e40))
- treat blank schema tags as untagged operations
  ([38aa0af](https://github.com/seanthimons/specmill/tree/38aa0af94a8e21fcb6700fe4874da5d013982504))
- preserve credential backups when environment restoration fails
  ([ef6679b](https://github.com/seanthimons/specmill/tree/ef6679bb5f5f505b5ccc995bdb5de099d7dcfbe4))
- preserve ownership when renaming grouped functions
  ([5dd41e3](https://github.com/seanthimons/specmill/tree/5dd41e3d70e2b73c88574d885905ec55b70f1efc))
- rebuild the Petstore trial against the live service
  ([fac44a9](https://github.com/seanthimons/specmill/tree/fac44a954b9a2b4f09ff96fc5cf3181bd3f6643f))
- install the trial client in a fresh R process
  ([faf4b0f](https://github.com/seanthimons/specmill/tree/faf4b0f74b0215bc7730e67aad7b69a6c794a956))

#### Tests

- reproduce matching-input proving-ground rebuild and comparison
  ([73814a9](https://github.com/seanthimons/specmill/tree/73814a92eb3b9b88eed9df4c14d1423712ecbe53))
- assert installed request methods and content types
  ([f3a8f1d](https://github.com/seanthimons/specmill/tree/f3a8f1d02f1e1ca28b0f583a4e80d0693c7eabd0))
- declare escaped query fixture value in local client schema
  ([a2afe75](https://github.com/seanthimons/specmill/tree/a2afe75b07d60e23170170c2458d0f88e7c53169))
- verify installed clients and exact localhost request bytes
  ([3010b81](https://github.com/seanthimons/specmill/tree/3010b81ed9b15ce6bb47157f62a7268b1abf3c90))
- preserve valid boundary fixtures and document transport nulls
  ([3713dc9](https://github.com/seanthimons/specmill/tree/3713dc9dd238a5752fb5d4fb175dd41f497983cb))
- preserve custom text requests during manual helper adoption
  ([a6e39a1](https://github.com/seanthimons/specmill/tree/a6e39a180a09fbc70f1f43e0e6dc34f281a38f3b))
- align retained diagnostics with request body semantics (#24)
  ([44f912e](https://github.com/seanthimons/specmill/tree/44f912ee370fb5bd433f356edeac70254072b32a))
- reject invalid generated-client credentials (#7)
  ([07bbce3](https://github.com/seanthimons/specmill/tree/07bbce3fff755479d631a02650604e31f35dea78))
- verify ComptoxR request acceptance (#7)
  ([0201726](https://github.com/seanthimons/specmill/tree/0201726485bcaadcef210738c24bc6d93635fbe0))
- add extended schema corpus sources
  ([d253b6d](https://github.com/seanthimons/specmill/tree/d253b6d9cf66da83c54e4195fa793a68c293c0b8))
- record composition verification and operation deltas (#12)
  ([554ca29](https://github.com/seanthimons/specmill/tree/554ca29f7f8f70a79185cacc029fbb438a811159))
- record native schema gap verification and operation deltas (#9)
  ([45064e0](https://github.com/seanthimons/specmill/tree/45064e0b9af4d75fb4c55ae7221c7874b087e030))
- verify native YAML ingestion against both schema corpora (#18)
  ([9c4feeb](https://github.com/seanthimons/specmill/tree/9c4feebccf7b2fb2f7f71d12fa893ae755c863bb))
- audit the additional schema corpus
  ([7630809](https://github.com/seanthimons/specmill/tree/763080972ac608775940e58c93a775cc1fc11d4c))

#### CI

- allow verified schema hashes in audit ledger
  ([5b4ec13](https://github.com/seanthimons/specmill/tree/5b4ec13c9aabb6c95f0525fac1b8b7c8c5839ce8))
- pin corrected baseline R check workflow
  ([fb6dec3](https://github.com/seanthimons/specmill/tree/fb6dec3c28ead431504e71d8acce37bf3ebb3cfc))
- migrate workflows to baseline callers
  ([4bc5b79](https://github.com/seanthimons/specmill/tree/4bc5b792fa74b90d5fdcd8cdba1ac3ca57d0ab50))
- exclude verified schema hash false positive from secret scan
  ([586ce20](https://github.com/seanthimons/specmill/tree/586ce20cf449ae5bc96fac2fdc7a04682e0e5eb9))
- make platform checks manual during early development (#3)
  ([366d65c](https://github.com/seanthimons/specmill/tree/366d65cdbc321be43374aa25ed416fc9472ba1e0))
- add checked release artifacts and a new-schema trial (#1)
  ([7268056](https://github.com/seanthimons/specmill/tree/72680568354a46f489fce04fbc7570a89fc306ec))
- add checked release artifacts and a new-schema trial
  ([48f6bfd](https://github.com/seanthimons/specmill/tree/48f6bfd5ad6f8ea1e69d4860048a37d8160a901f))

#### Docs

- make client guides independent of ComptoxR
  ([fafd3eb](https://github.com/seanthimons/specmill/tree/fafd3eb698e5aec1a6e92bd6e0e69c5f2eed00bb))
- refresh client workflows and add hex logo
  ([12289ae](https://github.com/seanthimons/specmill/tree/12289aeeec5d30458099eb5327bde2df67afa511))
- include multi-api configuration in reference index
  ([0aa7e4d](https://github.com/seanthimons/specmill/tree/0aa7e4daa3ed879de15c6daf83bafff022b3a41d))
- finalize verified issue status and preserve contract blockers
  ([36421fa](https://github.com/seanthimons/specmill/tree/36421fa0f35989b009c5dab4eb9789368cdd05a8))
- record verified issue outcomes and matching-input corpus comparison
  ([5a6b9db](https://github.com/seanthimons/specmill/tree/5a6b9dbff2fb81df9e37a676b67b7ce897c5d634))
- attribute new fixture failures to incompatible declared examples
  ([73be7d9](https://github.com/seanthimons/specmill/tree/73be7d94766ac96a45d24ab25049f1d95004de4a))
- verify individual unresolved source contracts for open issues
  ([eba2f88](https://github.com/seanthimons/specmill/tree/eba2f88fa4401c8b2bbe1ea3a906805cc7ccea68))
- explain function naming conventions
  ([d04a3ec](https://github.com/seanthimons/specmill/tree/d04a3ec87945286826e178e94766d3ee6a523268))
- record unsupported resolver GET-body disposition
  ([4ada30c](https://github.com/seanthimons/specmill/tree/4ada30c7cfb7f01cfb6096a59524a63b3066c18f))
- audit generated client capabilities (#6)
  ([f37c81c](https://github.com/seanthimons/specmill/tree/f37c81cea9c892f892a36889931ca4f7c7330f51))
- trim ComptoxR verification artifact
  ([87584c3](https://github.com/seanthimons/specmill/tree/87584c388edf73d70a5eaaa6713103468e357e84))
- record unresolved source contracts and audit verification (#16)
  ([d925661](https://github.com/seanthimons/specmill/tree/d92566126587e74e9764842abe2e59935d644102))
- apply and record ComptoxR proving-ground selection policy
  ([3675cfb](https://github.com/seanthimons/specmill/tree/3675cfbeef38ed06f92826c1a020003c7ecb64ab))
- crosswalk capability issues and expand implementation handoff
  ([d53b0fb](https://github.com/seanthimons/specmill/tree/d53b0fb8141c8e90e039e1ea5c0979e39d0000fa))
- classify proving-ground schema blockers and rank coverage fixes
  ([766f406](https://github.com/seanthimons/specmill/tree/766f40668bda4c2fe1c6862a1f197e5535e9ee25))
- explain endpoint naming and family configuration
  ([925e619](https://github.com/seanthimons/specmill/tree/925e61928dca6b45d15a901e30ae2997b3c452b8))

#### Style

- normalize fixture evidence line endings
  ([1cd5d81](https://github.com/seanthimons/specmill/tree/1cd5d819778dbe10df774b3bf1675dd831078832))

#### Other changes

- package base proving-ground schemas for transfer
  ([eb6aab4](https://github.com/seanthimons/specmill/tree/eb6aab4948d0a1aeacaeb6c2123c8e49a6135273))
- retire the Petstore build script
  ([678b181](https://github.com/seanthimons/specmill/tree/678b18163218c98e43b56db52d35dcca7cca0437))
- download additional testing schemas and relative references
  ([7a43db0](https://github.com/seanthimons/specmill/tree/7a43db02fe8e7b50cb7339a0092e9e14c2cb55be))
- sync manual platform check policy
  ([e31fe68](https://github.com/seanthimons/specmill/tree/e31fe68a30300a8da77abed12bb9aeb5b7a7e893))

Full set of changes:
[`v0.1.4...v0.1.5`](https://github.com/seanthimons/specmill/compare/v0.1.4...v0.1.5)

## specmill 0.1.4 (2026-09-10)

#### Bug fixes

- declare JSON runtime dependency in initialized clients
  ([ecd02dc](https://github.com/seanthimons/specmill/tree/ecd02dce91a3481757caef78eaefad03900dce01))

#### Refactorings

- rename the generated runtime template to specmill
  ([9dcb075](https://github.com/seanthimons/specmill/tree/9dcb075b0df31e66603eb18dadfe5ad5fdad4bb3))

#### Build

- release specmill with the renamed runtime template
  ([3cac81c](https://github.com/seanthimons/specmill/tree/3cac81c6da8e0aa4288c748fa8229da0a72ef025))

#### Docs

- record specmill migration validation
  ([cd64de8](https://github.com/seanthimons/specmill/tree/cd64de8da1ee83b1c98219a241c255181410923b))

Full set of changes:
[`v0.1.3...v0.1.4`](https://github.com/seanthimons/specmill/compare/v0.1.3...v0.1.4)

## specmill 0.1.3 (2026-09-10)

#### Breaking changes

- rename package and client tooling to specmill
  ([20d211d](https://github.com/seanthimons/specmill/tree/20d211d249879e0bb225f6171f0fe3fc4ebb7c4e))

#### Tests

- record migration parity and schema stress evidence
  ([7205fab](https://github.com/seanthimons/specmill/tree/7205fab027893f25341bffb32608201a71e6f7e1))

#### Docs

- add client setup guides and package website
  ([6a4467d](https://github.com/seanthimons/specmill/tree/6a4467d89f52c2d43ac275f46e2960e6f19d37fe))
- record completed maintenance migration gates
  ([1ffccb3](https://github.com/seanthimons/specmill/tree/1ffccb334cf0c9dcc173816c39d4e62d02d628c5))

Full set of changes:
[`v0.1.2...v0.1.3`](https://github.com/seanthimons/specmill/compare/v0.1.2...v0.1.3)

## specmill 0.1.2 (2026-09-09)

#### Bug fixes

- preserve portable metadata and complete alias policies
  ([2e4a3da](https://github.com/seanthimons/specmill/tree/2e4a3daaa4db86af04c6f40d59bf86c6b48cd441))
- order generation metadata independently of locale
  ([279edd2](https://github.com/seanthimons/specmill/tree/279edd24c873fd9bde63c50b0237741e109fa7d0))

Full set of changes:
[`v0.1.1...v0.1.2`](https://github.com/seanthimons/specmill/compare/v0.1.1...v0.1.2)

## specmill 0.1.1 (2026-09-09)

#### Bug fixes

- format owned files without formatter skip directives
  ([4fc6db4](https://github.com/seanthimons/specmill/tree/4fc6db48d9769230505ed73f12477144e879c844))

## specmill 0.1.0 (2026-09-09)

#### New features

- unify generation commands and schema coverage reports
  ([bf929c7](https://github.com/seanthimons/specmill/tree/bf929c7e85dc81be66f0ea61a1d2b5cf8be462e2))
- extract readiness and public maintenance checks
  ([4eee394](https://github.com/seanthimons/specmill/tree/4eee39418ee8b1f20443ba442b7f9e49aeb43aab))
- preserve client layouts and verify complete fixed contracts
  ([c31cb88](https://github.com/seanthimons/specmill/tree/c31cb88e74c717aee7b1db2b915b03d4e40e0632))
- verify public resolver POST mapping and per-contract fixtures
  ([1a22e80](https://github.com/seanthimons/specmill/tree/1a22e801069c7bf74ea482b6dfbd9c357688bb70))
- retain schema limitations for explicit client request mappings
  ([c40e1da](https://github.com/seanthimons/specmill/tree/c40e1da4cdc122cd75106aedf3c52be1c7564e92))
- support ordered array request bindings and verify EPI batch mapping
  ([68b2fee](https://github.com/seanthimons/specmill/tree/68b2fee4ee4a9c0292fbc85160dbc189d503dff9))
- support nested payloads and explicit client interfaces
  ([1c779a1](https://github.com/seanthimons/specmill/tree/1c779a1798252e11bfcd4169018f89d34b9df9f5))
- add declarative helper mappings and documentation policy
  ([4a47f3e](https://github.com/seanthimons/specmill/tree/4a47f3ed732d0f0cdb545c5c851a8b7739552b7a))
- add YAML generation and recoverable client initialization
  ([1f331bf](https://github.com/seanthimons/specmill/tree/1f331bf2334cdb970e04c6cf861b66633b300b71))
- verify reusable schema generation and isolated client contracts
  ([aae88f9](https://github.com/seanthimons/specmill/tree/aae88f99f6bd355a06d3404fd100b86620609e83))
- extract local wrapper maintenance tools and catalogue checks
  ([d2be109](https://github.com/seanthimons/specmill/tree/d2be109bb089a13b9313147c7bf2c6cd2348049c))

#### Bug fixes

- keep scoped ownership metadata deterministic
  ([571fa8c](https://github.com/seanthimons/specmill/tree/571fa8c184254d5f38afc65f84af7a08ed23c1aa))
- report metadata drift and validate owned output recovery
  ([744a755](https://github.com/seanthimons/specmill/tree/744a75595e9f467de3dc9bb65f830007d0675a1d))
- preserve required-input validation by client hooks
  ([f2484fe](https://github.com/seanthimons/specmill/tree/f2484fe1225459c833bb2a4420ada221c13ac496))

#### Refactorings

- rename maintenance toolkit to apipak
  ([6c5cf18](https://github.com/seanthimons/specmill/tree/6c5cf18825f10da8ff4e5ca5af2f05cafbe3dd23))

#### Build

- exclude worktree metadata from source archives
  ([137dee3](https://github.com/seanthimons/specmill/tree/137dee383ed98d92a2041b02493880205f34b32d))

Full set of changes:
[`d2be109...v0.1.0`](https://github.com/seanthimons/specmill/compare/d2be109...v0.1.0)
