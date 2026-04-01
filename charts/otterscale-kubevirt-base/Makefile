VERSION := 1.8.1
UPSTREAM := https://github.com/kubevirt/kubevirt/releases/download/v$(VERSION)

.PHONY: vendor
vendor:
	curl -sSL -o templates/kubevirt-operator.yaml $(UPSTREAM)/kubevirt-operator.yaml
	@echo "Vendored KubeVirt v$(VERSION)"
