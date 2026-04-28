local underTest = import './wilson-score.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';
local strings = import 'utils/strings.libsonnet';

test.suite({
  testBasicLower: {
    actual: strings.chomp(underTest.lower(scoreRate='score', totalRate='total', windowInSeconds=3600, confidence='95%')),
    expect: strings.chomp(|||
      (total == 0)
      or
      clamp(
        (
          (
            (score / total)
            +
            3.841459 / (2 * (total * 3600))
          )
          -
          1.959964
          *
          sqrt(
            (
              (score / total) * (1 - (score / total))
              +
              3.841459 / (4 * (total * 3600))
            )
            /
            (total * 3600)
          )
        )
        /
        (1 + 3.841459 / (total * 3600)),
        0, 1
      )
    |||),
  },
  testBasicUpper: {
    actual: strings.chomp(underTest.upper(scoreRate='score', totalRate='total', windowInSeconds=3600, confidence='95%')),
    expect: strings.chomp(|||
      clamp_min(total == 0, 1)
      or
      clamp(
        (
          (
            (score / total)
            +
            3.841459 / (2 * (total * 3600))
          )
          +
          1.959964
          *
          sqrt(
            (
              (score / total) * (1 - (score / total))
              +
              3.841459 / (4 * (total * 3600))
            )
            /
            (total * 3600)
          )
        )
        /
        (1 + 3.841459 / (total * 3600)),
        0, 1
      )
    |||),
  },
  testApdexUpper: {
    actual: strings.chomp(underTest.upper(scoreRate='gitlab_component_apdex:success:rate_1h', totalRate='gitlab_component_apdex:weight:score_1h', windowInSeconds=3600, confidence='95%')),
    expect: strings.chomp(|||
      clamp_min(gitlab_component_apdex:weight:score_1h == 0, 1)
      or
      clamp(
        (
          (
            (gitlab_component_apdex:success:rate_1h / gitlab_component_apdex:weight:score_1h)
            +
            3.841459 / (2 * (gitlab_component_apdex:weight:score_1h * 3600))
          )
          +
          1.959964
          *
          sqrt(
            (
              (gitlab_component_apdex:success:rate_1h / gitlab_component_apdex:weight:score_1h) * (1 - (gitlab_component_apdex:success:rate_1h / gitlab_component_apdex:weight:score_1h))
              +
              3.841459 / (4 * (gitlab_component_apdex:weight:score_1h * 3600))
            )
            /
            (gitlab_component_apdex:weight:score_1h * 3600)
          )
        )
        /
        (1 + 3.841459 / (gitlab_component_apdex:weight:score_1h * 3600)),
        0, 1
      )
    |||),
  },
  testErrorLower: {
    actual: strings.chomp(underTest.lower(scoreRate='gitlab_component_errors:rate_1h', totalRate='gitlab_component_ops:rate_1h', windowInSeconds=3600, confidence='95%')),
    expect: strings.chomp(|||
      (gitlab_component_ops:rate_1h == 0)
      or
      clamp(
        (
          (
            (gitlab_component_errors:rate_1h / gitlab_component_ops:rate_1h)
            +
            3.841459 / (2 * (gitlab_component_ops:rate_1h * 3600))
          )
          -
          1.959964
          *
          sqrt(
            (
              (gitlab_component_errors:rate_1h / gitlab_component_ops:rate_1h) * (1 - (gitlab_component_errors:rate_1h / gitlab_component_ops:rate_1h))
              +
              3.841459 / (4 * (gitlab_component_ops:rate_1h * 3600))
            )
            /
            (gitlab_component_ops:rate_1h * 3600)
          )
        )
        /
        (1 + 3.841459 / (gitlab_component_ops:rate_1h * 3600)),
        0, 1
      )
    |||),
  },
  testDedicated: {
    actual: strings.chomp(underTest.upper(scoreRate='gitlab_component_apdex:success:rate_5m{component="grpc_requests",type="gitlab-shell"}', totalRate='gitlab_component_apdex:weight:score_5m{component="grpc_requests",type="gitlab-shell"}', windowInSeconds=300, confidence='98%')),
    expect: strings.chomp(|||
      clamp_min(gitlab_component_apdex:weight:score_5m{component="grpc_requests",type="gitlab-shell"} == 0, 1)
      or
      clamp(
        (
          (
            (gitlab_component_apdex:success:rate_5m{component="grpc_requests",type="gitlab-shell"} / gitlab_component_apdex:weight:score_5m{component="grpc_requests",type="gitlab-shell"})
            +
            5.411894 / (2 * (gitlab_component_apdex:weight:score_5m{component="grpc_requests",type="gitlab-shell"} * 300))
          )
          +
          2.326348
          *
          sqrt(
            (
              (gitlab_component_apdex:success:rate_5m{component="grpc_requests",type="gitlab-shell"} / gitlab_component_apdex:weight:score_5m{component="grpc_requests",type="gitlab-shell"}) * (1 - (gitlab_component_apdex:success:rate_5m{component="grpc_requests",type="gitlab-shell"} / gitlab_component_apdex:weight:score_5m{component="grpc_requests",type="gitlab-shell"}))
              +
              5.411894 / (4 * (gitlab_component_apdex:weight:score_5m{component="grpc_requests",type="gitlab-shell"} * 300))
            )
            /
            (gitlab_component_apdex:weight:score_5m{component="grpc_requests",type="gitlab-shell"} * 300)
          )
        )
        /
        (1 + 5.411894 / (gitlab_component_apdex:weight:score_5m{component="grpc_requests",type="gitlab-shell"} * 300)),
        0, 1
      )
    |||),
  },
  testWithGrafanaVariables: {
    actual: strings.chomp(underTest.lower(scoreRate='score', totalRate='total', windowInSeconds=3600, confidence='$confidence', confidenceIsZScore=true)),
    expect: strings.chomp(|||
      (total == 0)
      or
      clamp(
        (
          (
            (score / total)
            +
            ($confidence * $confidence) / (2 * (total * 3600))
          )
          -
          $confidence
          *
          sqrt(
            (
              (score / total) * (1 - (score / total))
              +
              ($confidence * $confidence) / (4 * (total * 3600))
            )
            /
            (total * 3600)
          )
        )
        /
        (1 + ($confidence * $confidence) / (total * 3600)),
        0, 1
      )
    |||),
  },
})
