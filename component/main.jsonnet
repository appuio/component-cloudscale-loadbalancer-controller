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

local LoadBalancer(name) = {
  apiVersion: 'cloudscale.appuio.io/v1beta1',
  kind: 'LoadBalancer',
  metadata: {
    name: name,
    namespace: params.namespace,
  },
  spec+: {
    local this = self,
    _pools+:: {},
    _floatingIPAddresses+:: {},
    floatingIPAddresses+: [
      { cidr: '%(address)s/%(prefixlength)d' % this._floatingIPAddresses[name] }
      for name in std.objectFields(self._floatingIPAddresses)
      if
        std.isObject(self._floatingIPAddresses[name]) &&
        !std.member([ null, '' ], self._floatingIPAddresses[name].address)
    ],
    pools+: [
      self._pools[poolName] {
        name: poolName,
      }
      for poolName in std.objectFields(self._pools)
    ],
  },
};

// NOTE(sg): We need to remove duplicates after the call to
// `com.generateResources()`, since doing this snippet in `LoadBalancer(name)`
// doesn't see floating IPs configured via `_floatingIPAddresses` due to how
// layered objects work in Jsonnet.
local removeDuplicateFloatingIPAddresses(lb) = lb {
  spec+: {
    floatingIPAddresses: std.uniq(std.sort(
      super.floatingIPAddresses, function(it) it.cidr
    )),
  },
};

local loadbalancers = std.map(
  removeDuplicateFloatingIPAddresses,
  com.generateResources(params.loadbalancers, LoadBalancer)
);

local secrets = com.generateResources(params.secrets, secret);

// Define outputs below
{
  '00_namespace': namespace,
  '10_secrets': secrets,
  '20_loadbalancers': loadbalancers,
}
