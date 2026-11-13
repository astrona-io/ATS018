import json,subprocess,sys,time,tempfile,socket,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def run(*args,**kwargs):return subprocess.check_output(list(args),text=True,**kwargs).strip()
def get(namespace,kind,name):return json.loads(run('kubectl','-n',namespace,'get',kind,name,'-o','json'))
def check(ok,msg):
    if not ok:sys.exit('FAIL: '+msg)
app=get('argocd','application','scout-hpa');original=json.loads((ROOT/'initial-app.json').read_text())
check(app['metadata']['uid']==original['metadata']['uid'],'preserve the Application')
for key in ('source','destination','project'):
    check(app['spec'][key]==original['spec'][key],f'preserve Application {key}')
policy=app['spec'].get('syncPolicy',{})
check(policy.get('automated',{}).get('selfHeal') is True and policy.get('automated',{}).get('prune') is True and policy.get('automated',{}).get('enabled',True) is not False,'keep automated sync, self-heal and prune enabled')
check(set(policy.get('syncOptions',[]))=={'CreateNamespace=true','RespectIgnoreDifferences=true'},'respect the ignored field during sync')
rules=app['spec'].get('ignoreDifferences',[])
check(len(rules)==1 and rules[0].get('group')=='apps' and rules[0].get('kind')=='Deployment' and rules[0].get('name')=='scout' and rules[0].get('namespace','starfleet-hpa')=='starfleet-hpa' and rules[0].get('jsonPointers')==['/spec/replicas'] and not rules[0].get('jqPathExpressions') and not rules[0].get('managedFieldsManagers'),'ignore only scout replicas')
old=json.loads((ROOT/'initial-hpa.json').read_text());hpa=get('starfleet-hpa','hpa','scout')
check(hpa['metadata']['uid']==old['metadata']['uid'] and hpa['spec']==old['spec'],'preserve the HPA and its scaling policy')
for attempt in range(60):
    deploy=get('starfleet-hpa','deployment','scout')
    if deploy['spec']['replicas']>=2:break
    time.sleep(2)
else:sys.exit('FAIL: HPA did not establish at least two replicas')
# An unrelated Git update forces a real sync while the HPA owns replicas.
with socket.socket() as sock:
    sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
pf=subprocess.Popen(['kubectl','-n','gitea','port-forward','svc/gitea-http',f'{port}:3000'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
try:
    for attempt in range(30):
        try:
            with socket.create_connection(('127.0.0.1',port),timeout=1):break
        except OSError:time.sleep(1)
    with tempfile.TemporaryDirectory() as work:
        url=f'http://platform:starfleet-gitops@127.0.0.1:{port}/starfleet/scout-faults.git'
        run('git','clone','-q',url,work)
        source=Path(work)/'hpa/scout.yaml';text=source.read_text()
        check('replicas: 1' in text,'keep the Git replica declaration unchanged')
        token=uuid.uuid4().hex
        # Use Deployment metadata, keeping the workload template unchanged.
        import re
        text=re.sub(r'  annotations:\n    review.astrona.io/sync: "[a-f0-9]+"\n','',text)
        text=text.replace('  name: scout\nspec:',f'  name: scout\n  annotations:\n    review.astrona.io/sync: "{token}"\nspec:',1)
        source.write_text(text)
        run('git','-C',work,'add','hpa/scout.yaml')
        run('git','-C',work,'-c','user.name=lab-grader','-c','user.email=lab@astrona.local','commit','-qm','Exercise sync with HPA-owned replicas')
        commit=run('git','-C',work,'rev-parse','HEAD');run('git','-C',work,'push','-q','origin','main')
        run('kubectl','-n','argocd','annotate','application','scout-hpa','argocd.argoproj.io/refresh=hard','--overwrite')
        deadline=time.monotonic()+240
        while time.monotonic()<deadline:
            deploy=get('starfleet-hpa','deployment','scout')
            check(deploy['spec']['replicas']>=2,'Git sync reset HPA-owned replicas')
            app=get('argocd','application','scout-hpa');status=app.get('status',{})
            if deploy['metadata'].get('annotations',{}).get('review.astrona.io/sync')==token and status.get('sync',{}).get('revision')==commit and status.get('sync',{}).get('status')=='Synced':break
            time.sleep(.5)
        else:sys.exit('FAIL: the unrelated Git update did not sync')
        # Self-heal must still restore fields outside the exception.
        run('kubectl','-n','starfleet-hpa','annotate','deployment','scout','review.astrona.io/sync=live-drift','--overwrite')
        run('kubectl','-n','argocd','annotate','application','scout-hpa','argocd.argoproj.io/refresh=hard','--overwrite')
        for attempt in range(120):
            deploy=get('starfleet-hpa','deployment','scout')
            check(deploy['spec']['replicas']>=2,'self-heal reset HPA-owned replicas')
            if deploy['metadata'].get('annotations',{}).get('review.astrona.io/sync')==token:break
            time.sleep(1)
        else:sys.exit('FAIL: self-heal did not restore the unrelated annotation')
finally:
    pf.terminate();pf.wait(timeout=10)
run('kubectl','-n','starfleet-hpa','rollout','status','deploy/scout','--timeout=180s')
print('PASS: real Git sync and self-heal preserve HPA-owned replicas')
