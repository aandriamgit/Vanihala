#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D source_img;
layout(rgba16f, set = 1, binding = 0) uniform restrict writeonly image2D dest_img;

layout(push_constant, std430) uniform PushConstant {
    float focus_center;
    float focus_width;
    float blur_amount;
    float sigma;

    float saturation_boost;
    float angle;
    float shape;
    float highlight_boost;

    float highlight_threshold;
    float strength;
    float direction_x;
    float direction_y;

    float _p1; float _p2; float _p3; float _p4;
} pc;

float gaussian(float x, float s) {
    return exp(-(x * x) / (2.0 * s * s));
}
void main()
{
    ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 img_size = imageSize(source_img);
    if (coord.x >= img_size.x || coord.y >= img_size.y) return;

    vec4 original = imageLoad(source_img, coord);
    vec3 color = original.rgb;
    float alpha = original.a;

    vec2 uv = (vec2(coord) + 0.5) / vec2(img_size);
    vec2 aspect_uv = uv;
    aspect_uv.x = (aspect_uv.x - 0.5) * (float(img_size.x) / float(img_size.y)) + 0.5;

    float dist_from_focus;
    if (pc.shape > 0.5) {
        dist_from_focus = distance(aspect_uv, vec2(0.5, pc.focus_center));
    } else {
        float a = radians(pc.angle);
        vec2 dir = vec2(cos(a), sin(a));
        dist_from_focus = abs(dot(aspect_uv - vec2(0.5, pc.focus_center), dir));
    }

    float half_width = pc.focus_width * 0.5;
    float blur_factor = smoothstep(half_width, half_width + 0.15, dist_from_focus);
    int radius = clamp(int(blur_factor * pc.blur_amount), 0, 32);

    if (radius > 0) {
        float s = pc.sigma > 0.001 ? pc.sigma : float(radius) / 3.0;
        ivec2 d = ivec2(pc.direction_x > 0.5 ? 1 : 0, pc.direction_y > 0.5 ? 1 : 0);
        vec4 accum = vec4(0.0);
        float weight_sum = 0.0;

        for (int i = -radius; i <= radius; i++) {
            ivec2 sp = clamp(coord + d * i, ivec2(0), img_size - 1);
            vec4 sample_col = imageLoad(source_img, sp);

            if (pc.highlight_boost > 0.0 && pc.direction_y > 0.5) {
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

    if (pc.direction_y > 0.5) {
        if (pc.saturation_boost > 1.001) {
            float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
            color = mix(vec3(luma), color, pc.saturation_boost);
        }
        color = mix(original.rgb, color, pc.strength);
    }

    imageStore(dest_img, coord, vec4(color, alpha));
}
