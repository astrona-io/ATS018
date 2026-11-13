"""Live Kubernetes checks; missing work is FAIL, API errors are ERROR."""
import json
import subprocess
import sys
import time

class Incomplete(Exception):
    pass

def require(ok, message):
    if not ok:
        raise Incomplete(message)

def command(*args):
    result = subprocess.run(args, text=True, capture_output=True, timeout=45)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    return result.stdout

def get(kind, name=None, namespace=None):
    args = ['kubectl', '--request-timeout=20s']
    if namespace:
        args += ['-n', namespace]
    args += ['get', kind]
    if name:
        args += [name, '--ignore-not-found']
    args += ['-o', 'json']
    result = command(*args)
    require(bool(result.strip()), f'{kind} {name} is missing')
    return json.loads(result)

def ready(obj):
    status = obj.get('status', {})
    generation = obj['metadata'].get('generation', 0)
    require(status.get('observedGeneration', 0) >= generation, 'controller has not observed the current generation')
    require(any(c['type'] == 'Ready' and c['status'] == 'True'
                for c in status.get('conditions', [])), 'resource is not Ready')

def deployed(obj, replicas=1):
    status = obj.get('status', {})
    require(status.get('observedGeneration', 0) >= obj['metadata'].get('generation', 0), 'Deployment status is stale')
    require(obj['spec'].get('replicas', 1) == replicas, 'wrong replica count')
    require(status.get('updatedReplicas', 0) == replicas and status.get('availableReplicas', 0) == replicas, 'Deployment has not completed its rollout')

def response(url):
    return command('kubectl', '-n', 'starfleet', 'exec', 'deploy/shuttle', '-c', 'shuttle', '--',
                   'curl', '-fsS', '--max-time', '10', url)

def run(check):
    deadline = time.monotonic() + (180 if '--wait' in sys.argv else 0)
    while True:
        try:
            check()
            print('PASS: live result matches the task')
            return
        except Incomplete as error:
            if time.monotonic() >= deadline:
                sys.exit(f'FAIL: {error}')
            time.sleep(3)
        except (RuntimeError, subprocess.SubprocessError, ValueError, KeyError, OSError) as error:
            sys.exit(f'ERROR: {error}')
