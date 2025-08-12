// main template for cloudscale-loadbalancer-controller
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.cloudscale_loadbalancer_controller;
local isOpenshift = std.member([ 'openshift4', 'oke' ], inv.parameters.facts.distribution);

local namespace = {
  apiVersion: 'v1',
  kind: 'Namespace',
  metadata: {
    labels: {
      'app.kubernetes.io/name': params.namespace,
      name: params.namespace,
      // Configure the namespaces so that the OCP4 cluster-monitoring
      // Prometheus can find the servicemonitors and rules.
      [if isOpenshift then 'openshift.io/cluster-monitoring']: 'true',
    },
    name: params.namespace,
  },
};

local secret = function(name) {
  apiVersion: 'v1',
  kind: 'Secret',
  metadata: {
    name: name,
    namespace: params.namespace,
  },
};

local loadbalancers = [
  {
    local value = params.loadbalancers[name],
    apiVersion: 'cloudscale.appuio.io/v1beta1',
    kind: 'LoadBalancer',
    metadata: {
      name: name,
      namespace: params.namespace,
    },
    spec+: {
      _pools+:: [],
      pools+: [
        value.spec._pools[poolName] {
          name: poolName,
        }
        for poolName in std.objectFields(value.spec._pools)
      ],
    },
  }
  for name in std.objectFields(params.loadbalancers)
];

local secrets = com.generateResources(params.secrets, secret);

// Define outputs below
{
  '00_namespace': namespace,
  '10_secrets': secrets,
  '20_loadbalancers': loadbalancers,
}
