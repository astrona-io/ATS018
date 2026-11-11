from common import *

def check():
    app = get('application', 'scout-path', 'argocd')
    status = app.get('status', {})
    require(app['spec']['source'] == {'repoURL':'http://gitea-http.gitea.svc:3000/starfleet/scout-faults.git', 'path':'path', 'targetRevision':'main'}, 'preserve the Git source')
    require(status.get('sync', {}).get('status') == 'Synced' and status.get('health', {}).get('status') == 'Healthy', 'Application must be Synced and Healthy')
    operation = status.get('operationState', {})
    require(operation.get('phase') == 'Succeeded' and operation.get('syncResult', {}).get('revision') == status['sync'].get('revision'), 'wait for a successful operation at the synced revision')
    results = operation.get('syncResult', {}).get('resources', [])
    require(any(r.get('kind') == 'Job' and r.get('name') == 'scout-migrate' and r.get('hookType') == 'PreSync' and r.get('hookPhase') == 'Succeeded' for r in results), 'operation must report the successful PreSync Job')
    job = get('job', 'scout-migrate', 'starfleet-path')
    annotations = job['metadata'].get('annotations', {})
    require(annotations.get('argocd.argoproj.io/hook') == 'PreSync' and annotations.get('argocd.argoproj.io/hook-delete-policy') == 'BeforeHookCreation', 'set the hook phase and deletion policy')
    require(job['spec'].get('backoffLimit') == 0 and job['spec']['template']['spec'].get('restartPolicy') == 'Never', 'use the requested Job failure policy')
    require(job.get('status', {}).get('succeeded') == 1 and any(c['type']=='Complete' and c['status']=='True' for c in job.get('status', {}).get('conditions', [])), 'Job has not completed')
    logs = command('kubectl', '-n', 'starfleet-path', 'logs', 'job/scout-migrate')
    require('migrating the scout schema' in logs and logs.rstrip().endswith('done'), 'migration log is incomplete')
    settings = get('configmap', 'scout-settings', 'starfleet-path')
    annotations = settings['metadata'].get('annotations', {})
    require(annotations.get('argocd.argoproj.io/sync-wave') == '-1' and annotations.get('argocd.argoproj.io/tracking-id') == 'scout-path:/ConfigMap:starfleet-path/scout-settings', 'settings must be tracked in wave -1')
    require(settings.get('data', {}).get('PODINFO_UI_MESSAGE') == 'waves', 'settings data is missing')
    dep = get('deployment', 'scout', 'starfleet-path')
    deployed(dep)
    require(dep['metadata'].get('annotations', {}).get('argocd.argoproj.io/sync-wave', '0') == '0', 'keep the workload in wave 0')
    require(json.loads(response('http://scout.starfleet-path/')).get('version') == '6.15.0', 'workload is not serving the expected version')


if __name__ == "__main__":
    run(check)
