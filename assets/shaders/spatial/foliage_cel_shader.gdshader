shader_type spatial;
render_mode ambient_light_disabled, depth_prepass_alpha, specular_disabled;

group_uniforms Base;
uniform sampler2D base_texture : source_color, filter_linear, repeat_disable;

group_uniforms Variations;
uniform float var1_probability : hint_range(0.0, 1.0) = 0.1;
uniform float var2_probability : hint_range(0.0, 1.0) = 0.1;
uniform float var3_probability : hint_range(0.0, 1.0) = 0.1;
uniform float accent_depth_pull: hint_range(0.0, 1.0) = 0.1;

group_uniforms Albedo;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float vertical_offset         : hint_range(0.0, 1.0) = 0.25;
uniform float quad_scale              : hint_range(0.0, 1.0) = 1.0;

group_uniforms Lighting;
uniform int lighting_normal_mode : hint_range(0, 1, 1) = 1;

group_uniforms Wind;
uniform float framerate       = 5.0;
uniform bool  quantised       = true;
uniform bool  view_space_sway = true;
uniform float view_sway_speed : hint_range(0.0, 5.0,  0.001) = 0.1;
uniform float view_sway_angle : hint_range(0.0, 45.0, 0.001) = 10.0;

#include "res://assets/shaders/shaderincs/foliage_cel_shader.gdshaderinc"

varying vec3  world_normal;
varying vec3  world_up;
varying vec3  world_pos;
varying vec3  world_cent;
varying vec3  quad_center;
varying float variation_type;
varying vec3  frag_albedo;

void vertex() {
    vec3 object_origin  = MODEL_MATRIX[3].xyz;
    vec3 shifted_origin = object_origin + vec3(0.0, vertical_offset, 0.0);

    world_normal = toon_vertex(MODEL_NORMAL_MATRIX, NORMAL);
    world_up     = normalize((MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);

    VERTEX.xy *= quad_scale;

    float seed = 10.0 * toon_location_seed(object_origin.xz);
    float time = TIME;
    if (quantised) {
        time += mod(seed, 1.0 / framerate);
        time  = round(time * framerate) / framerate;
    }

    if (view_space_sway) {
        float angle     = sin((time + seed) * view_sway_speed * 2.0 * PI) * radians(view_sway_angle);
        const float pivot_y = -0.5;
        VERTEX.y -= pivot_y;
        VERTEX    = (toon_view_rotate(angle) * vec4(VERTEX, 1.0)).xyz;
        VERTEX.y += pivot_y;
    }

    mat4 billboard_world = toon_billboard_matrix(shifted_origin, INV_VIEW_MATRIX);
    MODELVIEW_MATRIX     = VIEW_MATRIX * billboard_world;
    world_pos            = (billboard_world * vec4(VERTEX, 1.0)).xyz;
    world_cent           = shifted_origin;
    quad_center          = (VIEW_MATRIX * vec4(shifted_origin, 1.0)).xyz;

    float var_hash = fract(sin(float(INSTANCE_ID) * 17.382) * 43758.5453);
    variation_type = 0.0;
    if (var_hash < var1_probability) {
        variation_type = 1.0;
    } else if (var_hash < var1_probability + var2_probability) {
        variation_type = 2.0;
    } else if (var_hash < var1_probability + var2_probability + var3_probability) {
        variation_type = 3.0;
    }

    UV = toon_variation_uv(UV, variation_type);

    if (variation_type >= 1.0) {
        MODELVIEW_MATRIX[3].z += accent_depth_pull;
    }
}

void fragment() {
    vec4 tex    = texture(base_texture, UV);
    frag_albedo = tex.rgb;

    toon_fragment(ALBEDO, EMISSION, variation_type, frag_albedo);

    ALBEDO                  = frag_albedo;
    ALPHA                   = tex.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
    EMISSION               *= ALBEDO;
    LIGHT_VERTEX            = quad_center;
}

void light() {
    vec3 lighting_normal;
    if (lighting_normal_mode == 0) {
        lighting_normal = NORMAL;
    } else {
        lighting_normal = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
    }

    toon_light(
        lighting_normal,
        LIGHT,
        LIGHT_COLOR,
        ATTENUATION,
        LIGHT_IS_DIRECTIONAL,
        world_pos,
        INV_VIEW_MATRIX[0].xyz,
        INV_VIEW_MATRIX[1].xyz,
        DIFFUSE_LIGHT,
        variation_type,
        frag_albedo
    );
}