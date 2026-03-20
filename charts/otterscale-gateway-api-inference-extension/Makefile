VERSION := 1.3.1
UPSTREAM := https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/v$(VERSION)

.PHONY: vendor
vendor:
	curl -sSL -o templates/manifests.yaml $(UPSTREAM)/manifests.yaml
	@echo "Vendored Gateway API Inference Extension v$(VERSION)"
