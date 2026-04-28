local stageGroupDashboards = import './stage-group-dashboards.libsonnet';

stageGroupDashboards.dashboard('product_planning', ['web', 'sidekiq'])
.stageGroupDashboardTrailer()
