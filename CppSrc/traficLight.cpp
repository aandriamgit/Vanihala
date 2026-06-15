#include "./traficLight.h"
#include "godot_cpp/classes/control.hpp"
#include "godot_cpp/classes/global_constants.hpp"
#include "godot_cpp/classes/ref.hpp"
#include "godot_cpp/core/class_db.hpp"
#include "godot_cpp/core/memory.hpp"
#include "godot_cpp/core/object.hpp"
#include "godot_cpp/core/property_info.hpp"
#include "godot_cpp/variant/variant.hpp"

void traficLight::_bind_methods()
{
	ClassDB::bind_method(D_METHOD("setGoTexture", "texture"),
		&traficLight::setGoTexture);
	ClassDB::bind_method(D_METHOD("setStopTexture", "texture"),
		&traficLight::setStopTexture);
	ClassDB::bind_method(D_METHOD("setCautionTexture", "texture"),
		&traficLight::setCautionTexture);
	ClassDB::bind_method(D_METHOD("getGoTexture"), &traficLight::getGoTexture);
	ClassDB::bind_method(D_METHOD("getStopTexture"),
		&traficLight::getStopTexture);
	ClassDB::bind_method(D_METHOD("getCautionTexture"),
		&traficLight::getCautionTexture);
	ClassDB::bind_method(D_METHOD("setTraficLightType", "type"),
		&traficLight::setTraficLightType);
	ClassDB::bind_method(D_METHOD("getTraficLightType"),
		&traficLight::getTraficLightType);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "goTexture",
			godot::PROPERTY_HINT_RESOURCE_TYPE, "Texture2D"), "setGoTexture",
		"getGoTexture");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "stopTexture",
			godot::PROPERTY_HINT_RESOURCE_TYPE, "Texture2D"), "setStopTexture",
		"getStopTexture");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "cautionTexture",
			godot::PROPERTY_HINT_RESOURCE_TYPE, "Texture2D"),
		"setCautionTexture", "getCautionTexture");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "lightType",
			godot::PROPERTY_HINT_ENUM, "Go,Stop,Caution"), "setTraficLightType",
		"getTraficLightType");
	BIND_ENUM_CONSTANT(traficLightType::TRAFIC_LIGHT_GO);
	BIND_ENUM_CONSTANT(traficLightType::TRAFIC_LIGHT_STOP);
	BIND_ENUM_CONSTANT(traficLightType::TRAFIC_LIGHT_CAUTION);
}

void traficLight::_notification(int p_what)
{
	switch (p_what)
	{
	case NOTIFICATION_READY:
		setTraficLightType(lightType);
		break ;
	}
}

traficLight::traficLight()
{
	texture_rect = memnew(TextureRect);
	add_child(texture_rect);
	texture_rect->set_anchors_preset(PRESET_FULL_RECT);
	lightType = TRAFIC_LIGHT_STOP;
}
void traficLight::setGoTexture(const Ref<Texture2D> &texture)
{
	goTexture = texture;
}

void traficLight::setStopTexture(const Ref<Texture2D> &texture)
{
	stopTexture = texture;
}

void traficLight::setCautionTexture(const Ref<Texture2D> &texture)
{
	cautionTexture = texture;
}

Ref<Texture2D> traficLight::getGoTexture() const
{
	return (goTexture);
}

Ref<Texture2D> traficLight::getStopTexture() const
{
	return (stopTexture);
}

Ref<Texture2D> traficLight::getCautionTexture() const
{
	return (cautionTexture);
}

void traficLight::setTraficLightType(traficLightType p_type)
{
	lightType = p_type;
	switch (p_type)
	{
	case TRAFIC_LIGHT_GO:
		texture_rect->set_texture(goTexture);
		break ;
	case TRAFIC_LIGHT_STOP:
		texture_rect->set_texture(stopTexture);
		break ;
	case TRAFIC_LIGHT_CAUTION:
		texture_rect->set_texture(cautionTexture);
		break ;
	}
}

traficLightType traficLight::getTraficLightType() const
{
	return (lightType);
}
