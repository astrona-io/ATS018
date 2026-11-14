#!/usr/bin/env python3
"""Compare the reviewed plan with its live objects, then check configuration and traffic."""
import json, os, pathlib, subprocess, sys
os.environ['PATH'] = str(pathlib.Path.home()/'.astrona/bin') + ':' + os.environ['PATH']
# Capture stdout only: curl writes its retry warnings and OpenTofu writes its
# deprecation warnings to stderr, and both would break the JSON parsed below.
def run(*args):
    return subprocess.check_output(args, text=True)
def require(ok, message):
    if not ok: raise ValueError(message)
def check(folder, name, namespace, replicas, mode):
    directory = pathlib.Path.home()/'resources/tofu'/folder
    os.chdir(directory)
    binary = directory/'change.plan'
    text = directory/'plan.txt'
    require(binary.is_file() and text.is_file(), 'save change.plan and plan.txt before applying')
    require(text.read_text() == run('tofu','show','-no-color',str(binary)), 'plan.txt must equal the human-readable saved plan')
    plan = json.loads(run('tofu','show','-json',str(binary)))
    changes = {item['address']:item for item in plan['resource_changes']}
    address = 'kubernetes_deployment.'+name
    change = changes[address]['change']
    expected_actions = {address: ['update'], 'kubernetes_service.'+name: ['no-op']}
    if mode == 'module': expected_actions['kubernetes_service.'+name] = ['create']
    if mode == 'expose': expected_actions = {address: ['no-op'], 'kubernetes_service.'+name: ['create']}
    require(set(changes) == set(expected_actions), 'review exactly this Deployment and Service')
    require(all(changes[key]['change']['actions'] == actions for key, actions in expected_actions.items()), 'review only the requested operations')
    if mode in ('module', 'expose'):
        configured = {r['address']: r for r in plan['configuration']['root_module']['resources']}
        refs = configured['kubernetes_service.'+name]['expressions']['spec'][0]['selector'].get('references', [])
        require(any(ref.startswith(address+'.spec[0].template[0].metadata[0].labels') for ref in refs), 'read the Service selector from the Deployment pod labels')
    live = json.loads(run('kubectl','-n',namespace,'get','deployment',name,'-o','json'))
    require(change['before']['metadata'][0]['uid'] == live['metadata']['uid'], 'keep the original managed Deployment')
    before_replicas = 1
    if mode != 'expose':
        require(change['actions'] == ['update'], 'review an in-place Deployment update')
        require(int(change['before']['spec'][0]['replicas']) == before_replicas, 'plan must start with one live replica')
    else:
        require(change['actions'] == ['no-op'], 'keep the existing Deployment unchanged')
    require(int(change['after']['spec'][0]['replicas']) == replicas, 'wrong planned replica count')
    svc_change = changes['kubernetes_service.'+name]['change']
    require(svc_change['actions'] == (['create'] if mode in ('module','expose') else ['no-op']), 'wrong Service action in the reviewed plan')
    planned_svc = svc_change['after']
    require(planned_svc['spec'][0]['selector'] == {'app':name}, 'planned selector must match pods')
    require(planned_svc['spec'][0]['port'][0]['port'] == 80, 'planned Service port must be 80')
    require(str(planned_svc['spec'][0]['port'][0]['target_port']) == '9898', 'planned target port must be 9898')
    require(live['spec']['replicas'] == replicas, 'wrong live replica count')
    run('kubectl','-n',namespace,'rollout','status','deployment/'+name,'--timeout=180s')
    live = json.loads(run('kubectl','-n',namespace,'get','deployment',name,'-o','json'))
    require(live['status'].get('updatedReplicas') == replicas and live['status'].get('availableReplicas') == replicas, 'wait for all updated replicas')
    require(live['spec']['template']['spec']['containers'][0]['image'] == 'ghcr.io/stefanprodan/podinfo:6.15.0', 'keep the pinned image')
    svc = json.loads(run('kubectl','-n',namespace,'get','service',name,'-o','json'))
    if mode in ('scale', 'drift'):
        require(svc_change['before']['metadata'][0]['uid'] == svc['metadata']['uid'], 'keep the existing Service identity')
    require(svc['spec']['type'] == 'ClusterIP' and svc['spec']['selector'] == {'app':name}, 'wrong live Service type or selector')
    require(svc['spec']['ports'][0]['port'] == 80 and svc['spec']['ports'][0]['targetPort'] == 9898, 'wrong live Service ports')
    state = json.loads(run('tofu','show','-json'))
    resources = {r['address']:r['values'] for r in state['values']['root_module']['resources']}
    require(resources[address]['metadata'][0]['uid'] == live['metadata']['uid'], 'Deployment state must match the live UID')
    require(resources['kubernetes_service.'+name]['metadata'][0]['uid'] == svc['metadata']['uid'], 'Service must belong to this state')
    require(int(resources[address]['spec'][0]['replicas']) == replicas, 'state must record the final replicas')
    # A successful fresh plan with no changes rejects a live-only fix or ignore_changes.
    result = subprocess.run(['tofu','plan','-no-color','-input=false','-detailed-exitcode'],capture_output=True,text=True)
    require(result.returncode == 0, 'saved configuration must agree with the live cluster: '+result.stdout+result.stderr)
    current = json.loads(run('tofu','show','-json','-config'))
    current_resources = {r['address']: r for r in current['root_module']['resources']}
    if mode in ('module', 'expose'):
        refs = current_resources['kubernetes_service.'+name]['expressions']['spec'][0]['selector'].get('references', [])
        require(any(ref.startswith(address+'.spec[0].template[0].metadata[0].labels') for ref in refs), 'keep the selector reference in the saved configuration')
    configuration = '\n'.join(p.read_text() for p in directory.glob('*.tf'))
    require('ignore_changes' not in configuration, 'do not hide drift with ignore_changes')
    # The Service may be seconds old: plain --retry skips DNS and connection errors, so retry on all of them.
    body = json.loads(run('kubectl','-n','starfleet','exec','deploy/shuttle','--','curl','-fsS','--retry','10','--retry-delay','2','--retry-all-errors','--max-time','10',f'http://{name}.{namespace}/'))
    require(body.get('version') == '6.15.0', 'request must return version 6.15.0')
try:
    check(*sys.argv[1:4], int(sys.argv[4]), sys.argv[5])
    print('PASS: '+sys.argv[1])
except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
    print('FAIL: '+sys.argv[1]+': '+str(error)); sys.exit(1)
