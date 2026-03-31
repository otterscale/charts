VERSION := 1.0.0
UPSTREAM := https://github.com/otterscale/workload-operator/releases/download/v$(VERSION)

.PHONY: vendor
vendor:
	curl -sSL -o templates/workload-operator.yaml $(UPSTREAM)/install.yaml
	@echo "Vendored Workload v$(VERSION)"
