AMOS schema snapshots retrieved on 2026-10-19 for offline endpoint-transition tests.

production.json
Source: https://hcd.rtpnc.epa.gov/api/amos/swagger.json
SHA-256: 4591f49840d0f0f5c8e092fd588c43087a8582e8555c3d477ef4c1a98390eaf4
Swagger 2.0; 77 method/path operations.

development.json
Source: https://cim-dev.sciencedataexperts.com/api/amos/swagger.json
SHA-256: 627d6cb4ec4aab1448163b578a6b857476c817a93404369cddfe87a4dd54c401
OpenAPI 3.0.3; 69 method/path operations.

Production to development adds 8 operations and removes 16. These counts describe
schema declarations, not verified server behavior. Production contains known
validation defects; tests use the explicit legacy validation bypass to exercise
change reporting. Tests never download schemas or call the described operations.
