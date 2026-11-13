from common import *

PARAMS = {'image', 'name', 'namespace', 'task'}

def resource_template(spec):
    resources = [t for t in spec.get('templates', []) if 'resource' in t]
    require(len(resources) == 1, 'use one resource template for the Deployment')
    template = resources[0]
    require(PARAMS <= {p['name'] for p in template.get('inputs', {}).get('parameters', [])}, 'declare all four local inputs')
    resource = template['resource']
    require(resource.get('action') == 'create', 'use the create resource action')
    manifest = resource.get('manifest', '')
    require(all('{{inputs.parameters.' + p + '}}' in manifest for p in ['image', 'name', 'namespace', 'task']), 'use all four inputs in the manifest')
    require(resource.get('successCondition') == 'status.availableReplicas > 0', 'wait for an available replica')
    return template

def check():
    template = get('workflowtemplate', 'deploy-workload', 'starfleet')
    spec = template['spec']
    require(PARAMS <= {p['name'] for p in spec.get('arguments', {}).get('parameters', [])}, 'declare all four workflow parameters')
    resource = resource_template(spec)
    workflows = get('workflows', namespace='starfleet')['items']
    for name, namespace, version, task in [('scout', 'outpost', '6.15.0', 'release-check'), ('probe', 'starfleet', '6.14.0', 'preview-check')]:
        expected = dict(name=name, namespace=namespace, image='ghcr.io/stefanprodan/podinfo:'+version, task=task)
        deployment = get('deployment', name, namespace)
        deployed(deployment)
        uid = deployment['metadata'].get('annotations', {}).get('training.astrona.io/workflow-uid')
        matching = [w for w in workflows if w['metadata']['uid'] == uid]
        require(len(matching) == 1, 'Deployment must reference a retained Workflow UID')
        workflow = matching[0]
        status = workflow.get('status', {})
        require(workflow['spec'].get('workflowTemplateRef', {}).get('name') == 'deploy-workload' and status.get('phase') == 'Succeeded', 'retain a Succeeded run from deploy-workload')
        values = {p['name']: p.get('value') for p in workflow['spec'].get('arguments', {}).get('parameters', [])}
        require(all(values.get(k) == v for k, v in expected.items()), 'run arguments do not match the requested inputs')
        stored = status.get('storedWorkflowTemplateSpec', {})
        used = resource_template(stored)
        require(all(used.get(k) == resource.get(k) for k in ['name', 'inputs', 'resource']), 'successful run used a different resource template')
        require(workflow['spec'].get('serviceAccountName', stored.get('serviceAccountName')) == 'deployment-writer', 'use deployment-writer')
        nodes = [n for n in status.get('nodes', {}).values() if n.get('templateName') == resource['name'] and n.get('type') == 'Pod' and n.get('phase') == 'Succeeded']
        require(any(all({p['name']:p.get('value') for p in n.get('inputs', {}).get('parameters', [])}.get(k) == v for k,v in expected.items()) for n in nodes), 'resource node did not receive all four inputs')
        podspec = deployment['spec']['template']['spec']
        require(len(podspec['containers']) == 1 and podspec['containers'][0]['image'] == expected['image'], 'Deployment uses the wrong image')
        labels = deployment['spec']['template']['metadata']['labels']
        require(labels.get('app') == name and deployment['spec']['selector']['matchLabels'] == {'app':name}, 'Deployment selectors must use the name input')
        probe = podspec['containers'][0].get('readinessProbe', {}).get('httpGet', {})
        require(probe.get('path') == '/readyz' and probe.get('port') in ['http', 9898], 'keep the requested readiness probe')
        pods = get('pods', namespace=namespace)['items']
        pods = [pod for pod in pods if pod['metadata'].get('labels', {}).get('app') == name and not pod['metadata'].get('deletionTimestamp')]
        require(bool(pods), 'no current workload pods')
        address = pods[0].get('status', {}).get('podIP')
        require(bool(address), 'workload has no pod IP')
        body = json.loads(response(f'http://{address}:9898/'))
        require(body.get('version') == version and body.get('message') == task, 'workload response has the wrong version or task message')


if __name__ == "__main__":
    run(check)
