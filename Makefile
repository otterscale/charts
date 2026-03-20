CHARTS := $(sort $(dir $(wildcard charts/*/Chart.yaml)))

.PHONY: dep-update
dep-update:
	@for chart in $(CHARTS); do \
		echo "==> helm dependency update $$chart"; \
		helm dependency update "$$chart" || exit 1; \
	done

.PHONY: dep-update-%
dep-update-%:
	helm dependency update charts/$*
