shader_type spatial;
render_mode unshaded, cull_disabled;

// Illustration-style soft studio light, stable as the arcade camera moves.
// Real geometry casts arena shadows; the atlas supplies soft self occlusion.
uniform sampler2D color_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float skin = 0.0;
uniform float shirt = 0.0;
uniform float shorts = 0.0;
uniform float socks = 0.0;
uniform float boots = 0.0;
uniform vec4 skin_color : source_color = vec4(1.0, 0.66, 0.57, 1.0);
uniform vec4 shirt_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 shorts_color : source_color = vec4(1.0);
uniform vec4 socks_color : source_color = vec4(1.0);
uniform vec4 boots_color : source_color = vec4(1.0);
uniform float hair = 0.0;
uniform float gloss = 0.015;
uniform int pattern_mode = 0;
uniform vec4 pattern_color : source_color = vec4(0.16,0.12,0.23,1.0);
uniform sampler2D shirt_print : source_color, filter_linear, repeat_disable;
uniform bool has_shirt_print = false;
uniform vec4 print_color : source_color = vec4(0.16,0.12,0.23,1.0);

void fragment() {
    vec3 color = texture(color_atlas,UV).rgb * base_color.rgb;
    color = mix(color,skin_color.rgb,skin);
    color = mix(color,shirt_color.rgb,shirt);
    color = mix(color,shorts_color.rgb,shorts);
    color = mix(color,socks_color.rgb,socks);
    color = mix(color,boots_color.rgb,boots);
    float pattern = 0.0;
    if (pattern_mode == 1) { pattern = step(0.5,fract(UV.x*6.0)); }
    else if (pattern_mode == 2) { pattern = step(0.65,fract(UV.y*4.0)); }
    else if (pattern_mode == 3) { pattern = step(0.5,UV.x); }
    else if (pattern_mode == 4) { pattern = step(0.5,fract((UV.x+UV.y)*3.0)); }
    color = mix(color,pattern_color.rgb,pattern*clamp(shirt+shorts+socks+boots,0.0,1.0));
    if (shirt > 0.5 && has_shirt_print && UV2.x >= 0.0 && UV2.x <= 1.0 && UV2.y >= 0.0 && UV2.y <= 1.0) {
        vec4 lettering = texture(shirt_print,UV2);
        color = mix(color,print_color.rgb,lettering.a);
    }
    vec3 n = normalize(NORMAL);
    vec3 key = normalize(vec3(-0.48,0.65,0.82));
    float wrapped = clamp((dot(n,key)+0.15)/1.15,0.0,1.0);
    float light = pow(wrapped,0.9);
    vec3 shadow_tint = mix(vec3(0.72,0.67,0.80),vec3(0.83,0.65,0.64),skin);
    shadow_tint = mix(shadow_tint,vec3(0.68,0.49,0.48),hair);
    vec3 diffuse = mix(shadow_tint,vec3(1.06,1.025,1.0),light);
    vec3 halfway = normalize(key+normalize(VIEW));
    float broad_highlight = pow(max(dot(n,halfway),0.0),12.0);
    float rim = pow(1.0-max(dot(n,normalize(VIEW)),0.0),3.0)*max(n.y,0.0);
    vec3 highlight_color = mix(vec3(1.0,0.78,0.65),color*vec3(1.15,0.80,0.72),hair);
    ALBEDO = color*diffuse + highlight_color*broad_highlight*gloss + vec3(0.08,0.03,0.04)*rim;
}
