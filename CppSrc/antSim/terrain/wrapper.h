#pragma once

#include "godot_cpp/classes/mesh_instance3d.hpp"
#include "godot_cpp/classes/node3d.hpp"
#include "godot_cpp/classes/world_environment.hpp"
#include "godot_cpp/variant/packed_vector3_array.hpp"
#include "terrain.hpp"

using namespace	godot;

class terrainAPI : public godot::Node3D
{
  private:
	GDCLASS(terrainAPI, Node3D);
	void initGeography();
	void initArrays(PackedVector3Array &vertices, PackedVector3Array &normals,
		PackedInt32Array &indices);

  protected:
	MeshInstance3D *_mi;
	WorldEnvironment *_we;
	terrain _terrain;
	static void _bind_methods();

  public:
	terrainAPI();
	void _ready() override;
	void _process(float delta);
};
