GDEXTENSION_DIR ?= /home/aandriam/Godot/godot_test_gdextension

.PHONY: all clean re

all:
	cd $(GDEXTENSION_DIR) && scons compiledb=yes

clean:
	cd $(GDEXTENSION_DIR) && scons -c

re: clean all
	@echo "Rebuild complete"
