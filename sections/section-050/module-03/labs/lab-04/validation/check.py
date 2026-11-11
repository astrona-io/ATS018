from common import *

from pathlib import Path
from datetime import datetime

def waiting_evidence(saved, events, uid):
    live = {e['metadata']['uid']:e for e in events}
    require(bool(saved), 'save the waiting events before approval')
    for item in saved:
        current = live.get(item['metadata']['uid'])
        require(current is not None and current.get('involvedObject',{}).get('uid') == uid and item.get('involvedObject',{}).get('uid') == uid and current.get('message') == item.get('message'), 'saved event does not match this Canary and its live event')
    messages = [e.get('message','') for e in saved]
    require(any('waiting for promotion approval scout-approval' in m for m in messages), 'retain the promotion-wait event')
    require(not any('Confirm-promotion check scout-approval passed' in m or 'Promotion completed' in m for m in messages), 'capture the events before approval')

def promotion_evidence(logs, saved):
    waiting = [e for e in saved if 'waiting for promotion approval scout-approval' in e.get('message', '')]
    def timestamp(value):
        return datetime.fromisoformat(value.replace('Z', '+00:00'))
    wait_time = min(timestamp(e.get('firstTimestamp') or e.get('eventTime') or e['metadata']['creationTimestamp']) for e in waiting)
    approved = None
    for line in logs.splitlines():
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if entry.get('canary') != 'scout.starfleet' or not entry.get('ts'):
            continue
        observed = timestamp(entry['ts'])
        if observed < wait_time:
            continue
        message = entry.get('msg', '')
        if 'Confirm-promotion check scout-approval passed' in message:
            approved = observed
        if 'Promotion completed' in message and approved is not None and observed >= approved:
            return
    raise Incomplete('promotion must follow successful approval for this waiting rollout')

def check():
    canary = get('canary','scout','starfleet')
    spec = canary['spec']
    require(spec.get('provider')=='istio' and spec.get('targetRef',{}).get('name')=='scout', 'preserve the Istio target')
    analysis = spec.get('analysis',{})
    require(all(analysis.get(k)==v for k,v in dict(interval='15s',threshold=3,maxWeight=50,stepWeight=10).items()), 'preserve the traffic and failure policy')
    require(any(m.get('name')=='request-success-rate' and m.get('thresholdRange',{}).get('min')==99 and m.get('interval')=='30s' for m in analysis.get('metrics',[])), 'preserve the success-rate check')
    hooks = analysis.get('webhooks',[])
    require(any(h.get('name')=='scout-approval' and h.get('type')=='confirm-promotion' and h.get('url')=='http://flagger-loadtester.starfleet/gate/check' and h.get('timeout')=='5s' for h in hooks), 'configure the promotion approval gate')
    require(not any(h.get('type')=='confirm-rollout' for h in hooks), 'this task gates promotion, not rollout start')
    require(any(h.get('type')=='rollout' and h.get('metadata',{}).get('cmd')=='hey -z 1m -q 10 -c 2 http://scout-canary.starfleet/' for h in hooks), 'keep the load hook')
    require(canary.get('status',{}).get('phase')=='Succeeded', 'wait for successful promotion')
    uid = canary['metadata']['uid']
    events = [e for e in get('events',namespace='starfleet')['items'] if e.get('involvedObject',{}).get('uid')==uid]
    evidence = Path('/tmp/scout-promotion-events.json')
    require(evidence.is_file(), 'save the waiting event snapshot')
    try:
        saved = json.loads(evidence.read_text()).get('items',[])
    except (ValueError, AttributeError):
        raise Incomplete('event snapshot must be a Kubernetes EventList JSON document')
    waiting_evidence(saved,events,uid)
    # Kubernetes combines similar Events, which can replace the approval message.
    logs = command('kubectl', '-n', 'istio-system', 'logs', 'deploy/flagger',
                   '--since-time=' + canary['metadata']['creationTimestamp'])
    promotion_evidence(logs, saved)
    dep=get('deployment','scout-primary','starfleet')
    deployed(dep)
    require(any(c['name']=='scout' and c['image']=='ghcr.io/stefanprodan/podinfo:6.15.0' for c in dep['spec']['template']['spec']['containers']), 'primary must run the new image')
    require(json.loads(response('http://scout.starfleet/')).get('version')=='6.15.0', 'public Service must serve the new image')


if __name__ == "__main__":
    run(check)
