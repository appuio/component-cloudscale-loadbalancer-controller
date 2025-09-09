local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();

// The hiera parameters for the component
local params = inv.parameters.cloudscale_loadbalancer_controller;

// CRDs

local crd = com.Kustomization(
  'https://github.com/appuio/cloudscale-loadbalancer-controller/config/crd',
  params.manifest_version,
);

// Controller

local cloudscale_loadbalancer_controller = com.Kustomization(
  'https://github.com/appuio/cloudscale-loadbalancer-controller/config/default',
  params.manifest_version,
  {
    'ghcr.io/appuio/cloudscale-loadbalancer-controller': {
      newTag: params.images.cloudscale_loadbalancer_controller.tag,
      newName: '%(registry)s/%(repository)s' % params.images.cloudscale_loadbalancer_controller,
    },
  },
  {
    resources: [
      'https://raw.githubusercontent.com/appuio/cloudscale-loadbalancer-controller/%s/config/rbac/loadbalancer_viewer_role.yaml' % [ params.manifest_version ],
    ],
    // Inner kustomization layers are immutable, so we need to re-replace the namespace after changing it in an outer layer
    replacements: [
      {
        source: {
          kind: 'Service',
          version: 'v1',
          name: 'metrics-service',
          fieldPath: 'metadata.name',
        },
        targets: [
          {
            select: {
              kind: 'Certificate',
              group: 'cert-manager.io',
              version: 'v1',
              name: 'metrics-certs',
            },
            fieldPaths: [
              'spec.dnsNames.0',
              'spec.dnsNames.1',
            ],
            options: {
              delimiter: '.',
              index: 0,
              create: true,
            },
          },
          {
            select: {
              kind: 'ServiceMonitor',
              group: 'monitoring.coreos.com',
              version: 'v1',
              name: 'controller-manager-metrics-monitor',
            },
            fieldPaths: [
              'spec.endpoints.0.tlsConfig.serverName',
            ],
            options: {
              delimiter: '.',
              index: 0,
              create: true,
            },
          },
        ],
      },
      {
        source: {
          kind: 'Service',
          version: 'v1',
          name: 'metrics-service',
          fieldPath: 'metadata.namespace',
        },
        targets: [
          {
            select: {
              kind: 'Certificate',
              group: 'cert-manager.io',
              version: 'v1',
              name: 'metrics-certs',
            },
            fieldPaths: [
              'spec.dnsNames.0',
              'spec.dnsNames.1',
            ],
            options: {
              delimiter: '.',
              index: 1,
              create: true,
            },
          },
          {
            select: {
              kind: 'ServiceMonitor',
              group: 'monitoring.coreos.com',
              version: 'v1',
              name: 'controller-manager-metrics-monitor',
            },
            fieldPaths: [
              'spec.endpoints.0.tlsConfig.serverName',
            ],
            options: {
              delimiter: '.',
              index: 1,
              create: true,
            },
          },
        ],
      },
      {
        source: {
          kind: 'Service',
          version: 'v1',
          name: 'cloudscale-loadbalancer-controller-webhook-service',
          fieldPath: '.metadata.namespace',
        },
        targets: [
          {
            select: {
              kind: 'Certificate',
              group: 'cert-manager.io',
              version: 'v1',
              name: 'cloudscale-loadbalancer-controller-serving-cert',
            },
            fieldPaths: [
              '.spec.dnsNames.0',
              '.spec.dnsNames.1',
            ],
            options: {
              delimiter: '.',
              index: 1,
              create: true,
            },
          },
        ],
      },
      {
        source: {
          kind: 'Certificate',
          group: 'cert-manager.io',
          version: 'v1',
          name: 'cloudscale-loadbalancer-controller-serving-cert',
          fieldPath: '.metadata.namespace',
        },
        targets: [
          {
            select: {
              kind: 'ValidatingWebhookConfiguration',
            },
            fieldPaths: [
              '.metadata.annotations.[cert-manager.io/inject-ca-from]',
            ],
            options: {
              delimiter: '/',
              index: 0,
              create: true,
            },
          },
        ],
      },
      {
        source: {
          kind: 'Certificate',
          group: 'cert-manager.io',
          version: 'v1',
          name: 'cloudscale-loadbalancer-controller-serving-cert',
          fieldPath: '.metadata.name',
        },
        targets: [
          {
            select: {
              kind: 'ValidatingWebhookConfiguration',
            },
            fieldPaths: [
              '.metadata.annotations.[cert-manager.io/inject-ca-from]',
            ],
            options: {
              delimiter: '/',
              index: 1,
              create: true,
            },
          },
        ],
      },
      {
        source: {
          kind: 'Certificate',
          group: 'cert-manager.io',
          version: 'v1',
          name: 'cloudscale-loadbalancer-controller-serving-cert',
          fieldPath: '.metadata.namespace',
        },
        targets: [
          {
            select: {
              kind: 'MutatingWebhookConfiguration',
            },
            fieldPaths: [
              '.metadata.annotations.[cert-manager.io/inject-ca-from]',
            ],
            options: {
              delimiter: '/',
              index: 0,
              create: true,
            },
          },
        ],
      },
      {
        source: {
          kind: 'Certificate',
          group: 'cert-manager.io',
          version: 'v1',
          name: 'cloudscale-loadbalancer-controller-serving-cert',
          fieldPath: '.metadata.name',
        },
        targets: [
          {
            select: {
              kind: 'MutatingWebhookConfiguration',
            },
            fieldPaths: [
              '.metadata.annotations.[cert-manager.io/inject-ca-from]',
            ],
            options: {
              delimiter: '/',
              index: 1,
              create: true,
            },
          },
        ],
      },
    ],

    patchesStrategicMerge: [
      'rm-namespace.yaml',
      std.manifestJson({
        apiVersion: 'apps/v1',
        kind: 'Deployment',
        metadata: {
          name: 'controller-manager',
          namespace: 'system',
        },
        spec: {
          template: {
            spec: {
              containers: [
                {
                  name: 'manager',
                  resources: params.resources.cloudscale_loadbalancer_controller,
                  env: com.envList(params.extra_env.cloudscale_loadbalancer_controller),
                },
              ],
            },
          },
        },
      }),
    ],
  } + com.makeMergeable(params.kustomize_input),
) {
  'rm-namespace': {
    '$patch': 'delete',
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: {
      name: 'system',
    },
  },
};

cloudscale_loadbalancer_controller
