// Validates one recorded response body against its OpenAPI response schema
// with the ajv build shipped in jsonvalidate. Returns error paths and messages
// only, never the recorded values.
function validate_response(schema, body, dialect) {
  var instance;
  try {
    instance = JSON.parse(body);
  } catch (e) {
    return {status: "unparsed", errors: []};
  }
  var settings = {allErrors: true, strict: false, logger: false};
  var ajv = dialect === "2020" ? new AjvSchema2020(settings) : new AjvSchema4(settings);
  addFormats(ajv);
  var validate;
  try {
    validate = ajv.compile(schema);
  } catch (e) {
    return {status: "uncompiled", errors: [{path: "", message: String(e.message)}]};
  }
  if (validate(instance)) {
    return {status: "agrees", errors: []};
  }
  return {
    status: "disagrees",
    errors: validate.errors.slice(0, 5).map(function (e) {
      return {path: e.instancePath || e.dataPath || "", message: e.message};
    })
  };
}
