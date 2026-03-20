VERSION := 1.4.1
UPSTREAM := https://github.com/kubernetes-sigs/gateway-api/releases/download/v$(VERSION)

.PHONY: vendor
vendor:
	curl -sSL -o templates/standard-install.yaml $(UPSTREAM)/standard-install.yaml
	@echo "Vendored Gateway API v$(VERSION)"
