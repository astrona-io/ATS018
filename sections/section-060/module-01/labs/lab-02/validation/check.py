from common import *

def check():
    source = get('gitrepository','platform-infra','flux-system')
    spec = source['spec']
    require(spec.get('url')=='http://gitea-http.gitea.svc:3000/starfleet/platform-infra.git' and spec.get('ref',{}).get('branch')=='main' and spec.get('secretRef',{}).get('name')=='platform-infra-auth' and not spec.get('suspend'), 'preserve source, branch and credentials')
    ready(source)
    revision = source.get('status',{}).get('artifact',{}).get('revision')
    require(bool(revision), 'source has no artifact revision')
    for name in ['platform','environments']:
        obj = get('kustomization',name,'flux-system')
        spec = obj['spec']
        require(spec.get('path')=='./'+name and spec.get('sourceRef')=={'kind':'GitRepository','name':'platform-infra'}, 'use the required source and separate paths')
        require(spec.get('prune') and spec.get('wait') and not spec.get('suspend'), 'keep pruning, health checks and reconciliation enabled')
        if name=='environments':
            require(any(d.get('name')=='platform' for d in spec.get('dependsOn',[])) and spec.get('timeout')=='2m', 'environments must wait for platform and check health for 2m')
        ready(obj)
        require(obj['status'].get('lastAppliedRevision')==revision, 'both Kustomizations must apply the current source revision')
        inventory = obj['status'].get('inventory',{}).get('entries',[])
        require(bool(inventory), 'Flux must own an applied inventory')
    for env, replicas in [('staging',1),('production',2)]:
        namespace = 'starfleet-'+env
        xr = get('scoutenvironments.platform.starfleet.dev','scout',namespace)
        require(any(c['type']=='Ready' and c['status']=='True' for c in xr.get('status',{}).get('conditions',[])), 'composite resource is not Ready')
        require(xr['spec'].get('version')=='6.15.0' and xr['spec'].get('replicas')==replicas and xr['spec'].get('message')==env, 'preserve the requested environment settings')
        require(xr['metadata'].get('labels',{}).get('kustomize.toolkit.fluxcd.io/name')=='environments', 'Flux must deliver the composite resource')
        deployed(get('deployment','scout',namespace),replicas)
        body=json.loads(response('http://scout.'+namespace+'/'))
        require(body.get('version')=='6.15.0' and body.get('message')==env, 'environment response differs from Git intent')
    raw = command('kubectl','-n','starfleet','exec','deploy/shuttle','--','curl','-fsS','--max-time','10','-u','platform:starfleet-gitops','http://gitea-http.gitea.svc:3000/api/v1/repos/starfleet/platform-infra/branches/main')
    commit=json.loads(raw)['commit']['id']
    require(revision.endswith(commit), 'Flux has not fetched the current Git commit')


if __name__ == "__main__":
    run(check)
