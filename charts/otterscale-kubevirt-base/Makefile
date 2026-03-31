VERSION := 1.8.1
UPSTREAM := https://github.com/kubevirt/kubevirt/releases/download/v$(VERSION)

.PHONY: vendor
vendor:
	curl -sSL -o templates/kubevirt-operator.yaml $(UPSTREAM)/kubevirt-operator.yaml
	curl -sSL -o templates/kubevirt-cr.yaml $(UPSTREAM)/kubevirt-cr.yaml
	@echo "Vendored KubeVirt v$(VERSION)"
