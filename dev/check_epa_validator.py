"""Run from the checkout: python3 dev/check_epa_validator.py.

Fetch the public EPA OPERA schema and upload its unmodified bytes to Swagger.
"""
import copy
import datetime
import hashlib
import json
from pathlib import Path
import urllib.parse
import urllib.request

source_url = "https://hcd.rtpnc.epa.gov/api/opera/swagger.json"
validator_url = "https://validator.swagger.io/validator/debug"
with urllib.request.urlopen(source_url, timeout=20) as response:
    body = response.read()
document = json.loads(body)
assert document["openapi"].startswith(("3.0.", "3.1."))
assert document["info"]["title"] == "OPERA Predictor"
with urllib.request.urlopen(validator_url.rsplit("/", 1)[0] + "/openapi.json", timeout=20) as response:
    api = json.load(response)
names = [p["$ref"].rsplit("/", 1)[-1] for p in api["paths"]["/debug"]["post"]["parameters"]]
all_true = dict.fromkeys(names, True)
profiles = {
    "default": {},
    "modern": {"jsonSchemaValidation": True, "legacyJsonSchemaValidation": False},
    "all_true": all_true,
    "all_true_modern": dict(all_true, legacyJsonSchemaValidation=False),
    "references_modern": {"jsonSchemaValidation": True, "legacyJsonSchemaValidation": False,
                          "resolve": True, "validateInternalRefs": True, "validateExternalRefs": True},
    "nontransforming_modern": dict.fromkeys(names, False) | {
        "jsonSchemaValidation": True, "validateInternalRefs": True},
}
results = []
for name, options in profiles.items():
    query = urllib.parse.urlencode({k: str(v).lower() for k, v in options.items()})
    request = urllib.request.Request(validator_url + ("?" + query if query else ""), data=body,
                                    headers={"Content-Type": "application/json", "Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=20) as response:
        report = json.load(response)
        status = response.status
    assert isinstance(report, dict), "Unexpected validator response"
    errors = [e for e in report.get("schemaValidationMessages", []) if e.get("level") == "error"]
    result = {"profile": name, "options": options, "http_status": status,
              "semantic_message_count": len(report.get("messages", [])), "schema_error_count": len(errors),
              "instance_pointer_count": sum("pointer" in e.get("instance", {}) for e in errors), "report": report}
    results.append(result)
    print(name, "messages", result["semantic_message_count"], "errors", len(errors),
          "pointers", result["instance_pointer_count"], flush=True)
# Verify that the validator detects a known defect, keeping the wild-type bytes intact.
control = copy.deepcopy(document)
del control["paths"]["/api/opera"]["get"]["responses"]
controls = []
for name in ("default", "modern"):
    query = urllib.parse.urlencode({k: str(v).lower() for k, v in profiles[name].items()})
    request = urllib.request.Request(validator_url + ("?" + query if query else ""),
                                    data=json.dumps(control).encode(),
                                    headers={"Content-Type": "application/json", "Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=20) as response:
        report = json.load(response)
    assert report.get("messages") or report.get("schemaValidationMessages"), "Missing responses went undetected"
    controls.append({"profile": name, "removed_field": "#/paths/~1api~1opera/get/responses", "report": report})
    print("negative control", name, "rejected", flush=True)
output = Path("dev/audits/swagger-validator")
output.mkdir(parents=True, exist_ok=True)
(output / "opera-production-schema.json").write_bytes(body)
record = {"checked_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
          "source_url": source_url, "source_sha256": hashlib.sha256(body).hexdigest(),
          "openapi": document["openapi"], "validator_url": validator_url,
          "service_version": api["info"]["version"], "profiles": results, "negative_controls": controls}
(output / "opera-option-profiles.json").write_text(json.dumps(record, indent=2) + "\n")
