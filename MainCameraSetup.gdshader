shader_type canvas_item;

uniform vec2 sub_texel_offset = vec2(0.0, 0.0);

void fragment() {
    // Convert the sub-pixel offset into UV space
    // 320.0 and 180.0 MUST match your SubViewport's exact size
    vec2 uv_offset = sub_texel_offset / vec2(320.0, 180.0);
    
    // Shift the UVs in the opposite direction of the camera movement
    vec2 shifted_uv = UV + uv_offset;
    
    COLOR = texture(TEXTURE, shifted_uv);
}