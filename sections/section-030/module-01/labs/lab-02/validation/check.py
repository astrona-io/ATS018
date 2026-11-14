from common import *

def check():
    app = get('application', 'scout-preview', 'argocd')
    spec = app['spec']
    source = spec['source']
    require(source.get('repoURL') == 'ghcr.io/stefanprodan/charts' and source.get('chart') == 'podinfo' and source.get('targetRevision') == '6.15.0' and not source.get('path'), 'use the specified Helm chart source and version')
    helm = source.get('helm', {})
    values = helm.get('valuesObject', {})
    require(helm.get('releaseName') == 'scout' and values.get('fullnameOverride') == 'scout' and values.get('replicaCount') == 2 and values.get('ui', {}).get('message') == 'preview', 'set release name and the requested valuesObject')
    require(spec.get('destination') == {'server': 'https://kubernetes.default.svc', 'namespace': 'starfleet-preview'}, 'wrong destination')
    policy = spec.get('syncPolicy', {})
    require(policy.get('automated', {}).get('prune') and policy.get('automated', {}).get('selfHeal') and policy.get('automated', {}).get('enabled', True), 'keep automated sync, prune and self-heal enabled')
    require('CreateNamespace=true' in policy.get('syncOptions', []), 'let Argo CD create the namespace')
    require(app.get('status', {}).get('sync', {}).get('status') == 'Synced' and app.get('status', {}).get('health', {}).get('status') == 'Healthy', 'Application must be Synced and Healthy')
    deployment = get('deployment', 'scout', 'starfleet-preview')
    deployed(deployment, 2)
    require(deployment['metadata'].get('annotations', {}).get('argocd.argoproj.io/tracking-id') == 'scout-preview:apps/Deployment:starfleet-preview/scout', 'Deployment must be tracked by scout-preview')
    require(not any(s.get('type') == 'helm.sh/release.v1' for s in get('secrets', namespace='starfleet-preview')['items']), 'do not install a Helm release')
    body = json.loads(response('http://scout.starfleet-preview:9898/'))
    require(body.get('version') == '6.15.0' and body.get('message') == 'preview', 'live response has the wrong version or message')


if __name__ == "__main__":
    run(check)
