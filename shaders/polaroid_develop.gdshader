shader_type canvas_item;

// Re-develops a Polaroid from one image into another. The old picture washes
// out to the milky grey-green of an undeveloped print, then the new one comes
// up through it unevenly (in blotches), low-contrast and cool at first, the
// way instant film actually develops.

uniform sampler2D next_image : source_color, filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec3 milk : source_color = vec3(0.47, 0.52, 0.48);

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
			mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec3 from = texture(TEXTURE, UV).rgb;
	vec3 to = texture(next_image, UV).rgb;
	float n = vnoise(UV * 5.0) * 0.65 + vnoise(UV * 17.0) * 0.35;

	// Phase 1: the old image fades into the undeveloped milk.
	float wash = smoothstep(0.0, 0.42, progress + (n - 0.5) * 0.15);
	vec3 old = mix(from, milk, wash);

	// Phase 2: the new image develops, blotchy and cool, then settles.
	float dev = clamp((progress - 0.38) / 0.62 * 1.35 - (1.0 - n) * 0.35, 0.0, 1.0);
	float lum = dot(to, vec3(0.299, 0.587, 0.114));
	vec3 early = mix(milk, vec3(lum) * vec3(0.85, 0.95, 1.0) * 0.7 + milk * 0.3, smoothstep(0.0, 0.5, dev));
	vec3 fresh = mix(early, to, smoothstep(0.35, 1.0, dev));

	vec3 col = mix(old, fresh, smoothstep(0.36, 0.44, progress));
	COLOR = vec4(col, 1.0);
}
