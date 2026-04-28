// Unfortunately the GitLab Workhorse reverse-proxy emits route labels as regular expressions.
// This is extremely painful to use, since proper escaping needs to be done for
// Jsonnet, Prometheus, then more escaping for PromQL regex matches.
// This is an awful way of emitting labels, and until it's fixed, we prefer
// keeping the black-magic of escaping these route expressions tightly confined to a
// single module.

// This module relies on the natives shipped as part of jsonnet-tool and tenctl:
// https://gitlab.com/gitlab-com/gl-infra/jsonnet-tool/-/tree/main/pkg/natives
local regex = {
  // escapeStringRegex(string s) string
  // escapeStringRegex escapes all regular expression metacharacters and returns a regular expression that matches the literal text.
  escapeStringRegex: std.native('escapeStringRegex'),
};

// Converts mutli-line routes into an array of trimmed strings
local convertMultilineRoutesToArray(s) =
  local splits = std.split(s, '\n');
  local trimmed = std.map(function(f) std.stripChars(f, ' \t\n'), splits);
  std.filter(function(f) f != '', trimmed);

local escapeWorkhorseRouteRegexp(s) =
  local f1 = regex.escapeStringRegex(s);
  std.strReplace(f1, '\\', '\\\\');

local escapeWorkhorseRouteLiteral(s) =
  std.strReplace(s, '\\', '\\\\');

{
  // Escape a string which is suitable for a regular expression
  // =~ or !~ selector expression in PromQL
  // Supports both arrays or single string values
  escapeForRegexp(input)::
    local routes = convertMultilineRoutesToArray(input);
    std.map(escapeWorkhorseRouteRegexp, routes),

  // Escape a string which is suitable for an equal or not-equal
  // = or != selector expression in PromQL
  // Supports both arrays or single string values
  escapeForLiterals(input)::
    local routes = convertMultilineRoutesToArray(input);
    std.map(escapeWorkhorseRouteLiteral, routes),
}
