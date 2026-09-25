# Build diagnostics

Parser-blocked operations were not generated. Source defects require a corrected upstream schema.
Missing request contracts require service-owned evidence. No schema repairs or encoding guesses were applied.
Capability gaps describe generator limitations; they do not establish that a schema is invalid.
Only the first parser blocker per operation is reported; correcting it may expose another.
Offline smoke passes do not establish live service compatibility.


Operation failures or blockers: 53

- alerts.json: `POST /api/alerts` [review_required]: Binary parameter requires source contract review (#16); Unsupported nested parameter object
  Source: `#/paths/~1api~1alerts/post/parameters/0/schema`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- alerts.json: `POST /api/alerts/groups` [review_required]: Binary parameter requires source contract review (#16)
  Source: `#/paths/~1api~1alerts~1groups/post/parameters/0/schema`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- alerts.json: `POST /api/alerts/groups/{id}/add` [review_required]: Binary parameter requires source contract review (#16); Unsupported nested parameter object
  Source: `#/paths/~1api~1alerts~1groups~1{id}~1add/post/parameters/1/schema`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- alerts.json: `POST /api/alerts/groups/{id}/replace` [review_required]: Binary parameter requires source contract review (#16)
  Source: `#/paths/~1api~1alerts~1groups~1{id}~1replace/post/parameters/1/schema`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- amos.json: `POST /api/amos/add_aqc_spectrum/` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1add_aqc_spectrum~1/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/add_new_fact_sheet/` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1add_new_fact_sheet~1/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/add_new_method/` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1add_new_method~1/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/add_new_product_declaration/` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1add_new_product_declaration~1/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/add_new_safety_data_sheet/` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1add_new_safety_data_sheet~1/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/all_similarities_by_dtxsid/` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1all_similarities_by_dtxsid~1/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/analytical_qc_batch_search` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1analytical_qc_batch_search/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/analytical_qc_keyset_pagination/{limit}` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1analytical_qc_keyset_pagination~1{limit}/post/parameters/1/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/batch_search` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1batch_search/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/count_substances_in_ids/` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1count_substances_in_ids~1/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/dtxsids/` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1dtxsids~1/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/entropy_similarity/` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1entropy_similarity~1/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/fact_sheet_keyset_pagination/{limit}` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1fact_sheet_keyset_pagination~1{limit}/post/parameters/1/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `GET /api/amos/get_similar_structures/{identifier_type}/{identifier}` [schema_defect]: Unmatched path parameter: dtxsid
  Source: `#/paths/~1api~1amos~1get_similar_structures~1{identifier_type}~1{identifier}/get/parameters/0`
  Verify the source contract and correct the schema or use an explicitly retained implementation; do not guess a replacement.
- amos.json: `GET /api/amos/list_sources_by_record_type/{record_type}` [schema_defect]: Missing path parameter: record_type
  Source: `#/paths/~1api~1amos~1list_sources_by_record_type~1{record_type}`
  Verify the source contract and correct the schema or use an explicitly retained implementation; do not guess a replacement.
- amos.json: `POST /api/amos/mass_range_search/` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1mass_range_search~1/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/mass_spectra_for_substances/` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1mass_spectra_for_substances~1/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/mass_spectrum_similarity_search/` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1mass_spectrum_similarity_search~1/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/max_similarity_by_dtxsid/` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1max_similarity_by_dtxsid~1/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/method_keyset_pagination/{limit}` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1method_keyset_pagination~1{limit}/post/parameters/1/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/next_level_classification/` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1next_level_classification~1/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/product_declaration_keyset_pagination/{limit}` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1product_declaration_keyset_pagination~1{limit}/post/parameters/1/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/record_counts_by_dtxsid/` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1record_counts_by_dtxsid~1/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/retrieve_fact_sheets/` [schema_defect]: Invalid input schema type
  Source: `#/paths/~1api~1amos~1retrieve_fact_sheets~1/post/parameters/0/type`
  Verify the source contract and correct the schema or use an explicitly retained implementation; do not guess a replacement.
- amos.json: `POST /api/amos/retrieve_product_declarations/` [schema_defect]: Invalid input schema type
  Source: `#/paths/~1api~1amos~1retrieve_product_declarations~1/post/parameters/0/type`
  Verify the source contract and correct the schema or use an explicitly retained implementation; do not guess a replacement.
- amos.json: `POST /api/amos/retrieve_safety_data_sheets/` [schema_defect]: Invalid input schema type
  Source: `#/paths/~1api~1amos~1retrieve_safety_data_sheets~1/post/parameters/0/type`
  Verify the source contract and correct the schema or use an explicitly retained implementation; do not guess a replacement.
- amos.json: `POST /api/amos/safety_data_sheet_keyset_pagination/{limit}` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1safety_data_sheet_keyset_pagination~1{limit}/post/parameters/1/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/search_for_document_ids/{record_type}` [schema_defect]: Invalid input schema type
  Source: `#/paths/~1api~1amos~1search_for_document_ids~1{record_type}/post/parameters/1/type`
  Verify the source contract and correct the schema or use an explicitly retained implementation; do not guess a replacement.
- amos.json: `POST /api/amos/spectral_entropy/` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1spectral_entropy~1/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/spectrum_count_for_methodology/` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1spectrum_count_for_methodology~1/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/substances_for_classification/` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1substances_for_classification~1/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- amos.json: `POST /api/amos/substances_for_ids/` [review_required: request media unspecified]: Ambiguous body media type
  Source: `#/paths/~1api~1amos~1substances_for_ids~1/post/parameters/0/schema`
  Obtain a service-owned media declaration; do not infer JSON or an upload encoding.
- hazard.json: `POST /api/hazard` [review_required]: Binary parameter requires source contract review (#16); Unsupported nested parameter object
  Source: `#/paths/~1api~1hazard/post/parameters/0/schema`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- resolver.json: `POST /api/resolver/casharvest` [review_required]: Binary parameter requires source contract review (#16); Unsupported nested parameter object
  Source: `#/paths/~1api~1resolver~1casharvest/post/parameters/0/schema`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- resolver.json: `GET /api/resolver/ghs-list-count` [review_required]: OAS 3.1 GET request body requires an explicit operation body_media review
  Source: `#/paths/~1api~1resolver~1ghs-list-count/get/requestBody`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- resolver.json: `POST /api/resolver/safety-flags` [review_required]: Binary parameter requires source contract review (#16); Unsupported nested parameter object
  Source: `#/paths/~1api~1resolver~1safety-flags/post/parameters/0/schema`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- resolver.json: `POST /api/resolver/universalharvest` [review_required]: Binary parameter requires source contract review (#16); Unsupported nested parameter object
  Source: `#/paths/~1api~1resolver~1universalharvest/post/parameters/0/schema`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- services.json: `POST /api/services/caspreflight` [review_required]: Binary parameter requires source contract review (#16)
  Source: `#/paths/~1api~1services~1caspreflight/post/parameters/0/schema`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- services.json: `POST /api/services/files` [review_required]: Binary parameter requires source contract review (#16); Unsupported nested parameter object
  Source: `#/paths/~1api~1services~1files/post/parameters/0/schema`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- services.json: `POST /api/services/preflight` [review_required]: Binary parameter requires source contract review (#16)
  Source: `#/paths/~1api~1services~1preflight/post/parameters/0/schema`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- services.json: `POST /api/services/universalpreflight` [review_required]: Binary parameter requires source contract review (#16)
  Source: `#/paths/~1api~1services~1universalpreflight/post/parameters/0/schema`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- standardizer.json: `POST /api/stdizer` [review_required]: Binary parameter requires source contract review (#16); Unsupported nested parameter object
  Source: `#/paths/~1api~1stdizer/post/parameters/0/schema`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- standardizer.json: `POST /api/stdizer/groups` [review_required]: Binary parameter requires source contract review (#16); Unsupported nested parameter object
  Source: `#/paths/~1api~1stdizer~1groups/post/parameters/0/schema`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- standardizer.json: `POST /api/stdizer/groups/preflight` [review_required]: Binary parameter requires source contract review (#16)
  Source: `#/paths/~1api~1stdizer~1groups~1preflight/post/parameters/0/schema`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- standardizer.json: `POST /api/stdizer/groups/{id}/add` [review_required]: Binary parameter requires source contract review (#16); Unsupported nested parameter object
  Source: `#/paths/~1api~1stdizer~1groups~1{id}~1add/post/parameters/1/schema`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- standardizer.json: `POST /api/stdizer/groups/{id}/replace` [review_required]: Binary parameter requires source contract review (#16)
  Source: `#/paths/~1api~1stdizer~1groups~1{id}~1replace/post/parameters/1/schema`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.
- standardizer.json: `GET /api/stdizer/protocols/{id}` [capability_gap]: Unsupported nested parameter object
  Source: `#/paths/~1api~1stdizer~1protocols~1{id}/get/parameters/6/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- standardizer.json: `POST /api/stdizer/protocols/{id}` [capability_gap]: Unsupported nested parameter object
  Source: `#/paths/~1api~1stdizer~1protocols~1{id}/post/parameters/1/schema`
  Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.
- toxprints.json: `POST /api/toxprints/calculate` [review_required]: Binary parameter requires source contract review (#16); Unsupported nested parameter object
  Source: `#/paths/~1api~1toxprints~1calculate/post/parameters/0/schema`
  Review the source and configuration at this location; this diagnostic does not establish schema validity.

Details: [operations.csv](operations.csv), [schemas.csv](schemas.csv), [sources.csv](sources.csv).
