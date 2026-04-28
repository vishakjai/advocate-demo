// Upstream PR https://github.com/google/jsonnet/pull/1082
// Transforms nested arrays into a single flattened array, removing null values.
local compact(arrs) =
  if arrs == null then
    []
  else
    local foldable = function(accumulator, value)
      if std.isArray(value) then
        accumulator + compact(value)
      else if value == null then
        accumulator
      else
        accumulator + [value];

    std.foldl(foldable, arrs, []);

{
  compact:: compact,
}
