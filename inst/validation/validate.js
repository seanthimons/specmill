// Validates OpenAPI documents with the ajv build shipped in jsonvalidate.
// Expects the globals swagger20, oas30, oas31, dialect31 and meta31.
var options = {allErrors: true, strict: false, logger: false, verbose: true};

function draft04(schema) {
  var ajv = new AjvSchema4(options);
  addFormats(ajv);
  return ajv.compile(schema);
}

function resolve(node, pointer) {
  return pointer.split("/").slice(1).reduce(function (node, part) {
    return node == null ? node :
      node[part.replace(/~1/g, "/").replace(/~0/g, "~")];
  }, node);
}

function deref(root, node) {
  for (var i = 0; i < 20 && node && typeof node.$ref === "string" &&
    node.$ref.indexOf("#/") === 0; i++) {
    node = resolve(root, node.$ref.slice(1));
  }
  return node;
}

// Values a oneOf branch accepts for `key`: its enum, or the values of its own
// keyed oneOf branches.
function key_values(root, branch, key) {
  var node = deref(root, branch);
  if (!node || typeof node !== "object") return null;
  var property = node.properties && node.properties[key];
  if (property && Array.isArray(property.enum)) return property.enum;
  if (!Array.isArray(node.oneOf)) return null;
  var values = [];
  for (var i = 0; i < node.oneOf.length; i++) {
    var nested = key_values(root, node.oneOf[i], key);
    if (!nested) return null;
    values = values.concat(nested);
  }
  return values;
}

function requires(root, branch, key) {
  var node = deref(root, branch);
  return !!node && (node.required || []).indexOf(key) >= 0;
}

// Finds the property that selects a oneOf branch: a Reference's `$ref`, or a
// key whose enum values are disjoint across branches. One branch may be the
// fallback for instances no other branch claims.
function selector(root, branches) {
  var references = branches.filter(function (b) {
    return requires(root, b, "$ref");
  });
  if (branches.length === 2 && references.length === 1) {
    return {key: "$ref", groups: [{values: null, branches: references}],
      fallback: branches[1 - branches.indexOf(references[0])]};
  }
  var keys = ["in", "type"];
  branches.forEach(function (b) {
    var node = deref(root, b);
    Object.keys((node && node.properties) || {}).forEach(function (key) {
      if (keys.indexOf(key) < 0) keys.push(key);
    });
  });
  for (var k = 0; k < keys.length; k++) {
    var key = keys[k], groups = [], fallback = null, claimed = {}, ok = true;
    branches.forEach(function (b) {
      var values = key_values(root, b, key);
      if (!values) {
        if (fallback) ok = false;
        fallback = b;
        return;
      }
      var id = JSON.stringify(values.slice().sort());
      var group = groups.filter(function (g) { return g.id === id; })[0];
      if (!group) {
        values.forEach(function (v) {
          if (claimed[JSON.stringify(v)]) ok = false;
          claimed[JSON.stringify(v)] = true;
        });
        group = {id: id, values: values, branches: []};
        groups.push(group);
      }
      group.branches.push(b);
    });
    if (ok && groups.length + (fallback ? 1 : 0) > 1) {
      return {key: key, groups: groups, fallback: fallback};
    }
  }
  return null;
}

function guard(key, values) {
  if (key === "$ref") return {required: ["$ref"]};
  var properties = {};
  properties[key] = {enum: values};
  return {required: [key], properties: properties};
}

// A failing oneOf reports every branch's errors, burying the real one. Rewrite
// keyed oneOfs so only the branch the instance selects is checked. Guards are
// tagged so clean() can drop their errors.
function rewrite(root, node) {
  if (Array.isArray(node)) {
    node.forEach(function (child) { rewrite(root, child); });
    return;
  }
  if (!node || typeof node !== "object") return;
  var plan = Array.isArray(node.oneOf) && selector(root, node.oneOf);
  if (plan) {
    var tests = [], parts = [], union = [];
    plan.groups.forEach(function (group) {
      var test = guard(plan.key, group.values);
      tests.push(test);
      union = union.concat(group.values || []);
      parts.push({anyOf: [{not: test, "x-guard": true}, group.branches.length === 1 ?
        group.branches[0] : {oneOf: group.branches}]});
    });
    if (plan.fallback) {
      parts.push({anyOf: [{not: {not: {anyOf: tests}}, "x-guard": true},
        plan.fallback]});
    } else {
      var check = guard(plan.key, union);
      if (!node.oneOf.every(function (b) { return requires(root, b, plan.key); })) {
        delete check.required;
      }
      parts.unshift(check);
    }
    node.allOf = (node.allOf || []).concat(parts);
    delete node.oneOf;
  }
  Object.keys(node).forEach(function (key) { rewrite(root, node[key]); });
}

function diagnostic(schema) {
  var copy = JSON.parse(JSON.stringify(schema));
  rewrite(schema, copy);
  return draft04(copy);
}

var ajv2020 = new AjvSchema2020(options);
addFormats(ajv2020);
ajv2020.addFormat("media-range", true);
ajv2020.addSchema(dialect31);
ajv2020.addSchema(meta31);

// The official schema decides validity; the rewritten one only explains it.
// OAS 3.1 already selects branches with if/then.
var validators = {
  "2.0": [draft04(swagger20), diagnostic(swagger20)],
  "3.0": [draft04(oas30), diagnostic(oas30)],
  "3.1": [ajv2020.compile(oas31)]
};

function clean(errors) {
  var combinators = ["oneOf", "anyOf", "if", "$ref"];
  errors = errors.filter(function (a) {
    return combinators.indexOf(a.keyword) < 0 &&
      !(a.parentSchema && a.parentSchema["x-guard"]);
  });
  // `type` and `not` errors restate a more specific error at the same place,
  // such as the enum of an anyOf over `type`.
  var vague = ["type", "not"];
  errors = errors.filter(function (a) {
    return vague.indexOf(a.keyword) < 0 || !errors.some(function (b) {
      return vague.indexOf(b.keyword) < 0 && b.instancePath === a.instancePath;
    });
  });
  // Ancestor errors only restate a deeper failure in the same subtree.
  errors = errors.filter(function (a) {
    return !errors.some(function (b) {
      return b.instancePath.indexOf(a.instancePath + "/") === 0;
    });
  });
  var seen = {}, out = [];
  errors.forEach(function (a) {
    var detail = a.params.allowedValues || a.params.additionalProperty ||
      a.params.unevaluatedProperty;
    var message = a.message + (detail === undefined ? "" :
      ": " + [].concat(detail).join(", "));
    if (a.keyword === "not") {
      message = a.schema && Array.isArray(a.schema.required) ?
        "must not define both " + a.schema.required.join(" and ") :
        "must NOT be valid against " + JSON.stringify(a.schema);
    }
    var key = a.instancePath + " " + message;
    if (!seen[key]) {
      seen[key] = true;
      out.push({pointer: a.instancePath, message: message});
    }
  });
  return out;
}

function validate_document(version, document) {
  var official = validators[version][0], explain = validators[version][1];
  if (official(document)) return [];
  if (explain && !explain(document)) {
    var detailed = clean(explain.errors);
    if (detailed.length) return detailed;
  }
  var errors = clean(official.errors);
  // An invalid document always yields a finding; unlocated ones block it.
  return errors.length ? errors :
    [{pointer: "", message: "does not conform to the OpenAPI schema"}];
}
