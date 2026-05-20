shader_type canvas_item;

uniform float blur_size : hint_range(0.0, 10.0) = 1.0;
uniform float darken_amount : hint_range(0.0, 1.0) = 0.8; // 0.8 = 80% darker

void fragment() {
    vec2 ps = TEXTURE_PIXEL_SIZE * blur_size;
    vec4 color = texture(TEXTURE, UV) * 4.0;
    
    // Orthogonal passes
    color += texture(TEXTURE, UV + vec2(1.0, 0.0) * ps) * 2.0;
    color += texture(TEXTURE, UV + vec2(-1.0, 0.0) * ps) * 2.0;
    color += texture(TEXTURE, UV + vec2(0.0, 1.0) * ps) * 2.0;
    color += texture(TEXTURE, UV + vec2(0.0, -1.0) * ps) * 2.0;
    
    // Diagonal passes
    color += texture(TEXTURE, UV + vec2(1.0, 1.0) * ps);
    color += texture(TEXTURE, UV + vec2(-1.0, -1.0) * ps);
    color += texture(TEXTURE, UV + vec2(1.0, -1.0) * ps);
    color += texture(TEXTURE, UV + vec2(-1.0, 1.0) * ps);
    
    // Average the blurred color
    vec4 final_color = color / 16.0;
    
    // Multiply RGB by the remaining brightness percentage (1.0 - 0.8 = 0.2)
    final_color.rgb *= (1.0 - darken_amount);
    
    COLOR = final_color;
}