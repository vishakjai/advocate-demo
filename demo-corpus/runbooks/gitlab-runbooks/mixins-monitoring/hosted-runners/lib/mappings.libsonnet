local objectsMappings = import 'utils/objects.libsonnet';

local onlineStatusMappings = [
  {
    text: 'Online',
    color: 'green',
  },
  {
    text: 'Offline',
    color: 'red',
  },
  {
    text: 'Stale',
    color: 'orange',
  },
];

local concurrentMappings = [
  {
    text: 'Healthy',
    color: 'black',
  },
  {
    text: 'Degraded',
    color: 'red',
  },
];

local generateMappingValues(mappingList) =
  [{
    type: 'value',
    options: objectsMappings.fromPairs(
      std.mapWithIndex(
        function(index, v)
          [index, v { index: index }],
        mappingList
      )
    ),
  }];

{
  concurrentMappings:: generateMappingValues(concurrentMappings),
  onlineStatusMappings:: generateMappingValues(onlineStatusMappings),
}
