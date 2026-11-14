from common import *

def references(spec):
    tasks = {t['name']:t for t in spec.get('tasks', [])}
    require(set(tasks) == {'fetch-source','run-tests'}, 'preserve the two pipeline tasks')
    for name, resolver, expected in [
        ('fetch-source','cluster',{'kind':'task','name':'fetch-source','namespace':'tekton-tasks'}),
        ('run-tests','git',{'url':'http://gitea-http.gitea.svc:3000/starfleet/scout-app.git','revision':'main','pathInRepo':'tekton/run-tests.yaml'})]:
        ref = tasks[name].get('taskRef', {})
        require(ref.get('resolver') == resolver and not ref.get('name') and 'taskSpec' not in tasks[name], 'use the required resolver')
        params = {p['name']:p.get('value') for p in ref.get('params', [])}
        require(all(params.get(k) == v for k,v in expected.items()), 'repair the resolver location')
    require(tasks['run-tests'].get('runAfter') == ['fetch-source'], 'test only after fetching source')

def check():
    pipeline = get('pipeline','scout-ci','starfleet')
    references(pipeline['spec'])
    require(not get('tasks',namespace='starfleet')['items'], 'do not copy the resolved Tasks into starfleet')
    runs = get('pipelineruns',namespace='starfleet')['items']
    runs = [r for r in runs if r['spec'].get('pipelineRef',{}).get('name') == 'scout-ci' and any(c['type']=='Succeeded' and c['status']=='True' for c in r.get('status',{}).get('conditions',[]))]
    require(bool(runs), 'retain a successful PipelineRun')
    run = max(runs,key=lambda r:r['metadata']['creationTimestamp'])
    references(run['status'].get('pipelineSpec',{}))
    results = {r['name']:r['value'] for r in run['status'].get('results',[])}
    require(results.get('version') == '6.15.0' and len(results.get('commit','')) == 40, 'run must report version and source commit')
    require(any(w.get('name')=='shared' and 'volumeClaimTemplate' in w for w in run['spec'].get('workspaces',[])), 'use a fresh volumeClaimTemplate')
    tasks = get('taskruns',namespace='starfleet')['items']
    tasks = [t for t in tasks if any(o.get('uid') == run['metadata']['uid'] for o in t['metadata'].get('ownerReferences',[]))]
    tests = [t for t in tasks if t['metadata'].get('labels',{}).get('tekton.dev/pipelineTask')=='run-tests']
    require(len(tests)==1, 'successful run must own its test TaskRun')
    provenance = tests[0].get('status',{}).get('provenance',{}).get('refSource',{})
    require(provenance.get('entryPoint') == 'tekton/run-tests.yaml' and provenance.get('digest',{}).get('sha1') == results['commit'], 'test Task provenance must match the tested source commit')
    require(provenance.get('uri','').endswith('gitea-http.gitea.svc:3000/starfleet/scout-app.git'), 'test Task must come from the supplied Git repository')
    logs = command('kubectl','-n','starfleet','logs','-l','tekton.dev/taskRun='+tests[0]['metadata']['name'],'-c','step-test')
    require('Tests passed for scout 6.15.0' in logs, 'the resolved Task must execute the source tests')


if __name__ == "__main__":
    run(check)
