#include "godot_cpp/classes/mesh_instance3d.hpp"
#include "godot_cpp/core/memory.hpp"
#include "godot_cpp/classes/engine.hpp"
#include "terrainSystem.hpp"
#include "wrapper.h"

void terrainAPI::_bind_methods()
{
}

terrainAPI::terrainAPI()
{
}

void terrainAPI::initArrays(PackedVector3Array &vertices,
	PackedVector3Array &normals, PackedInt32Array &indices)
{
	int			ix;
	const int	idxCount = _terrain.indx.size();

	const std::vector<float> &Vert = _terrain.vertices;
	const std::vector<float> &Norm = _terrain.normals;
	const std::vector<uint32_t> &indx = _terrain.indx;
	vertices.resize(getVertMaxIndex(_terrain));
	normals.resize(getVertMaxIndex(_terrain));
	indices.resize(getIndxCount(_terrain));
	Vector3 *vertPtr(vertices.ptrw());
	Vector3 *normPtr(normals.ptrw());
	int32_t *indxPtr(indices.ptrw());
	for (size_t i = 0; i < vertices.size(); ++i)
	{
		ix = i * 3;
		vertPtr[i] = Vector3(Vert[ix], Vert[ix + 1], Vert[ix + 2]);
		normPtr[i] = Vector3(Norm[ix], Norm[ix + 1], Norm[ix + 2]);
	}
	for (int i = 0; i < idxCount; ++i)
		indxPtr[i] = static_cast<int32_t>(indx[i]);
}

void terrainAPI::initGeography()
{
	PackedVector3Array	vertices;
	PackedVector3Array	normals;
	PackedInt32Array	indx;
	Array				arrays;

	initTerrain(_terrain, 512);
	godot::UtilityFunctions::print("Vertices: ", getVertMaxIndex(_terrain),
		"\n");
	godot::UtilityFunctions::print("Indices: ", getIndxCount(_terrain), "\n");
	initArrays(vertices, normals, indx);
	arrays.resize(Mesh::ARRAY_MAX);
	arrays[Mesh::ARRAY_VERTEX] = vertices;
	arrays[Mesh::ARRAY_NORMAL] = normals;
	arrays[Mesh::ARRAY_INDEX] = indx;
	Ref<ArrayMesh> mesh;
	mesh.instantiate();
	mesh->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES, arrays);
	_mi = memnew(MeshInstance3D);
	add_child(_mi);
	_mi->set_mesh(mesh);
}

void terrainAPI::_ready()
{
	if (Engine::get_singleton()->is_editor_hint())
		return;
	initGeography();
}

void terrainAPI::_process(float delta)
{
}
