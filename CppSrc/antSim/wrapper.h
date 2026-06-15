#pragma once

#include "antSim.h"
#include "godot_cpp/classes/node3d.hpp"

using namespace	godot;

class antSim : public godot::Node3D
{
  private:
	GDCLASS(antSim, Node3D);
	AntColony colony;

  protected:
	static void _bind_methods();

  public:
	void _ready() override;
	void _process(float delta);
	void resetColony() const;
	std::size_t getAntCount;
};
