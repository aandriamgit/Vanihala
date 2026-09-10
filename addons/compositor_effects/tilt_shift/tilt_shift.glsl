#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D source_img;
layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2D dest_img;

// Pure screen-space tilt-shift: the blur gradient is computed from the
// fragment's Y position on screen, not from the depth buffer. The camera
// is orthographic, so screen height maps linearly to ground depth anyway.
// The GDScript side pushes exactly 12 floats = 48 bytes; the struct below
// must keep matching it exactly (9 params + 3 pads).
layout(push_constant, std430) uniform PushConstant {
    float band;               // sharp half-screen fraction: blur starts at |uv.y - 0.5| > band
    float ramp;               // gradient width from band edge to full blur, same units
    float blur_amount;        // max kernel radius contribution
    float strength;           // zoom fade multiplier (0..1)
    float saturation_boost;
    float highlight_boost;
    float highlight_threshold;
    float direction_x;
    float direction_y;
    float _pad0, _pad1, _pad2;
} pc;

float gaussian(float x, float s) {
    return exp(-(x * x) / (2.0 * s * s));
}

void main() {
    ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 img_size = imageSize(source_img);
    if (coord.x >= img_size.x || coord.y >= img_size.y) return;

    vec2 uv = (vec2(coord) + 0.5) / vec2(img_size);

    // t = position along the blur ramp: 0.0 (at the in-focus edge) .. 1.0
    // (fully blurred). Bands are screen-symmetric around the screen center.
    float d = abs(uv.y - 0.5);
    float t = clamp((d - pc.band) / max(pc.ramp, 0.001), 0.0, 1.0);

    vec4 original = imageLoad(source_img, coord);
    vec3 color = original.rgb;
    float alpha = original.a;

    if (t > 0.001) {
        // Kernel radius grows with ramp position: strongest blur far from
        // the focus band, fading smoothly toward it.
        int radius = 2 + clamp(int(round(t * pc.strength * pc.blur_amount)), 0, 16);
        float s = max(float(radius) / 3.0, 0.001);

        ivec2 dir = ivec2(int(pc.direction_x + 0.5), int(pc.direction_y + 0.5));

        vec4 accum = vec4(0.0);
        float weight_sum = 0.0;

        for (int i = -radius; i <= radius; i++) {
            ivec2 sp = clamp(coord + dir * i, ivec2(0), img_size - 1);
            vec4 sample_col = imageLoad(source_img, sp);

            if (pc.highlight_boost > 0.0) {
                float luma = dot(sample_col.rgb, vec3(0.2126, 0.7152, 0.0722));
                if (luma > pc.highlight_threshold) {
                    sample_col.rgb *= 1.0 + pc.highlight_boost * (luma - pc.highlight_threshold);
                }
            }

            float w = gaussian(float(i), s);
            accum.rgb += sample_col.rgb * w;
            accum.a += sample_col.a * w;
            weight_sum += w;
        }
        color = accum.rgb / max(weight_sum, 0.0001);
        alpha = accum.a / max(weight_sum, 0.0001);
    }

    // Quadratic onset: no perceptible step at the band edge (the kernel is
    // tiny there too), full blend exactly at the end of the ramp. Applied
    // in BOTH passes so horizontal and vertical blur fade in together.
    float mix_factor = t * t;
    // Narrow screen-edge fade (outer 4%): hides any 1-px kernel clamp seam
    // while keeping full blur visible right up to the edge. Clamped to 0
    // so it can never go negative at the outermost row.
    // float view_fade = clamp(1.0 - (abs(uv.y * 2.0 - 1.0) - 0.96) * 25.0, 0.0, 1.0);
    color = mix(original.rgb, color, mix_factor);

    if (pc.direction_y > 0.5 && pc.saturation_boost > 1.001)
    {
        float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
        color = mix(vec3(luma), color, pc.saturation_boost);
    }

    imageStore(dest_img, coord, vec4(color, alpha));
}
