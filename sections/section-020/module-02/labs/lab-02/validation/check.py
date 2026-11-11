from common import *

def check():
    parent = get('application', 'platform-apps', 'argocd')
    source = parent['spec']['source']
    url = 'http://gitea-http.gitea.svc:3000/starfleet/platform-apps.git'
    require(source.get('repoURL') == url and source.get('path') == 'argocd-apps' and source.get('targetRevision') == 'main', 'parent must deliver argocd-apps from main')
    require(parent['spec'].get('destination') == {'server': 'https://kubernetes.default.svc', 'namespace': 'argocd'}, 'parent must deliver into argocd')
    require(not parent['metadata'].get('finalizers'), 'leave the parent without cascading deletion')
    for name, app in [('platform-apps', parent)] + [(n, get('application', n, 'argocd')) for n in ['scout', 'probe', 'bridge']]:
        require(app['spec'].get('project') == 'default', 'use project default')
        automated = app['spec'].get('syncPolicy', {}).get('automated', {})
        require(automated.get('prune') and automated.get('selfHeal') and automated.get('enabled', True), 'keep automated sync, prune and self-heal')
        status = app.get('status', {})
        require(status.get('sync', {}).get('status') == 'Synced' and status.get('health', {}).get('status') == 'Healthy', f'{name} is not Synced and Healthy')
        if name == 'platform-apps':
            continue
        require(app['metadata'].get('annotations', {}).get('argocd.argoproj.io/tracking-id') == f'platform-apps:argoproj.io/Application:argocd/{name}', 'child must be tracked by the parent')
        require(app['spec']['source'].get('repoURL') == url and app['spec']['source'].get('path') == f'apps/{name}', 'child source changed')
        dep = get('deployment', name, 'starfleet')
        deployed(dep)
        require(dep['metadata'].get('annotations', {}).get('argocd.argoproj.io/tracking-id') == f'{name}:apps/Deployment:starfleet/{name}', 'workload must be tracked by its child Application')
    require(json.loads(response('http://scout/')).get('version') == '6.15.0', 'scout returned the wrong version')
    require('headers' in json.loads(response('http://probe/get')), 'probe did not return an HTTP response document')
    require('nginx' in response('http://bridge/').lower(), 'bridge did not return its page')


if __name__ == "__main__":
    run(check)
