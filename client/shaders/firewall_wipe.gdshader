shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D emission_texture : source_color, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;

uniform float wipe_progress : hint_range(0.0, 1.0) = 0.0;
uniform float min_height = -0.05;
uniform float max_height = 2.65;
uniform vec4 firewall_color : source_color = vec4(1.0, 0.28, 0.05, 1.0);
uniform float edge_thickness = 0.22;
uniform float edge_intensity = 4.5;
uniform float alpha_mult : hint_range(0.0, 1.0) = 1.0;

varying float v_local_y;

void vertex() {
	v_local_y = VERTEX.y;
}

void fragment() {
	float current_cutoff = mix(min_height, max_height, wipe_progress);

	// Se a altura do vértice estiver acima do limite do wipe, descarta o pixel
	if (v_local_y > current_cutoff) {
		discard;
	}

	vec4 alb = texture(albedo_texture, UV);
	vec4 emi = texture(emission_texture, UV);
	vec3 norm = texture(normal_texture, UV).rgb;

	NORMAL_MAP = norm;
	ALBEDO = alb.rgb * firewall_color.rgb;
	ROUGHNESS = 0.25;
	METALLIC = 0.1;

	// Brilho de emissão base
	EMISSION = (emi.rgb + firewall_color.rgb * 0.4) * 1.6;

	// Linha brilhante de energia na crista da materialização
	float edge_dist = current_cutoff - v_local_y;
	if (edge_dist < edge_thickness && wipe_progress < 0.999) {
		float edge_factor = 1.0 - (edge_dist / edge_thickness);
		EMISSION += vec3(1.0, 0.9, 0.3) * edge_intensity * edge_factor;
	}

	// Scanlines de pulso de energia
	float scanline = sin(v_local_y * 16.0 - TIME * 7.0) * 0.5 + 0.5;
	EMISSION += firewall_color.rgb * scanline * 0.75;
	ALPHA = alb.a * alpha_mult;
}
