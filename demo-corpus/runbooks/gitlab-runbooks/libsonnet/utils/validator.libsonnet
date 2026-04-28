// Recursively validate an object using the provided definition
local validateNested(prefix, definition, object) =
  if object == null then
    ['field %s: expected an object' % [std.join('.', prefix)]]
  else
    std.flatMap(
      function(field)
        local fullField = std.join('.', prefix + [field]);
        local validator = definition[field];

        if std.objectHas(object, field) then
          if std.isObject(validator) then
            // Recursively validate
            validateNested(prefix + [field], validator, object[field])
          else
            local failureMessage = validator(object[field]);
            if failureMessage == null then
              /* success! */
              []
            else
              ['field %s: %s' % [fullField, failureMessage]]
        else
          local isOptional = std.isFunction(validator) && validator(null) == null;
          if isOptional then
            []
          else
            ['field %s is required' % [fullField]],
      std.objectFields(definition)
    );

// Returns a validator function
local newValidator(definition) =
  {
    /** For testing purposes only */
    _validationMessages(object)::
      validateNested([], definition, object),

    isValid(object)::
      local messages = validateNested([], definition, object);
      std.length(messages) == 0,

    assertValid(object)::
      local messages = validateNested([], definition, object);
      if std.length(messages) == 0 then
        object
      else
        local traceMessage = |||
          VALIDATION FAILURE:
          -------------------
          %s
        ||| % [std.join('\n', messages)];

        std.assertEqual(std.trace(traceMessage, object), { __assert: messages }),
  };

// Create a field validator function
local validator(fn, message) =
  function(v)
    if fn(v) then null else message;

local or(validatorA, validatorB) =
  function(v)
    local a = validatorA(v);
    local b = validatorB(v);
    if a == null || b == null then
      null
    else
      '%s or %s' % [a, b];

local and(validatorA, validatorB) =
  function(v)
    local a = validatorA(v);
    local b = validatorB(v);
    if a == null then
      if b == null then null else b
    else a;

// Optional means that value can be null
// if its not null, we delegate to the underlying validator
local optional(validator) =
  function(v)
    if v == null then
      null
    else
      local result = validator(v);
      if result == null then
        null
      else
        // Extend the message to include the null optional
        result + ' or null';

local durationSuffixes = std.set(std.stringChars('wdhms'));
local isDuration(v) =
  local len = std.length(v);
  std.isString(v) && len >= 2 &&
  // Validate that all characters are valid
  std.all(
    // Check that each character is valid given its position in the string
    // My kingdom for a regexp
    std.mapWithIndex(
      function(index, c)
        if index == len - 1 then
          std.setMember(c, durationSuffixes)
        else
          c >= '0' && c <= '9',
      std.stringChars(v)
    )
  );

local isArrayOfStrings(v) =
  std.isArray(v) && std.foldl(function(memo, e) memo && std.isString(e), v, true);

{
  new:: newValidator,
  array:: validator(std.isArray, 'expected an array'),
  boolean:: validator(std.isBoolean, 'expected an boolean'),
  func:: validator(std.isFunction, 'expected a function'),
  number:: validator(std.isNumber, 'expected a number'),
  object:: validator(std.isObject, 'expected an object'),
  string:: validator(std.isString, 'expected a string'),
  duration:: validator(isDuration, 'expected a promql duration'),
  arrayOfStrings:: validator(isArrayOfStrings, 'expected an array of strings'),
  optional:: optional,
  or:: or,
  and:: and,
  setMember(set):: validator(function(v) std.setMember(v, set), 'value not in valid set: %s' % [set]),
  validator:: validator,
}
