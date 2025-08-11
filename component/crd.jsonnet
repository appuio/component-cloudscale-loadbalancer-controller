local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();

// The hiera parameters for the component
local params = inv.parameters.cloudscale_loadbalancer_controller;

local crd = com.Kustomization(
  'https://github.com/appuio/cloudscale-loadbalancer-controller/config/crd',
  params.manifest_version,
);

crd
