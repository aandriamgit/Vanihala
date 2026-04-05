shader_type canvas_item;
render_mode unshaded;

uniform vec2 texel_offset = vec2(0.0);

vec4 sharp_sample(sampler2D tex, vec2 coords, vec2 px) {
    vec2 fw = clamp(fwidth(coords) / px, 1e-5, 1.0);
    vec2 grid = coords / px - 0.5 * fw;
    vec2 blend = smoothstep(1.0 - fw, vec2(1.0), fract(grid));
    vec2 final_uv = (floor(grid) + 0.5 + blend) * px;
    return textureLod(tex, final_uv, 0.0);
}

void fragment() {
    vec2 shifted = UV - texel_offset * TEXTURE_PIXEL_SIZE;
    COLOR = sharp_sample(TEXTURE, shifted, TEXTURE_PIXEL_SIZE);
}