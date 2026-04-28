local selectors = import 'promql/selectors.libsonnet';

local kubeNodeMachineFamilyResourceUsageRule(name, resource, selector) = {
  record: 'kube:node:machine_family_%s_per_1h' % name,
  expr: |||
    max_over_time(
        sum by (environment,env,provider,project,region,cluster,machine_family,provisioning,node_region,node_zone) (
            kube_node_status_capacity{%(selector)s}
            * on (environment,env,provider,region,cluster,node) group_left(machine_family,provisioning,node_region,node_zone) (
                max by (environment,env,provider,region,cluster,node,machine_family,provisioning,node_region,node_zone) (
                    label_replace(
                      label_replace(
                          label_replace(
                              label_replace(
                                  kube_node_labels,
                                  "machine_family", "$1", "label_cloud_google_com_machine_family", "(.*)"
                              ), "provisioning", "$1", "label_cloud_google_com_gke_provisioning", "(.*)"
                            ), "node_region", "$1", "label_topology_kubernetes_io_region", "(.*)"
                        ), "node_zone", "$1", "label_topology_kubernetes_io_zone", "(.*)"
                    )
                )
            )
            * on (environment,env,provider,region,cluster,node) group_left(project) (
                max by (environment,env,provider,region,cluster,node,project) (
                    label_replace(
                        kube_node_info,
                        "project", "$1", "provider_id", "gce://([^/]+)/.*"
                    )
                )
            )
        )[1h:1h]
    )
  ||| % {
    selector: selectors.serializeHash(selector {
      resource: resource,
    }),
  },
};

{
  kubeNodeResourceUsageRules(selector): {
    groups: [
      {
        name: 'Kube Node Resource Usage',
        interval: '1h',
        rules: [
          kubeNodeMachineFamilyResourceUsageRule('cpu_count', 'cpu', selector),
          kubeNodeMachineFamilyResourceUsageRule('memory_capacity', 'memory', selector),
        ],
      },
    ],
  },
}
