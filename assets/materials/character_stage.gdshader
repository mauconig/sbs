shader_type spatial;
render_mode unshaded;
uniform vec4 foreground : source_color = vec4(0.60,0.35,0.95,1.0);
uniform vec4 background : source_color = vec4(0.56,0.32,0.90,1.0);
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
    float distance_fade = smoothstep(0.5,13.0,world_position.z);
    vec3 base = mix(foreground.rgb,background.rgb,distance_fade);
    vec2 cell = world_position.xz / 0.55;
    vec2 line = abs(fract(cell-0.5)-0.5) / max(fwidth(cell),vec2(0.0001));
    float grid = 1.0-min(min(line.x,line.y),1.0);
    grid *= (1.0-smoothstep(2.0,6.0,world_position.z))*0.13;
    ALBEDO = mix(base,vec3(0.78,0.61,1.0),grid);
}
