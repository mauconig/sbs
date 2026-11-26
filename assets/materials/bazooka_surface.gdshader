shader_type spatial;
render_mode specular_schlick_ggx;

varying vec3 launcher_position;

void vertex() {
	launcher_position = VERTEX;
}

void fragment() {
	vec3 navy = vec3(0.022, 0.036, 0.076);
	vec3 cream = vec3(1.0, 0.896, 0.716);
	vec3 bore = vec3(0.005, 0.007, 0.016);
	float trim = 1.0 - smoothstep(-0.43, -0.42, launcher_position.z);
	float inner = (1.0 - smoothstep(0.09, 0.105, length(launcher_position.xy)))
		* (1.0 - smoothstep(-0.49, -0.48, launcher_position.z));
	ALBEDO = mix(mix(navy, cream, trim), bore, inner);
	ROUGHNESS = 0.58;
	SPECULAR = 0.12;
}
