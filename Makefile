.PHONY: all re

all:
	cd /home/aandriam/Godot/godot_test_gdextension && scons compiledb=yes

clean:
	cd /home/aandriam/Godot/godot_test_gdextension && scons -c

re:
	clear && cd /home/aandriam/Godot/godot_test_gdextension && scons -c && scons compiledb=yes
