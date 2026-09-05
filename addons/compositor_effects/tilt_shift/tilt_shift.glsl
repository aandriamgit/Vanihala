#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D source_img;
layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2D dest_img;
layout(set = 2, binding = 0) uniform sampler2D depth_tex;

layout(push_constant, std430) uniform PushConstant {
    float focus_distance;
    float near_start;
    float near_end;
    float far_start;
    float far_end;
    float blur_amount;
    float sigma;
    float saturation_boost;
    float highlight_boost;
    float highlight_threshold;
    float strength;
    float direction_x;
    float direction_y;
    float near_plane;
    float far_plane;
    float is_orthographic;
    float _pad0, _pad1, _pad2;
} pc;

float linearize_depth(float raw_depth) {
    // Godot 4.3+ uses a REVERSED-Z depth buffer: raw depth is 1.0 at the near
    // plane and 0.0 at the far plane.
    if (pc.is_orthographic > 0.5) {
	return pc.near_plane + (1.0 - raw_depth) * (pc.far_plane - pc.near_plane);
    }
    float n = pc.near_plane;
    float f = pc.far_plane;
    return (n * f) / (n + raw_depth * (f - n));
}

float compute_coc(float depth) {
    // Signed blur amount in [-1, 1]: negative = near field, positive = far
    // field, 0 = in focus. `strength` is applied ONCE (here), never again in
    // the mix below — the old code multiplied it twice, halving the blur.
    float delta = depth - pc.focus_distance;
    if (delta < 0.0) {
        float range = max(pc.near_start - pc.near_end, 0.0001);
        float t = clamp((-delta - pc.near_end) / range, 0.0, 1.0);
        return -t;
    }
    float range = max(pc.far_end - pc.far_start, 0.0001);
    float t = clamp((delta - pc.far_start) / range, 0.0, 1.0);
    return t;
}

float gaussian(float x, float s) {
    return exp(-(x * x) / (2.0 * s * s));
}

void main() {
    ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 img_size = imageSize(source_img);
    if (coord.x >= img_size.x || coord.y >= img_size.y) return;

    vec2 uv = (vec2(coord) + 0.5) / vec2(img_size);

    float raw_depth = textureLod(depth_tex, uv, 0.0).r;
    float linear_depth = linearize_depth(raw_depth);

    float coc = compute_coc(linear_depth) * pc.blur_amount * pc.strength;
    int radius = clamp(int(round(abs(coc))), 0, 32);

    vec4 original = imageLoad(source_img, coord);
    vec3 color = original.rgb;
    float alpha = original.a;

    if (radius > 0) {
        float s = pc.sigma > 0.001 ? pc.sigma : float(radius) / 3.0;
        
        ivec2 d = ivec2(int(pc.direction_x + 0.5), int(pc.direction_y + 0.5));
        
        vec4 accum = vec4(0.0);
        float weight_sum = 0.0;

        for (int i = -radius; i <= radius; i++) {
            ivec2 sp = clamp(coord + d * i, ivec2(0), img_size - 1);
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

    if (pc.direction_y > 0.5)
    {
	    if (pc.saturation_boost > 1.001)
	    {
        	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
        	color = mix(vec3(luma), color, pc.saturation_boost);
	    }
	    // coc is already scaled by blur_amount * strength: the blurred result
	    // is used as-is when fully out of focus (mix_factor == 1 there).
	    float mix_factor = clamp(abs(coc), 0.0, 1.0);
	    color = mix(original.rgb, color, mix_factor);
    }

    imageStore(dest_img, coord, vec4(color, alpha));
}
