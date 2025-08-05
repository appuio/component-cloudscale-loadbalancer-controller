// main template for cloudscale-loadbalancer-controller
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.cloudscale_loadbalancer_controller;

// Define outputs below
{
}
