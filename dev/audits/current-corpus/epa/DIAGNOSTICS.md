# Build diagnostics

Parser-blocked operations were not generated. Source defects require a corrected upstream schema.
Missing request contracts require service-owned evidence. No schema repairs or encoding guesses were applied.
Capability gaps describe generator limitations; they do not establish that a schema is invalid.
Only the first parser blocker per operation is reported; correcting it may expose another.
Offline smoke passes do not establish live service compatibility.


Operation failures or blockers: 4

- echo-all-data.swagger.json: `GET /echo_rest_services.get_facilities` [fixture]: No valid fixture: supply a reviewed override
- echo-all-data.swagger.json: `POST /echo_rest_services.get_facilities` [fixture]: No valid body fixture: supply a reviewed override
- echo-all-data.swagger.json: `GET /echo_rest_services.get_facility_info` [fixture]: No valid fixture: supply a reviewed override
- echo-all-data.swagger.json: `POST /echo_rest_services.get_facility_info` [fixture]: No valid body fixture: supply a reviewed override

Details: [operations.csv](operations.csv), [schemas.csv](schemas.csv), [sources.csv](sources.csv).
