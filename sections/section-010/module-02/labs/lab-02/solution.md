# Solution Walkthrough

Compare the stored values with the current response before choosing a target:

```sh
export PATH="$HOME/.astrona/bin:$PATH"
helm history scout -n starfleet-production
helm get values scout -n starfleet-production --revision 2 --all
helm get values scout -n starfleet-production --revision 3 --all
kubectl -n starfleet exec deploy/shuttle -- curl -fsS http://scout.starfleet-production/
```

Revision 2 contains `release-ready`; revision 3 contains `temporary`. Restore the stored working revision:

```sh
helm rollback scout 2 -n starfleet-production --wait=watcher --timeout 180s
kubectl -n starfleet-production rollout status deploy/scout --timeout=180s
helm history scout -n starfleet-production
kubectl -n starfleet exec deploy/shuttle -- curl -fsS http://scout.starfleet-production/
```

The rollback adds a revision rather than erasing history. Check that the latest operation names revision 2 as its rollback target and that the response contains version `6.15.0` and message `release-ready`. Chart authoring is covered in the preceding independent lab.
