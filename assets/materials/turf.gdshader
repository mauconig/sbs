shader_type spatial;
render_mode diffuse_burley;
uniform vec4 green : source_color = vec4(0.155,0.62,0.28,1.0);
uniform vec4 green_alt : source_color = vec4(0.115,0.575,0.23,1.0);
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    float band = step(0.5,fract((world_position.z+18.0)/7.6));
    vec3 grass = mix(green.rgb,green_alt.rgb,band*0.8);
    float fleck = hash(floor(world_position.xz*85.0));
    grass *= 0.987 + fleck*0.026;
    ALBEDO = grass;
    ROUGHNESS = 0.88;
    SPECULAR = 0.22;
}
