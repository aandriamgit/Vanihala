#pragma once

#include "godot_cpp/classes/object.hpp"
#include "godot_cpp/classes/wrapped.hpp"

using namespace	godot;

class Summator : public Object
{
	GDCLASS(Summator, Object);

	int count;

  protected:
	static void _bind_methods();

  public:
	void add(const int &p_value);
	void reset();
	int get_total();

	Summator();
};
