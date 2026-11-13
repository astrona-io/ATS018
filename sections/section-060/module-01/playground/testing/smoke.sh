#!/usr/bin/env bash
# Exercise the checksum lesson against the playground's real Workflow controller.
set -euo pipefail
export PATH="$HOME/.astrona/bin:$PATH"
dir=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
kubectl apply -f "$dir/probe-release.yaml"
run=$(argo submit -n starfleet --from workflowtemplate/probe-release -o name)
kubectl -n starfleet wait --for=jsonpath='{.status.phase}'=Succeeded "workflow/$run" --timeout=180s
kubectl -n starfleet get workflow "$run" -o json > "$work/run.json"
python3 - "$work/run.json" <<'CHECK'
import hashlib, json, sys
run=json.load(open(sys.argv[1]))
nodes={n['templateName']:n for n in run['status']['nodes'].values() if n['type']=='Pod'}
assert set(nodes)=={'prepare','checksum','publish'}, nodes
assert all(n['phase']=='Succeeded' for n in nodes.values())
def output(node,name):
    return next(p['value'] for p in nodes[node]['outputs']['parameters'] if p['name']==name)
assert output('checksum','checksum')==hashlib.sha256(output('prepare','manifest').encode()).hexdigest()
assert nodes['prepare']['finishedAt'] <= nodes['checksum']['startedAt']
assert nodes['checksum']['finishedAt'] <= nodes['publish']['startedAt']
print('PASS: ordered steps passed the prepared value and computed its SHA-256')
CHECK

# Exercise the Deployment resource-template lesson with two input sets.
kubectl create namespace outpost --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$dir/deployment-writer-rbac.yaml" -f "$dir/deploy-workload.yaml"
argo submit -n starfleet --from workflowtemplate/deploy-workload \
  -p image=ghcr.io/stefanprodan/podinfo:6.15.0 \
  -p name=workflow-scout -p namespace=outpost -p task=release-check --wait
argo submit -n starfleet --from workflowtemplate/deploy-workload \
  -p image=ghcr.io/stefanprodan/podinfo:6.14.0 \
  -p name=workflow-probe -p namespace=starfleet -p task=preview-check --wait
kubectl -n outpost rollout status deployment/workflow-scout --timeout=180s
kubectl -n starfleet rollout status deployment/workflow-probe --timeout=180s
