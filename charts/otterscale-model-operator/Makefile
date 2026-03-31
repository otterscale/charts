VERSION := 1.0.0
UPSTREAM := https://github.com/otterscale/model-operator/releases/download/v$(VERSION)

.PHONY: vendor
vendor:
	curl -sSL -o templates/model-operator.yaml $(UPSTREAM)/install.yaml
	@echo "Vendored Model v$(VERSION)"
