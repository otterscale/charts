VERSION := 1.65.0
UPSTREAM := https://github.com/kubevirt/containerized-data-importer/releases/download/v$(VERSION)

.PHONY: vendor
vendor:
	curl -sSL -o templates/cdi-operator.yaml $(UPSTREAM)/cdi-operator.yaml
	@echo "Vendored CDI v$(VERSION)"
