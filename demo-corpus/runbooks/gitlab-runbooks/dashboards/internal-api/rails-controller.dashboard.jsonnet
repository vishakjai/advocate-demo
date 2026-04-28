local railsController = import 'gitlab-dashboards/rails_controller_common.libsonnet';

railsController.dashboard(type='internal-api', defaultController='Grape', defaultAction='GET /api/projects')
