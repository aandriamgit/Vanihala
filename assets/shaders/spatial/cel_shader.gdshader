shader_type spatial;
render_mode ambient_light_disabled, blend_mix, depth_draw_opaque, cull_back;
#include "res://assets/shaders/shaderincs/cel_shader.gdshaderinc"

varying vec3  world_normal;
varying vec3  world_pos;
varying float line_mask;

void vertex() {
    world_normal = toon_vertex(MODEL_NORMAL_MATRIX, NORMAL);
    world_pos    = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 toon_albedo;
    vec3 toon_emission;
    toon_fragment(toon_albedo, toon_emission);

    ALBEDO   = toon_albedo;
    EMISSION = toon_emission;
}

void light() {
    if (line_mask > 0.25) {
        float ndotl    = max(0.0, dot(NORMAL, LIGHT));
        DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * ndotl;
        SPECULAR_LIGHT = vec3(0.0);
    } else {
        float lit_amount;
        toon_light(
            NORMAL,
            LIGHT,
            VIEW,
            LIGHT_COLOR,
            ATTENUATION,
            LIGHT_IS_DIRECTIONAL,
            world_pos,
            INV_VIEW_MATRIX[0].xyz,
            INV_VIEW_MATRIX[1].xyz,
            DIFFUSE_LIGHT,
            SPECULAR_LIGHT,
            lit_amount
        );
    }
}