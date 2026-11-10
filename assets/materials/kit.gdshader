shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 team_color : source_color = vec4(0.95,0.12,0.52,1.0);
uniform vec4 stripe_color : source_color = vec4(1.0,0.94,0.83,1.0);
void fragment() {
    float stripe = smoothstep(0.3,0.32,fract(UV.x * 10.0)) * (1.0-smoothstep(0.6,0.62,fract(UV.x*10.0)));
    ALBEDO = mix(team_color.rgb,stripe_color.rgb,stripe);
    ROUGHNESS = 0.76;
    SPECULAR = 0.26;
}
