shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount = 2.0;
uniform vec4 base_color : source_color = vec4(0.15, 0.18, 0.25, 0.8); 
uniform vec4 grid_color : source_color = vec4(0.4, 0.8, 0.9, 0.15); 
uniform float grid_spacing = 8.0; 
uniform float line_thickness = 1.0; 

void fragment() {
    vec4 bg = textureLod(screen_texture, SCREEN_UV, blur_amount);
    vec2 pos = FRAGCOORD.xy;
    float line_val = mod(pos.x + pos.y, grid_spacing);
    float grid = step(line_val, line_thickness);
    vec4 final_color = mix(bg, base_color, base_color.a);
    final_color.rgb = mix(final_color.rgb, grid_color.rgb, grid * grid_color.a);
    COLOR = vec4(final_color.rgb, 1.0);
}