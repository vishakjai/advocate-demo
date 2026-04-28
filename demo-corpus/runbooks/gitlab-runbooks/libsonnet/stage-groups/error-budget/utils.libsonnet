local durationParser = import 'utils/duration-parser.libsonnet';
local strings = import 'utils/strings.libsonnet';

local dynamicRange = '$__range';
local isDynamicRange(range) = range == dynamicRange;

// We're calculating an absolute number of failures from a failure rate
// this means we don't have an exact precision, but only a request per second
// number that we turn into an absolute number. To display a number of requests
// over multiple days, the decimals don't matter anymore, so we're rounding them
// up using `ceil`.
//
// The per-second-rates are sampled every minute, we assume that we continue
// to receive the same number of requests per second until the next sample.
// So we multiply the rate by the number of samples we don't have.
// For example: the last sample said we were processing 2RPS, next time we'll
// take a sample will be in 60s, so in that time we assume to process
// 60 * 2 = 120 requests.
// https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/1123
local rateToOperationCount(query) =
  |||
    ceil(
      (
        %(query)s
      ) * 60
    )
  ||| % {
    query: strings.indent(strings.chomp(query), 4),
  };

{
  dynamicRange: dynamicRange,
  isDynamicRange: isDynamicRange,
  rangeInSeconds(range):
    if isDynamicRange(range) then
      '$__range_s'
    else
      durationParser.toSeconds(range),
  budgetSeconds(slaTarget, range):
    if isDynamicRange(range) then
      '(1 - %(slaTarget).4f) * $__range_s' % slaTarget
    else
      (1 - slaTarget) * durationParser.toSeconds(range),
  budgetMinutes(slaTarget, range):
    if isDynamicRange(range) then
      '(1 - %(slaTarget).4f) * $__range_s / 60.0' % slaTarget
    else
      (1 - slaTarget) * durationParser.toSeconds(range) / 60.0,
  rateToOperationCount: rateToOperationCount,
}
