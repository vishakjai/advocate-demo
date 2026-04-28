local all = import './services/all.jsonnet';

std.map(function(service) service.type, all)
