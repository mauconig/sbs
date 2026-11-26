shader_type spatial;
render_mode cull_disabled;

// Soft toon response lit by the scene: the sun, its shadows and the sky ambient
// all reach the characters, so they sit in the same light as the stadium.
// The face (eyes, brows, mouth) is painted directly on the skin in head space.
uniform sampler2D color_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float skin = 0.0;
uniform float shirt = 0.0;
uniform float shorts = 0.0;
uniform float socks = 0.0;
uniform float boots = 0.0;
uniform float cleat = 0.0;
uniform vec4 skin_color : source_color = vec4(1.0, 0.66, 0.57, 1.0);
uniform vec4 shirt_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 shorts_color : source_color = vec4(1.0);
uniform vec4 socks_color : source_color = vec4(1.0);
uniform vec4 boots_color : source_color = vec4(1.0);
uniform float hair = 0.0;
uniform vec4 hair_color : source_color = vec4(0.25, 0.105, 0.105, 1.0);
uniform float gloss = 0.015;
uniform int pattern_mode = 0;
uniform vec4 pattern_color : source_color = vec4(0.16,0.12,0.23,1.0);
uniform sampler2D shirt_print : source_color, filter_linear, repeat_disable;
uniform bool has_shirt_print = false;
uniform vec4 print_color : source_color = vec4(0.16,0.12,0.23,1.0);

// Painted face. head_from_world maps world space into the head bone's space:
// +X across the face, +Y up, +Z out of the face (front surface near z = 0.36).
uniform bool face_enabled = false;
uniform mat4 head_from_world = mat4(1.0);
// 0 Neutral, 1 Happy, 2 Determined, 3 Surprised, 4 Celebrating
uniform int face_expression = 2;
uniform float face_blink = 1.0;
uniform vec4 eye_color : source_color = vec4(0.45, 0.24, 0.74, 1.0);

const vec3 INK = vec3(0.17, 0.10, 0.15);
const vec3 PAPER = vec3(1.0, 0.985, 0.96);
const vec3 MOUTH = vec3(0.45, 0.11, 0.17);
const vec3 TONGUE = vec3(0.97, 0.47, 0.52);

float sd_ellipse(vec2 p, vec2 r) {
    // Cheap, well-behaved ellipse distance for small painted shapes.
    float k0 = length(p / r);
    float k1 = length(p / (r * r));
    return k0 * (k0 - 1.0) / max(k1, 1e-5);
}

float sd_segment(vec2 p, vec2 a, vec2 b, float radius) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - radius;
}

