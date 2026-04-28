local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local labelTaxonomy = import 'label-taxonomy/label-taxonomy.libsonnet';

{
  disk_maximum_capacity: resourceSaturationPoint({
    title: 'Maximum per-disk capacity',
    severity: 's1',
    horizontallyScalable: false,
    appliesTo: metricsCatalog.findVMProvisionedServices(),
    description: |||
      The maximum capacity for a single disk can be limited by the cloud provider.
      This tracks the saturation as a ratio of the storage utilization to the maximum size limit enforced per disk.

      In order to resolve a saturation alert, storage needed on a single disk needs to be reduced.
      Possible ways of doing this include reducing utilization overall or partitioning data across multiple disks.

      This excludes nodes that already have LVM devices defined, those can be aggregated into logical volumes that can be grown.
      The tracking of a logical volume is done using the `disk_space` saturation point.

      (64*2^40) = 64TiB is the maximum value for many types of GCP disks, see https://cloud.google.com/compute/docs/disks#introduction.
    |||,
    grafana_dashboard_uid: 'sat_gcp_maximum_disk_capacity',
    resourceLabels: [labelTaxonomy.getLabelFor(labelTaxonomy.labels.shard), labelTaxonomy.getLabelFor(labelTaxonomy.labels.node), 'device'],
    burnRatePeriod: '5m',
    query: |||
      max by (%(aggregationLabels)s) (
        node_filesystem_size_bytes{fstype=~"ext.|xfs", %(selector)s} - node_filesystem_avail_bytes{fstype=~"ext.|xfs", %(selector)s}
        unless on (fqdn) node_disk_info{serial=~"lvm.*", %(selector)s}
      ) / (64*2^40)
    |||,
    slos: {
      soft: 0.70,
      hard: 0.95,
    },
    capacityPlanning: {
      forecast_days: 180,
      saturation_dimensions: [
        { selector: selectors.serializeHash({ shard: 'backup', type: { re: 'patroni.*' } }) },
        { selector: selectors.serializeHash({ shard: { ne: 'backup' }, type: { re: 'patroni.*' } }) },
        { selector: selectors.serializeHash({ type: { nre: 'patroni.*' } }) },
      ],
      saturation_dimensions_keep_aggregate: false,
      changepoint_range: 0.8,  // Less reactive to recent changes in trend, as this is a long-term metric
      strategy: 'quantile99_1w',
    },
  }),
}
