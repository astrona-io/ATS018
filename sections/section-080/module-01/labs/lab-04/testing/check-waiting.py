import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'validation'))
from common import *

def check():
    require(get('canary','scout','starfleet')['status']['phase']=='WaitingPromotion','candidate must wait for promotion')
    routes=get('virtualservice','scout','starfleet')['spec']['http'][0]['route']
    weights={r['destination']['host'].split('.')[0]:r.get('weight',0) for r in routes}
    require(weights.get('scout-primary')==50 and weights.get('scout-canary')==50,'live route must retain a 50/50 split')
    dep=get('deployment','scout-primary','starfleet')
    require(any(c['name']=='scout' and c['image']=='ghcr.io/stefanprodan/podinfo:6.14.0' for c in dep['spec']['template']['spec']['containers']),'primary must remain on the baseline while waiting')

run(check)