float sd_round_box(vec2 p, vec2 half_size, float radius) {
    vec2 q = abs(p) - half_size + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

float fill(float d, float aa) {
    return 1.0 - smoothstep(-aa, aa, d);
}

// One eye in mirrored face space: x grows toward the outside of the face.
vec3 paint_eye(vec3 color, vec2 p, float aa) {
    vec2 c = vec2(0.150, 0.245);
    vec2 q = p - c;
    float open = clamp(face_blink, 0.0, 1.0);
    if (face_expression == 4 || open < 0.22) {
        // Closed or celebrating: a confident upward arc.
        float lift = face_expression == 4 ? 1.0 : -0.35;
        float arc = q.y - lift * (0.035 - 6.0 * q.x * q.x);
        float d = max(abs(arc) - 0.0135, abs(q.x) - 0.072);
        return mix(color, INK, fill(d, aa));
    }
    vec2 radius = vec2(0.074, 0.094);
    if (face_expression == 3) {
        radius *= 1.12;
    }
    radius.y *= open;
    float eye = sd_ellipse(q, radius);
    // Lids shape the expression: determined slants toward the nose.
    float lid = -1.0;
    if (face_expression == 2) {
        lid = q.y - (0.050 + 0.42 * q.x);
    } else if (face_expression == 1) {
        lid = -(q.y + 0.060 - 0.9 * q.x * q.x);
    }
    eye = max(eye, lid);
    float outline = fill(eye - 0.013, aa);
    color = mix(color, INK, outline);
    vec3 inner = PAPER;
    float iris_size = face_expression == 3 ? 0.044 : 0.056;
    vec2 iris_q = q - vec2(-0.010, -0.012 * open);
    float iris = fill(length(iris_q) - iris_size, aa);
    inner = mix(inner, eye_color.rgb * 0.92, iris);
    float pupil = fill(length(iris_q) - iris_size * 0.52, aa);
    inner = mix(inner, INK, pupil);
    float shine = fill(length(iris_q - vec2(0.020, 0.024)) - iris_size * 0.30, aa);
    inner = mix(inner, PAPER, shine);
    return mix(color, inner, fill(eye, aa));
}

vec3 paint_brow(vec3 color, vec2 p, float aa) {
    vec2 inner = vec2(0.062, 0.390);
    vec2 outer = vec2(0.238, 0.392);
    if (face_expression == 2) { inner.y = 0.338; outer.y = 0.398; }
    else if (face_expression == 1) { inner.y = 0.402; outer.y = 0.384; }
    else if (face_expression == 3) { inner.y = 0.430; outer.y = 0.420; }
    else if (face_expression == 4) { inner.y = 0.418; outer.y = 0.392; }
    float d = sd_segment(p, inner, outer, 0.0215);
    vec3 brow = mix(hair_color.rgb, INK, 0.35);
    return mix(color, brow, fill(d, aa));
}

vec3 paint_mouth(vec3 color, vec2 p, float aa) {
    vec2 c = vec2(0.0, 0.108);
    vec2 q = p - c;
    if (face_expression == 0) {
        float d = sd_segment(q, vec2(-0.048, 0.0), vec2(0.048, 0.0), 0.0125);
        return mix(color, INK, fill(d, aa));
    }
    if (face_expression == 3) {
        float d = sd_ellipse(q, vec2(0.036, 0.046));
        color = mix(color, INK, fill(d - 0.012, aa));
        return mix(color, MOUTH, fill(d, aa));
    }
    if (face_expression == 2) {
        // Gritted grin: white teeth inside a dark outline with one bite line.
        vec2 g = q - vec2(0.0, 0.004 + 1.4 * q.x * q.x);
        float d = sd_round_box(g, vec2(0.088, 0.030), 0.026);
        color = mix(color, INK, fill(d - 0.012, aa));
        vec3 teeth = mix(PAPER, INK, fill(abs(g.y) - 0.004, aa));
        return mix(color, teeth, fill(d, aa));
    }
    // Happy and celebrating: an open D-shaped smile with a tongue.
    vec2 size = face_expression == 4 ? vec2(0.094, 0.082) : vec2(0.078, 0.062);
    vec2 m = q - vec2(0.0, 0.026);
    float d = max(sd_ellipse(m, size), m.y);
    color = mix(color, INK, fill(d - 0.012, aa));
    vec3 inside = mix(MOUTH, TONGUE, fill(length(m - vec2(0.0, -size.y * 0.95)) - size.x * 0.55, aa));
    return mix(color, inside, fill(d, aa));
}

vec3 paint_face(vec3 color, vec3 view_vertex, vec3 view_normal, mat4 inv_view) {
    vec3 world = (inv_view * vec4(view_vertex, 1.0)).xyz;
    vec3 local = (head_from_world * vec4(world, 1.0)).xyz;
    vec3 world_normal = (inv_view * vec4(view_normal, 0.0)).xyz;
    vec3 local_normal = normalize(mat3(head_from_world) * world_normal);
    // Only the front of the head: excludes the back, hands and the neck.
    if (local.z < 0.10 || local.z > 0.47 || abs(local.x) > 0.40 || local.y < -0.02 || local.y > 0.52 || local_normal.z < 0.12) {
        return color;
    }
    vec2 p = vec2(abs(local.x), local.y);
    float aa = max(fwidth(local.x) + fwidth(local.y), 0.0015) * 0.75;
    color = paint_eye(color, p, aa);
    color = paint_brow(color, p, aa);
    color = paint_mouth(color, vec2(local.x, local.y), aa);
    return color;
}

void fragment() {
    vec3 color = texture(color_atlas,UV).rgb * base_color.rgb;
    color = mix(color,skin_color.rgb,skin);
    color = mix(color,shirt_color.rgb,shirt);
    color = mix(color,shorts_color.rgb,shorts);
    color = mix(color,socks_color.rgb,socks);
    color = mix(color,boots_color.rgb,boots);
    color = mix(color,hair_color.rgb,hair);
    float pattern = 0.0;
    if (pattern_mode == 1) { pattern = step(0.5,fract(UV.x*6.0)); }
    else if (pattern_mode == 2) { pattern = step(0.65,fract(UV.y*4.0)); }
    else if (pattern_mode == 3) { pattern = step(0.5,UV.x); }
    else if (pattern_mode == 4) { pattern = step(0.5,fract((UV.x+UV.y)*3.0)); }
    color = mix(color,pattern_color.rgb,pattern*clamp(shirt+shorts+socks+boots,0.0,1.0));
    if (cleat > 0.5) {
        // Vertex colors store the supplied shoe's normalized shape coordinates.
        // Continuous masks retain clean sole and lace edges on the actual mesh.
        vec3 shoe = COLOR.rgb;
        float side_panel = smoothstep(0.24,0.31,abs(shoe.x-0.5))
            * smoothstep(0.27,0.34,shoe.y) * (1.0-smoothstep(0.72,0.80,shoe.y))
            * (1.0-smoothstep(0.82,0.90,shoe.z));
        float collar = smoothstep(0.86,0.91,shoe.y) * (1.0-smoothstep(0.32,0.43,shoe.z));
        color = mix(color,pattern_color.rgb,max(side_panel,collar));
        float lace_band = min(abs(shoe.z-0.44),min(abs(shoe.z-0.57),abs(shoe.z-0.70)));
        float laces = (1.0-smoothstep(0.018,0.032,lace_band))
            * (1.0-smoothstep(0.18,0.22,abs(shoe.x-0.5))) * smoothstep(0.46,0.52,shoe.y);
        float sole = 1.0-smoothstep(0.25,0.28,shoe.y);
        color = mix(color,vec3(1.0,0.955,0.90),max(sole,laces));
    }
    if (shirt > 0.5 && has_shirt_print && UV2.x >= 0.0 && UV2.x <= 1.0 && UV2.y >= 0.0 && UV2.y <= 1.0) {
        vec4 lettering = texture(shirt_print,UV2);
        color = mix(color,print_color.rgb,lettering.a);
    }
    if (face_enabled && skin > 0.5) {
        color = paint_face(color, VERTEX, normalize(NORMAL), INV_VIEW_MATRIX);
    }
    ALBEDO = color;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
    // Soft warm rim keeps silhouettes readable against the turf.
    float rim = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 3.0);
    EMISSION = color * rim * 0.10;
}

void light() {
    float ndl = dot(NORMAL, LIGHT);
    // Wrapped, two-step-ish ramp: broad lit side, short soft terminator.
    float wrapped = clamp((ndl + 0.35) / 1.35, 0.0, 1.0);
    float band = smoothstep(0.30, 0.58, wrapped);
    float ramp = mix(wrapped, band, 0.6) * ATTENUATION;
    // LIGHT_COLOR carries energy * PI for physically based models; undo it here.
    vec3 light_color = LIGHT_COLOR / PI;
    vec3 lit = light_color * ramp;
    // Warm terminator on skin and hair, like light passing through.
    float terminator = (1.0 - abs(band * 2.0 - 1.0)) * ATTENUATION;
    lit += light_color * terminator * (skin * vec3(0.20, 0.06, 0.04) + hair * vec3(0.10, 0.03, 0.02));
    DIFFUSE_LIGHT += lit;
    vec3 halfway = normalize(LIGHT + VIEW);
    float highlight = pow(max(dot(NORMAL, halfway), 0.0), 18.0);
    SPECULAR_LIGHT += light_color * ATTENUATION * highlight * gloss * 0.6;
}
