# perfscale migration of HariKube's kubernetes-performance-challenge.
#   make setup     apply CRDs + ServiceAccount (prints nothing; see `make env`)
#   make smoke     1 VU, 5s — proves the scenario end to end
#   make start     10 VUs, 1h — the challenge load (config.yaml)
#   make cleanup   delete every created custom resource
PERFSCALE ?= perfscale

ENV = eval "$$(scripts/setup.sh)"

.PHONY: setup smoke start cleanup lint

setup:
	@scripts/setup.sh >/dev/null && echo "cluster ready"

lint:
	$(PERFSCALE) lint test.yaml config.yaml

smoke:
	@$(ENV) && printf 'vus: 1\nduration: 5s\nlibraries:\n  - use: "@std/random@v1"\n    capabilities: []\n' > .smoke.yaml \
	  && $(PERFSCALE) run -f test.yaml -c .smoke.yaml --quiet; rm -f .smoke.yaml

start:
	@mkdir -p results && $(ENV) && $(PERFSCALE) run -f test.yaml -c config.yaml --quiet \
	  --summary-export results/$$(date +%s)_sum.json

cleanup:
	@scripts/cleanup.sh
