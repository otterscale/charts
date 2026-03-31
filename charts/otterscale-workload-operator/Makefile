VERSION := 0.9.1
UPSTREAM := https://github.com/otterscale/workload-operator/releases/download/v$(VERSION)

.PHONY: vendor
vendor:
	curl -sSL -o templates/workload-operator.yaml $(UPSTREAM)/install.yaml
	@echo "Vendored Workload v$(VERSION)"
