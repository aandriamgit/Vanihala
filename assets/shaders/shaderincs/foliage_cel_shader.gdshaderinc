group_uniforms CelShading.Ramp;
uniform sampler2D cel_ramp        : source_color, filter_linear, repeat_disable;
uniform sampler2D cel_ramp_accent : source_color, filter_linear, repeat_disable;

group_uniforms CelShading.Controls;
uniform float light_wrap      : hint_range(-2.0,  2.0)  = 0.3;
uniform float steepness       : hint_range( 1.0,  8.0)  = 1.0;
uniform float shadow_strength : hint_range( 0.0,  1.0)  = 1.0;

group_uniforms CelShading.PointLight;
uniform float point_light_attenuation_curve : hint_range(0.1, 4.0) = 1.0;

group_uniforms CelShading.AdditiveLightPass;
uniform float additive_light_strength : hint_range(0.0, 0.5) = 0.0;

group_uniforms CelShading.MultiLight;
uniform float chromaticity_clamp : hint_range(1.0,  8.0) = 3.0;
uniform bool  light_cap_enabled                          = false;
uniform float light_cap_max      : hint_range(0.25, 4.0) = 1.5;

group_uniforms CelShading.Dithering;
uniform bool  use_dither         = false;
uniform float dither_strength    : hint_range(0.0, 1.0) = 0.1;
uniform bool  dither_directional = false;

group_uniforms CelShading.Structure;
uniform float shadow_floor_emission_scale : hint_range(0.0, 1.0) = 1.0;

group_uniforms CelShading.Billboard;
uniform int billboard_mode : hint_range(0, 1, 1) = 0;

group_uniforms;

float _toon_bayer(vec2 coords) {
    const float bayer[16] = float[16](
         0.0,  8.0,  2.0, 10.0,
        12.0,  4.0, 14.0,  6.0,
         3.0, 11.0,  1.0,  9.0,
        15.0,  7.0, 13.0,  5.0
    );
    ivec2 p = ivec2(floor(coords)) & ivec2(3);
    return bayer[p.y * 4 + p.x] / 16.0;
}

vec2 _toon_world_pixel(vec3 world_pos, vec3 cam_right, vec3 cam_up) {
    vec3 dx = dFdx(world_pos);
    vec3 dy = dFdy(world_pos);
    float sx = dot(dx, cam_right);
    float sy = dot(dy, cam_up);
    return vec2(
        floor(dot(world_pos, cam_right) / max(abs(sx), 1e-6)),
        floor(dot(world_pos, cam_up)    / max(abs(sy), 1e-6))
    );
}

vec3 _ramp_floor(float var_type, vec3 tex_albedo) {
    vec3 r1 = textureLod(cel_ramp,        vec2(mix(0.5, 0.0, shadow_strength), 0.5), 0.0).rgb;
    vec3 r2 = textureLod(cel_ramp_accent, vec2(mix(0.5, 0.0, shadow_strength), 0.5), 0.0).rgb;
    if (var_type < 0.5) return r1;
    if (var_type < 1.5) return r2;
    float is_white = smoothstep(0.8, 0.95, min(tex_albedo.r, min(tex_albedo.g, tex_albedo.b)));
    vec3  r2_luma  = vec3(dot(r2, vec3(0.2126, 0.7152, 0.0722))) * 1.5;
    return mix(r2_luma, r2, is_white);
}

// Returns a stable per-instance seed in [0, 1) from a world-space XZ position.
float toon_location_seed(vec2 location) {
    return fract(sin(dot(location, vec2(12.9898, 78.233))) * 43758.5453123);
}

// 2D rotation matrix for view-space wind sway.
mat4 toon_view_rotate(float angle) {
    return mat4(
        vec4( cos(angle), -sin(angle), 0.0, 0.0),
        vec4( sin(angle),  cos(angle), 0.0, 0.0),
        vec4(0.0, 0.0, 1.0, 0.0),
        vec4(0.0, 0.0, 0.0, 1.0)
    );
}

