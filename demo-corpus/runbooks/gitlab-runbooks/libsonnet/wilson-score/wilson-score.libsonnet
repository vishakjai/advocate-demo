local strings = import 'utils/strings.libsonnet';

// Lookup from https://docs.google.com/spreadsheets/d/1Kpn7GZTJ280sRCbmC4T6bHixU1Q0biIH2DXhlskM2Mo/edit#gid=0
// https://www.statisticshowto.com/probability-and-statistics/find-critical-values/
local confidenceLookup =
  {
    '80%': 1.281551564,
    '85%': 1.439531472,
    '90%': 1.644853625,
    '95%': 1.959963986,
    '98%': 2.326347874,
    '99%': 2.575829306,
    '99.50%': 2.80703377,
    '99.95%': 3.4807564,
  };

local confidenceBoundaryExpression(isLowerBoundary, scoreRate, totalRate, windowInSeconds, confidence, confidenceIsZScore=false) =
  local z = if confidenceIsZScore then confidence else std.get(confidenceLookup, confidence, error 'Unknown confidence value ' + confidence);
  local zs = if std.isNumber(z) then '%f' % z else z;

  local zSquared = if std.isNumber(z) then '%f' % (z * z) else '(%s * %s)' % [z, z];

  // phat is a ratio in a Bernoulli trial process
  local phatExpression = '(%s / %s)' % [scoreRate, totalRate];

  // Convert from rate/second to total score over window period
  local scoreCountExpr = '(%s * %d)' % [scoreRate, windowInSeconds];
  local totalCountExpr = '(%s * %d)' % [totalRate, windowInSeconds];

  //  a = phat + z * z / (2 * total)
  local aExpr = |||
    (
      %(phatExpression)s
      +
      %(zSquared)s / (2 * %(totalCountExpr)s)
    )
  ||| % {
    phatExpression: strings.indent(phatExpression, 2),
    zSquared: zSquared,
    totalCountExpr: totalCountExpr,
  };

  // b = z * sqrt((phat * (1 - phat) + z * z / (4 * total)) / total);
  local bExpr =
    |||
      %(zs)s
      *
      sqrt(
        (
          %(phatExpression)s * (1 - %(phatExpression)s)
          +
          %(zSquared)s / (4 * %(totalCountExpr)s)
        )
        /
        %(totalCountExpr)s
      )
    ||| % {
      phatExpression: phatExpression,
      zs: zs,
      zSquared: zSquared,
      totalCountExpr: totalCountExpr,
    };

  local cExpr =
    |||
      (1 + %(zSquared)s / %(totalCountExpr)s)
    ||| % {
      zSquared: zSquared,
      totalCountExpr: totalCountExpr,
    };

  local operator = if isLowerBoundary then '-' else '+';

  local boundaryConditionExpr =
    if isLowerBoundary then
      // If totalCount == 0, then return 0 for lower boundary
      '(%s == 0)' % [totalRate]
    else
      // If totalCount == 0, then return 1 for upper boundary
      'clamp_min(%s == 0, 1)' % [totalRate];

  |||
    %(boundaryConditionExpr)s
    or
    clamp(
      (
        %(aExpr)s
        %(operator)s
        %(bExpr)s
      )
      /
      %(cExpr)s,
      0, 1
    )
  ||| % {
    boundaryConditionExpr: boundaryConditionExpr,
    operator: operator,
    aExpr: strings.indent(aExpr, 4),
    bExpr: strings.indent(bExpr, 4),
    cExpr: strings.indent(cExpr, 2),
  };

{
  /**
   * Given a score, total, window and confidence, produces a PromQL expression for the lower boundary
   * Wilson Score Interval
   */
  lower(scoreRate, totalRate, windowInSeconds, confidence, confidenceIsZScore=false):: confidenceBoundaryExpression(true, scoreRate, totalRate, windowInSeconds, confidence, confidenceIsZScore=confidenceIsZScore),

  /**
   * Given a score, total, window and confidence, produces a PromQL expression for the upper boundary
   * Wilson Score Interval
   */
  upper(scoreRate, totalRate, windowInSeconds, confidence, confidenceIsZScore=false):: confidenceBoundaryExpression(false, scoreRate, totalRate, windowInSeconds, confidence, confidenceIsZScore=confidenceIsZScore),

  confidenceLookup:: confidenceLookup,
}
