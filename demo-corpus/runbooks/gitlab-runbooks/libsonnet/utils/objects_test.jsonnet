local objects = import './objects.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testFromPairs: {
    actual: objects.fromPairs([['a', 1], ['b', [2, 3]], ['c', { d: 4 }]]),
    expect: { a: 1, b: [2, 3], c: { d: 4 } },
  },
  testFromPairsIntegerKeys: {
    actual: objects.fromPairs([[1, 1], [2, [2, 3]], [3, { d: 4 }]]),
    expect: { '1': 1, '2': [2, 3], '3': { d: 4 } },
  },
  testFromPairsDuplicateKeys: {
    actual: objects.fromPairs([[1, 1], [2, [2, 3]], [1, { d: 4 }]]),
    expect: { '1': 1, '2': [2, 3] },
  },
  testObjectWithout: {
    actual: objects.objectWithout({ hello: 'world', foo: 'bar', baz:: 'hi' }, 'foo'),
    expect: { hello: 'world', baz:: 'hi' },
  },
  testObjectWithoutIncHiddenFunction: {
    local testThing = { hello(world):: [world] },
    actual: objects.objectWithout(testThing { foo: 'bar' }, 'foo').hello('world'),
    expect: ['world'],
  },
  testFromPairsRoundTrip: {
    actual: objects.fromPairs(objects.toPairs({ '1': 1, '2': [2, 3], '3': { d: 4 } })),
    expect: { '1': 1, '2': [2, 3], '3': { d: 4 } },
  },
  testToPairs: {
    actual: objects.toPairs({ a: 1, b: [2, 3], c: { d: 4 } }),
    expect: [['a', 1], ['b', [2, 3]], ['c', { d: 4 }]],
  },
  testToPairsRoundTrip: {
    actual: objects.toPairs(objects.fromPairs([['a', 1], ['b', [2, 3]], ['c', { d: 4 }]])),
    expect: [['a', 1], ['b', [2, 3]], ['c', { d: 4 }]],
  },
  testMergeAllTrivial: {
    actual: objects.mergeAll([]),
    expect: {},
  },
  testMergeAllWithoutClashes: {
    actual: objects.mergeAll([{ a: 1 }, { b: 'b' }, { c: { d: 1 } }]),
    expect: {
      a: 1,
      b: 'b',
      c: { d: 1 },
    },
  },
  testMergeAllWithClashes: {
    actual: objects.mergeAll([{ a: { a: 1, d: 1 } }, { a: { c: 1, d: 2 } }]),
    expect: {
      a: { c: 1, d: 2 },
    },
  },

  testMapKeyValues: {
    actual: objects.mapKeyValues(function(key, value) [key + 'a', value + 1], { a: 1, b: 2, c: 3 }),
    expect: {
      aa: 2,
      ba: 3,
      ca: 4,
    },
  },

  testMapKeyValuesOmit: {
    actual: objects.mapKeyValues(function(key, value) null, { a: 1, b: 2, c: 3 }),
    expect: {},
  },

  testTransformKeys: {
    actual: objects.transformKeys(
      function(key)
        if key == 'remove-me' then null else '%s-transformed' % [key],
      { a: 1, b: 2, 'remove-me': 3, c: 4 }
    ),
    expect: {
      'a-transformed': 1,
      'b-transformed': 2,
      'c-transformed': 4,
    },
  },

  testInvert: {
    actual: objects.invert({ a: 1, b: 2 }),
    expect: { '1': 'a', '2': 'b' },
  },
  testInvertDuplicates: {
    actual: objects.invert({ a: '', b: '', c: 3, d: '', e: '' }),
    expect: { '': ['a', 'b', 'd', 'e'], '3': 'c' },
  },

  testNestedMergeMultipleLevels: {
    local objectA = { a: { b: { c: { d: 0 } } } },
    local objectB = { a: { b: { c: { f: 1 }, g: 2 }, h: 3 } },
    actual: objects.nestedMerge(objectA, objectB),
    expect: { a: { b: { c: { d: 0, f: 1 }, g: 2 }, h: 3 } },
  },
  testAbsenseOfAttributesOnTarget: {
    local objectA = { z: 'z', y: 'y' },
    local objectB = { a: { b: 1 }, c: 2 },
    actual: objects.nestedMerge(objectA, objectB),
    expect: { a: { b: 1 }, c: 2, z: 'z', y: 'y' },
  },
  testNestedMergeWithMethods: {
    local objectA = {
      a: 1,
      methodA(var):: var + self.a,
      overrideMe(var)::
        assert false : 'This is never called';
        var,
    },
    local objectB = {
      b: 2,
      methodB(var):: var + self.b,
      overrideMe(var):: 'Overridden: ' + var,
    },
    actual: objects.nestedMerge(objectA, objectB),
    expectThat: {
      result:
        self.actual.a == 1 &&
        self.actual.b == 2 &&
        self.actual.methodA('varA') == 'varA1' &&
        self.actual.methodB('varB') == 'varB2' &&
        self.actual.overrideMe('var') == 'Overridden: var',
    },
  },
  testNestedMergeIncompatibleTypeOverrideWins: {
    local objectA = { a: 'hello', b: { foo: 'bar', double: { a: 'a' } } },
    local objectB = { a: ['world'], b: { bar: 'baz', double: { b: 'b' } } },
    actual: objects.nestedMerge(objectA, objectB),
    expect: { a: ['world'], b: { bar: 'baz', double: { a: 'a', b: 'b' }, foo: 'bar' } },
  },
})
