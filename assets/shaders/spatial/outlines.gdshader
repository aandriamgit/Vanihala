shader_type spatial;
render_mode depth_prepass_alpha, unshaded;

uniform sampler2D screen_texture           : hint_screen_texture,           repeat_disable, filter_nearest;
uniform sampler2D depth_texture            : hint_depth_texture,            repeat_disable, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

group_uniforms colors;
uniform vec3 line_tint   : source_color = vec3(0.05, 0.05, 0.08);
uniform vec3 crease_tint : source_color = vec3(1.00, 0.55, 0.10);
uniform bool flip_palettes = false;

group_uniforms line;
uniform bool  line_overlay = false;
uniform float line_alpha   : hint_range(0.0, 1.0, 0.01) = 1.0;

group_uniforms crease;
uniform bool  crease_overlay = true;
uniform float crease_alpha   : hint_range(0.0, 1.0, 0.01) = 1.0;

group_uniforms sampling;
uniform float kernel_radius : hint_range(0.5, 4.0, 0.5) = 1.0;

group_uniforms line_detect;
uniform float zdelta_cutoff  : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float angle_z_cutoff : hint_range(0.0, 1.0, 0.01) = 0.50;
uniform float angle_z_scale                                = 2.0;

group_uniforms crease_detect;
uniform float convex_cutoff    = 0.10;
uniform float crease_feather   : hint_range(0.0, 0.5, 0.005) = 0.0;
uniform float concave_cutoff   = 0.01;
uniform float concave_z_cutoff = 0.50;

// ── helpers ──────────────────────────────────────────────────────────────────

vec3 unproject(vec2 uv, float d, mat4 inv_proj) {
    vec4 p = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
    return p.xyz / p.w;
}

vec3 fetch_viewpos(vec2 uv, mat4 inv_projection_matrix) {
    float d = textureLod(depth_texture, uv, 0.0).r;
    return unproject(uv, d, inv_projection_matrix);
}

// op 0 = replace, op 3 = overlay
vec3 composite(vec3 dst, vec3 src, bool overlay) {
    if (overlay)
        return clamp(
            mix(2.0 * dst * src,
                1.0 - 2.0 * (1.0 - dst) * (1.0 - src),
                step(0.5, dst)),
            vec3(0.0), vec3(1.0));
    return clamp(src, vec3(0.0), vec3(1.0));
}

// ── fragment ─────────────────────────────────────────────────────────────────

void fragment() {
    vec3 px      = texture(screen_texture, SCREEN_UV).rgb;
    vec2 step_uv = (1.0 / VIEWPORT_SIZE) * kernel_radius;

    vec3  vp[9];
    vec3  vn[9];
    float cx[9];

    for (int k = 0; k < 9; k++) {
        vec2 off = vec2(ivec2(k % 3 - 1, k / 3 - 1));
        vec2 uv  = SCREEN_UV + off * step_uv;
        vp[k] = fetch_viewpos(uv, INV_PROJECTION_MATRIX);
        vn[k] = texture(normal_roughness_texture, uv).xyz * 2.0 - 1.0;
    }

    float facing   = 1.0 - vn[4].z;
    float t01      = clamp((facing - angle_z_cutoff) / (1.0 - angle_z_cutoff), 0.0, 1.0);
    float z_thresh = zdelta_cutoff * (t01 * angle_z_scale + 1.0);

    float concave_sum = 0.0;
    for (int k = 0; k < 9; k++) {
        vec2  off2 = vec2(ivec2(k % 3 - 1, k / 3 - 1));
        vec3  cr   = cross(vn[4], vn[k]);
        cx[k]      = dot(cr, vec3(off2.yx, 0.0));
        concave_sum += step(concave_cutoff, -cx[k])
                     * step(vp[k].z - vp[4].z, concave_z_cutoff);
    }

    float crease_weight = 0.0;
    for (int k = 1; k <= 7; k += 2) {
        float base_nb = (k < 4) ? 1e-5 : 0.0;
        bool  zdiff   = abs(vp[k].z - vp[4].z) < z_thresh;
        bool  zface   = vn[k].z + base_nb > vn[4].z;
        float soft    = (crease_feather > 0.0)
            ? smoothstep(convex_cutoff, convex_cutoff + crease_feather, cx[k])
            : (cx[k] > convex_cutoff ? 1.0 : 0.0);
        crease_weight += (zdiff && zface) ? soft : 0.0;
    }
    if (concave_sum > 0.0) crease_weight = 0.0;

    bool has_line =
        vp[4].z - vp[1].z > z_thresh ||
        vp[4].z - vp[3].z > z_thresh ||
        vp[4].z - vp[5].z > z_thresh ||
        vp[4].z - vp[7].z > z_thresh;

    vec3 c_line   = flip_palettes ? crease_tint : line_tint;
    vec3 c_crease = flip_palettes ? line_tint   : crease_tint;

    vec3 result = px;

    if (has_line) {
        result = mix(px, composite(px, c_line, line_overlay), line_alpha);
    } else if (crease_weight > 0.0) {
        float a = clamp(crease_weight, 0.0, 1.0) * crease_alpha;
        result  = mix(px, composite(px, c_crease, crease_overlay), min(a, 1.0));
    }

    ALBEDO = result;
}