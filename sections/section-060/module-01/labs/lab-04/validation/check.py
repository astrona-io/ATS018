"""Grade one part of the task: python3 check.py template|runs|deployments [--wait]."""
from common import *

PARAMS = {'image', 'name', 'namespace', 'msg'}
RUNS = [('scout', 'outpost', 'alpine:3.23', 'scout is running')]

def resource_template(spec):
    resources = [t for t in spec.get('templates', []) if 'resource' in t]
    require(len(resources) == 1, 'use one resource template for the Deployment')
    resource = resources[0]['resource']
    require(resource.get('action') == 'create', 'use the create resource action')
    require(' '.join(resource.get('successCondition', '').split()) == 'status.availableReplicas > 0',
            'wait for status.availableReplicas > 0')
    manifest = resource.get('manifest', '')
    for param in sorted(PARAMS):
        require('parameters.' + param + '}}' in manifest, f'fill the Deployment from the {param} parameter, not a fixed value')
    return resources[0]

def template_spec():
    return get('workflowtemplate', 'deploy-workload', 'starfleet')['spec']

def check_template():
    spec = template_spec()
    require(PARAMS <= {p['name'] for p in spec.get('arguments', {}).get('parameters', [])},
            'declare the parameters image, name, namespace and msg')
    require(spec.get('serviceAccountName') == 'deployment-writer', 'run as deployment-writer')
    resource_template(spec)

def find_run(workflows, name, namespace, image, msg):
    expected = dict(name=name, namespace=namespace, image=image, msg=msg)
    for workflow in workflows:
        values = {p['name']: p.get('value') for p in workflow['spec'].get('arguments', {}).get('parameters', [])}
        if (workflow['spec'].get('workflowTemplateRef', {}).get('name') == 'deploy-workload'
                and all(values.get(k) == v for k, v in expected.items())
                and workflow.get('status', {}).get('phase') == 'Succeeded'):
            return workflow
    raise Incomplete(f'no Succeeded workflow from deploy-workload with name={name} namespace={namespace} image={image} msg="{msg}"')

def check_runs():
    resource = resource_template(template_spec())
    workflows = get('workflows', namespace='starfleet')['items']
    for run_inputs in RUNS:
        workflow = find_run(workflows, *run_inputs)
        used = resource_template(workflow['status'].get('storedWorkflowTemplateSpec', {}))
        require(used.get('resource') == resource.get('resource'),
                f'the {run_inputs[0]} run used a different template; submit it again from the current template')

def check_deployments():
    workflows = get('workflows', namespace='starfleet')['items']
    for name, namespace, image, msg in RUNS:
        workflow = find_run(workflows, name, namespace, image, msg)
        deployment = get('deployment', name, namespace)
        deployed(deployment)
        status = workflow['status']
        created = deployment['metadata']['creationTimestamp']
        require(status.get('startedAt', '') <= created <= status.get('finishedAt', ''),
                f'Deployment {name} was not created by its workflow run')
        require(deployment['spec']['selector'].get('matchLabels') == {'app': name}, f'Deployment {name} must select app: {name}')
        containers = deployment['spec']['template']['spec']['containers']
        require(len(containers) == 1 and containers[0]['image'] == image, f'Deployment {name} uses the wrong image')
        pods = [pod for pod in get('pods', namespace=namespace)['items']
                if pod['metadata'].get('labels', {}).get('app') == name and not pod['metadata'].get('deletionTimestamp')]
        require(bool(pods), f'Deployment {name} has no running pod')
        lines = command('kubectl', '-n', namespace, 'logs', pods[0]['metadata']['name']).splitlines()
        require(msg in lines, f'the {name} container log does not print "{msg}"')

CHECKS = {'template': check_template, 'runs': check_runs, 'deployments': check_deployments}

if __name__ == "__main__":
    run(CHECKS[sys.argv[1]])
