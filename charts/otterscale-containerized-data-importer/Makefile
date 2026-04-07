VERSION := 1.65.0
UPSTREAM := https://github.com/kubevirt/containerized-data-importer/releases/download/v$(VERSION)

.PHONY: vendor
vendor:
	curl -sSL -o templates/cdi-cr.yaml $(UPSTREAM)/cdi-cr.yaml
	@echo "Vendored CDI v$(VERSION)"
