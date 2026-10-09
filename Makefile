# Direct build-tool invocations through make's fixed command interface.
ICK ?= ick
ICK_LINK_FLAGS ?= -fno-link-libatomic
BUILD ?= build/tests
CFLAGS ?= -O2
WARN = -std=c11 -Wall -Wextra -Werror

.PHONY: test
test: $(BUILD)/test-sprott-system $(BUILD)/functorial-equivalence
	$(BUILD)/test-sprott-system
	$(BUILD)/functorial-equivalence

$(BUILD)/test-sprott-system: src/sprott_system.c src/sprott_system.h tests/test_sprott_system.c
	mkdir -p $(@D)
	$(ICK) $(ICK_LINK_FLAGS) $(WARN) $(CFLAGS) -Isrc src/sprott_system.c tests/test_sprott_system.c -lm -o $@

$(BUILD)/reference.o: tests/reference/sprott_system.c src/sprott_system.h
	mkdir -p $(@D)
	$(ICK) $(WARN) $(CFLAGS) -Isrc -Dsprott_parameter_count=reference_sprott_parameter_count -Dsprott_reset=reference_sprott_reset -Dsprott_derivative=reference_sprott_derivative -Dsprott_rk4_step=reference_sprott_rk4_step -c $< -o $@

$(BUILD)/functorial-equivalence: src/sprott_system.c src/sprott_system.h tests/functorial_equivalence.c $(BUILD)/reference.o
	$(ICK) $(ICK_LINK_FLAGS) $(WARN) $(CFLAGS) -Isrc src/sprott_system.c tests/functorial_equivalence.c $(BUILD)/reference.o -lm -o $@
