local toolingLinkDefinition = (import './tooling_link_definition.libsonnet').toolingLinkDefinition({ tool:: 'grafana', type:: 'dashboard' });

local mapVars(vars) =
  local varsMapped = [
    'var-%(key)s=%(value)s' % { key: key, value: vars[key] }
    for key in std.objectFields(vars)
  ];
  std.join('&', varsMapped);

local urlFromUidAndVars(dashboardUid, vars) =
  '/d/%(dashboardUid)s?%(vars)s' % {
    dashboardUid: dashboardUid,
    vars: mapVars(vars),
  };

{
  grafanaUid(path)::
    local parts = std.split(path, '/');

    assert std.length(parts) == 2 && std.endsWith(parts[1], '.jsonnet') :
           "Invalid dashboard path: '%s'. Valid path syntax: folder/dashboard-name.jsonnet";

    local folder = parts[0];
    local maxLength = 40 - std.length(folder) - 1;
    local names = std.split(parts[1], '.');
    local basename = std.substr(names[0], 0, maxLength);

    '%(folder)s-%(basename)s' % {
      folder: folder,
      basename: basename,
    },

  grafana(title, dashboardUid, vars={})::
    function(options)
      [
        toolingLinkDefinition({
          title: 'Grafana: ' + title,
          url: urlFromUidAndVars(dashboardUid, vars),
        }),
      ],
}
