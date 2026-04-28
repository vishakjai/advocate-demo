local array = import './array.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testCompactEmptyArray: {
    actual: array.compact([]),
    expect: [],
  },
  testCompactFlatArray: {
    actual: array.compact([1, 2, 3]),
    expect: [1, 2, 3],
  },
  testCompactNestedArray: {
    actual: array.compact([1, [2, 3]]),
    expect: [1, 2, 3],
  },
  testCompactMultipleNestedArrays: {
    actual: array.compact([[1], [2, 3], [], [null]]),
    expect: [1, 2, 3],
  },
  testCompactDeepNestedArrays: {
    actual: array.compact([[1], 2, [3, [4, [5], []], []]]),
    expect: [1, 2, 3, 4, 5],
  },
  testCompactNullValue: {
    actual: array.compact(null),
    expect: [],
  },
})
