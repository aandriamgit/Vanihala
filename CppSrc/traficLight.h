#pragma once

#include "godot_cpp/classes/control.hpp"
#include "godot_cpp/classes/ref.hpp"
#include "godot_cpp/classes/texture2d.hpp"
#include "godot_cpp/classes/texture_rect.hpp"
#include "godot_cpp/classes/wrapped.hpp"
#include "godot_cpp/core/binder_common.hpp"

using namespace	godot;

enum			traficLightType
{
	TRAFIC_LIGHT_GO,
	TRAFIC_LIGHT_STOP,
	TRAFIC_LIGHT_CAUTION,
};

class traficLight : public Control
{
  private:
	GDCLASS(traficLight, Control);
	TextureRect *texture_rect;
	Ref<Texture2D> goTexture;
	Ref<Texture2D> stopTexture;
	Ref<Texture2D> cautionTexture;
	traficLightType lightType;

  protected:
	static void _bind_methods();
	void _notification(int p_what);

  public:
	traficLight();
	void setGoTexture(const Ref<Texture2D> &texture);
	void setStopTexture(const Ref<Texture2D> &texture);
	void setCautionTexture(const Ref<Texture2D> &texture);
	Ref<Texture2D> getGoTexture() const;
	Ref<Texture2D> getStopTexture() const;
	Ref<Texture2D> getCautionTexture() const;
	void setTraficLightType(traficLightType p_type);
	traficLightType getTraficLightType() const;
};

VARIANT_ENUM_CAST(traficLightType);
