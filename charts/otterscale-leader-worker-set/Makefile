VERSION := 0.7.0
UPSTREAM := https://github.com/kubernetes-sigs/lws/releases/download/v$(VERSION)

.PHONY: vendor
vendor:
	curl -sSL -o templates/manifests.yaml $(UPSTREAM)/manifests.yaml
	@echo "Vendored LeaderWorkerSet v$(VERSION)"
