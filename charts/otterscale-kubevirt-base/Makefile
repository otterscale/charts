VERSION := 1.7.2
UPSTREAM := https://github.com/kubevirt/kubevirt/releases/download/v$(VERSION)

.PHONY: vendor
vendor:
	curl -sSL -o templates/kubevirt-operator.yaml $(UPSTREAM)/kubevirt-operator.yaml
	curl -sSL -o templates/kubevirt-cr.yaml $(UPSTREAM)/kubevirt-cr.yaml
	@echo "Vendored KubeVirt v$(VERSION)"
