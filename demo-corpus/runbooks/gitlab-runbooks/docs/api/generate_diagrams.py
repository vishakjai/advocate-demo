# Instructions at https://diagrams.mingrammer.com/docs/guides/diagram
# Required components at https://diagrams.mingrammer.com/docs/getting-started/installation
# to generate diagrams use `make diagrams`

from diagrams import Diagram, Edge, Cluster
from diagrams.k8s.compute import Deployment
from diagrams.k8s.clusterconfig import HPA
from diagrams.k8s.network import Ingress
from diagrams.k8s.network import Service
from diagrams.onprem.container import Docker

graph_attr = {
  "layout":"dot",
  "compound":"true",
  "splines":"spline",
  "labelloc": "t",
}

with Diagram("API Service Kubernetes Deployment", show=True, direction="LR", graph_attr = graph_attr):
    service = Service("webservice-api Service")

    Ingress("webservice-api Ingress") \
      >> Edge(label="Path '/'") \
      >> service

    with Cluster("API Deployment"):
      deployment = Deployment("webservice-api Deployment")
      service >> deployment
      deployment >> Docker("webservice Container")
      deployment >> Docker("gitlab-workhorse Container")

    HPA("webservice-api HPA") >> deployment