// Builds the billboard world matrix for the given world-space origin.
// Uses billboard_mode: 0 = full (camera-facing), 1 = Y-axis (upright).
// Pass INV_VIEW_MATRIX columns directly.
mat4 toon_billboard_matrix(vec3 origin, mat4 inv_view) {
    if (billboard_mode == 0) {
        return mat4(
            inv_view[0],
            inv_view[1],
            inv_view[2],
            vec4(origin, 1.0)
        );
    } else {
        vec3 b_right = normalize(vec3(inv_view[0].x, 0.0, inv_view[0].z));
        vec3 b_up    = vec3(0.0, 1.0, 0.0);
        vec3 b_back  = cross(b_right, b_up);
        return mat4(
            vec4(b_right, 0.0),
            vec4(b_up,    0.0),
            vec4(b_back,  0.0),
            vec4(origin,  1.0)
        );
    }
}

// Remaps UV into the correct quadrant of a 2x2 tilemap atlas for the given variation.
vec2 toon_variation_uv(vec2 uv, float var_type) {
    if (var_type < 0.5) return uv * 0.5;
    if (var_type < 1.5) return uv * 0.5 + vec2(0.5, 0.0);
    if (var_type < 2.5) return uv * 0.5 + vec2(0.0, 0.5);
                        return uv * 0.5 + vec2(0.5, 0.5);
}

vec3 toon_vertex(mat3 normal_matrix, vec3 normal) {
    return normalize(normal_matrix * normal);
}

void toon_fragment(out vec3 albedo, out vec3 emission, float var_type, vec3 tex_albedo) {
    albedo   = vec3(1.0);
    emission = _ramp_floor(var_type, tex_albedo) * shadow_floor_emission_scale;
}

void toon_light(
        vec3  surface_normal,
        vec3  light_dir,
        vec3  light_color,
        float attenuation,
        bool  light_is_directional,
        vec3  world_pos,
        vec3  cam_right,
        vec3  cam_up,
        inout vec3 diffuse_light,
        float var_type,
        vec3  tex_albedo)
{
    bool do_dither = use_dither && (dither_directional || !light_is_directional);

    float att = light_is_directional
        ? attenuation
        : pow(clamp(attenuation, 0.0, 1.0), point_light_attenuation_curve);

    float luma         = dot(light_color, vec3(0.2126, 0.7152, 0.0722));
    float luma_safe    = max(luma, 0.001);
    vec3  chromaticity = clamp(light_color / luma_safe, 0.0, chromaticity_clamp);

    float att_output = 1.0;

    float NdotL           = dot(surface_normal, light_dir);
    float diffuse_wrapped = clamp(NdotL + light_wrap, 0.0, 1.0);
    float diffuse_raw     = clamp(diffuse_wrapped + (att - 1.0), 0.0, 1.0);
    float band_eval       = clamp(diffuse_raw * steepness, 0.0, 1.0);

    if (do_dither) {
        float bayer_val = _toon_bayer(_toon_world_pixel(world_pos, cam_right, cam_up));
        band_eval = clamp(band_eval + (bayer_val - 0.5) * dither_strength * 0.25, 0.0, 1.0);
    }

    vec3 r1_color = textureLod(cel_ramp,        vec2(band_eval, 0.5), 0.0).rgb;
    vec3 r2_color = textureLod(cel_ramp_accent, vec2(band_eval, 0.5), 0.0).rgb;

    vec3 ramp_color;
    if (var_type < 0.5) {
        ramp_color = r1_color;
    } else if (var_type < 1.5) {
        ramp_color = r2_color;
    } else {
        float is_white = smoothstep(0.8, 0.95, min(tex_albedo.r, min(tex_albedo.g, tex_albedo.b)));
        vec3  r2_luma  = vec3(dot(r2_color, vec3(0.2126, 0.7152, 0.0722))) * 1.5;
        ramp_color = mix(r2_luma, r2_color, is_white);
    }
    vec3 ramp_floor = _ramp_floor(var_type, tex_albedo);

    diffuse_light += (ramp_color - ramp_floor)
                     * sqrt(luma * 0.32)
                     * chromaticity
                     * att_output;

    if (!light_is_directional) {
        float ramp_brightness = dot(ramp_color, vec3(0.2126, 0.7152, 0.0722));
        float colorfulness    = clamp(distance(chromaticity, vec3(1.0)), 0.0, 1.0);
        diffuse_light += chromaticity
                         * ramp_brightness
                         * colorfulness
                         * additive_light_strength
                         * att_output;
    }

    if (light_cap_enabled) {
        float total_luma = dot(diffuse_light, vec3(0.2126, 0.7152, 0.0722));
        if (total_luma > light_cap_max) {
            diffuse_light *= light_cap_max / max(total_luma, 0.001);
        }
    }
}