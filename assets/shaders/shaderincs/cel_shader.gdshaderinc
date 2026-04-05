group_uniforms CelShading.Ramp;
uniform sampler2D cel_ramp         : source_color, filter_linear, repeat_disable;
uniform sampler2D cel_specular_ramp : source_color, filter_linear, repeat_disable;

group_uniforms CelShading.Controls;
uniform float light_wrap                    : hint_range(-2.0,  2.0)  = 0.3;
uniform float steepness                     : hint_range( 1.0,  8.0)  = 1.0;
uniform float shadow_strength               : hint_range( 0.0,  1.0)  = 1.0;
uniform float point_light_attenuation_curve : hint_range( 0.1,  4.0)  = 1.0;

group_uniforms CelShading.Specular;
uniform float specular_shininess : hint_range(  1.0, 256.0) = 32.0;
uniform float specular_strength  : hint_range(  0.0,   1.0) =  0.0;

group_uniforms CelShading.Dithering;
uniform bool  use_dither         = false;
uniform float dither_strength    : hint_range(0.0, 1.0) = 0.1;
uniform bool  dither_directional = false;

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

vec3 _ramp_floor() {
    return textureLod(cel_ramp, vec2(mix(0.5, 0.0, shadow_strength), 0.5), 0.0).rgb;
}

vec3 toon_vertex(mat3 normal_matrix, vec3 normal) {
    return normalize(normal_matrix * normal);
}

void toon_fragment(out vec3 albedo, out vec3 emission) {
    albedo   = vec3(1.0);
    emission = _ramp_floor();
}

void toon_light(
        vec3  surface_normal,
        vec3  light_dir,
        vec3  view_dir,
        vec3  light_color,
        float attenuation,
        bool  light_is_directional,
        vec3  world_pos,
        vec3  cam_right,
        vec3  cam_up,
        inout vec3  diffuse_light,
        inout vec3  specular_light,
        out   float lit_amount)
{
    bool do_dither = use_dither && (dither_directional || !light_is_directional);

    float att = light_is_directional
        ? attenuation
        : pow(clamp(attenuation, 0.0, 1.0), point_light_attenuation_curve);

    float luma         = dot(light_color, vec3(0.2126, 0.7152, 0.0722));
    float luma_safe    = max(luma, 0.001);
    vec3  chromaticity = clamp(light_color / luma_safe, 0.0, 3.0);

    float att_output = 1.0;

    float NdotL           = dot(surface_normal, light_dir);
    float diffuse_wrapped = clamp(NdotL + light_wrap, 0.0, 1.0);
    float diffuse_raw     = clamp(diffuse_wrapped + (att - 1.0), 0.0, 1.0);
    float band_eval       = clamp(diffuse_raw * steepness, 0.0, 1.0);

    if (do_dither) {
        float bayer_val = _toon_bayer(_toon_world_pixel(world_pos, cam_right, cam_up));
        band_eval = clamp(band_eval + (bayer_val - 0.5) * dither_strength * 0.25, 0.0, 1.0);
    }

    vec3 ramp_color = textureLod(cel_ramp, vec2(band_eval, 0.5), 0.0).rgb;
    vec3 ramp_floor = _ramp_floor();

    diffuse_light += (ramp_color - ramp_floor)
                     * sqrt(luma * 0.32)
                     * chromaticity
                     * att_output;

    vec3  half_dir   = normalize(light_dir + view_dir);
    float NdotH      = clamp(dot(surface_normal, half_dir), 0.0, 1.0);
    float spec_uv    = pow(NdotH, specular_shininess);
    vec3  spec_color = textureLod(cel_specular_ramp, vec2(spec_uv, 0.5), 0.0).rgb;

    float spec_shadow_mask = smoothstep(0.0, 1.0, band_eval * 4.0);

    specular_light += spec_color
                      * spec_shadow_mask
                      * specular_strength
                      * chromaticity
                      * att_output;

    lit_amount = clamp(band_eval * att_output * sqrt(luma * 0.32), 0.0, 1.0);
}