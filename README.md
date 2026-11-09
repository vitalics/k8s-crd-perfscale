# Kubernetes CRD performance — HariKube challenge on perfscale

A migration of [HariKube's kubernetes-performance-challenge](https://github.com/HariKube/kubernetes-performance-challenge)
k6 script (`k6_custom_resource_6_read_write.js`) to [perfscale](https://github.com/Perfscale/perfscale)'s
native YAML engine. Same workload, no JavaScript runtime: every iteration
creates six Crossplane GCP custom resources (Address, Firewall,
GlobalAddress, Network, Router, Subnetwork) and reads each back by label
selector — 12 Kubernetes API calls per iteration.

This repo is a migration example, not a challenge submission.

> Requires **perfscale ≥ 0.32.0** (`npm i -g @perfscale/exe`). Older builds
> repeat generated names from the second iteration on and the creates fail
> with 409 Conflict ([Perfscale/perfscale#46](https://github.com/Perfscale/perfscale/pull/46)).

## Quick start

```sh
# any cluster in your kubeconfig (docker-desktop, kind, k3d, a real one)
export KUBE_CONTEXT=docker-desktop
make smoke     # 1 VU, 5s — proves the scenario end to end
make start     # 10 VUs, 1h — the challenge load (config.yaml)
make cleanup   # delete every custom resource the run created
```

`scripts/setup.sh` (called by `smoke`/`start`) applies the provider-gcp
CRDs — the same set the challenge's Makefile applies; no Crossplane
controller is installed, so the test measures the API server and its
storage only — and mints a token for a ServiceAccount scoped to
`compute.gcp.crossplane.io`.

## k6 → perfscale mapping

| k6 (`k6_custom_resource_6_read_write.js`) | perfscale (`test.yaml` / `config.yaml`) |
|---|---|
| `options.tlsAuth` client certificate (mTLS) | `authorization: Bearer ${{ env.API_TOKEN }}` — ServiceAccount token from `scripts/setup.sh`; `std/http@v1` has no client-certificate option |
| `--insecure-skip-tls-verify` | `insecure: true` per request |
| `http.post(url, JSON.stringify(payload))` | `std/http@v1` with `method: POST` and a YAML `body:` (sent as JSON) |
| `check(res, { 'Status is 201': … })` | `check: { status: 201 }` |
| `name = k6s-${Date.now()}-${uuidv4()}-${iter}` built once per iteration | `ps-${random.uuid4(id)}` in the first POST (the keyed call is shared within that body); later steps read it back from the response — `${{ address.body.metadata.name }}` |
| `created` label = `Date.now()` | `${now_ms}` in the first POST, reused via `${{ address.body.metadata.labels.created }}` |
| `Promise.allSettled([...])` over `http.post` | sequential steps — k6's `http.post` is synchronous, so the k6 script already runs the 12 calls one after another |
| `--vus=10 --duration=1h` | `vus: 10`, `duration: 1h` |
| `--iterations=100000` | no iteration cap in perfscale: the run is time-bounded |
| `--summary-export` | `--summary-export results/<ts>_sum.json` (`make start`) |

## Results (local, docker-desktop on Apple Silicon)

10 VUs × 60s, cluster wiped between runs, alternating engines (second
pair shown; the first perfscale run hit a cold API server):

| | requests/s | iterations/s | p95 | failed | CPU (u+s) | peak RSS |
|---|---:|---:|---:|---:|---:|---:|
| perfscale (YAML) | 723 | 60.4 | 42.5 ms | 0.00% | 7.4 s | 25 MiB |
| k6 v1.5 (original script) | 501 | 41.7 | 63.6 ms | 0.00% | 14.9 s | 290 MiB |

On a laptop cluster the API server is the bottleneck and run-to-run noise is
large (±30%); the stable gaps are the generator's own cost — about half the
CPU and a twelfth of the memory of k6 for the same scenario.

## Licence

MIT (see `LICENSE`). The resource payloads come from HariKube's script,
BSD 3-Clause — see `LICENSE-HARIKUBE`.
