from common import *

def check():
    appset = get('applicationset', 'platform-apps', 'argocd')
    spec = appset['spec']
    url = 'http://gitea-http.gitea.svc:3000/starfleet/platform-apps.git'
    require(spec.get('goTemplate') and 'missingkey=error' in spec.get('goTemplateOptions', []), 'enable strict Go templates')
    generators = spec.get('generators', [])
    require(len(generators) == 1 and set(generators[0]) == {'git'}, 'use one Git generator')
    git = generators[0]['git']
    require(git.get('repoURL') == url and git.get('revision') == 'main' and git.get('directories') == [{'path': 'apps/*'}] and not git.get('files'), 'use the Git directory generator for apps/*')
    template = spec['template']
    require(template['metadata'].get('name') == '{{.path.basename}}' and template['spec']['source'].get('path') == '{{.path.path}}', 'derive names and paths from the generator')
    conditions = {c['type']:c['status'] for c in appset.get('status', {}).get('conditions', [])}
    require(conditions.get('ErrorOccurred') == 'False' and conditions.get('ResourcesUpToDate') == 'True', 'ApplicationSet is not reconciled')
    for name in ['scout', 'probe', 'bridge', 'beacon']:
        app = get('application', name, 'argocd')
        require(any(o.get('uid') == appset['metadata']['uid'] and o.get('controller') for o in app['metadata'].get('ownerReferences', [])), 'Application is not controlled by this ApplicationSet')
        require(app['metadata'].get('labels', {}).get('team') == 'starfleet', 'set the team label')
        require(app['spec'].get('project') == 'default' and app['spec']['source'] == {'repoURL':url, 'targetRevision':'main', 'path':f'apps/{name}'}, 'incorrect generated source or project')
        require(app['spec']['destination'] == {'server':'https://kubernetes.default.svc', 'namespace':'starfleet'}, 'incorrect destination')
        policy = app['spec'].get('syncPolicy', {}).get('automated', {})
        require(policy.get('prune') and policy.get('selfHeal') and policy.get('enabled', True), 'enable automated sync, prune and self-heal')
        require(app.get('status', {}).get('sync', {}).get('status') == 'Synced' and app.get('status', {}).get('health', {}).get('status') == 'Healthy', f'{name} is not Synced and Healthy')
        dep = get('deployment', name, 'starfleet')
        deployed(dep)
        require(dep['metadata'].get('annotations', {}).get('argocd.argoproj.io/tracking-id') == f'{name}:apps/Deployment:starfleet/{name}', 'workload has no Application tracking')
    require('headers' in json.loads(response('http://beacon/get')), 'beacon does not respond')


if __name__ == "__main__":
    run(check)
