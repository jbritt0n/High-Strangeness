shader_type canvas_item;

// Full-screen analog film look. Driven by conviction (see film_post.gd):
// low conviction = noisy, flickery, desaturated; high conviction = clean.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float grain : hint_range(0.0, 1.0) = 0.1;
uniform float color_noise : hint_range(0.0, 1.0) = 0.0;
uniform float aberration : hint_range(0.0, 0.02) = 0.0015;
uniform float flicker : hint_range(0.0, 0.3) = 0.0;
uniform float saturation : hint_range(0.0, 1.5) = 0.9;
uniform float vignette : hint_range(0.0, 1.0) = 0.45;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - 0.5;
	float ab = aberration * length(centered);
	vec3 c;
	c.r = texture(screen_tex, uv + vec2(ab, 0.0)).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - vec2(ab, 0.0)).b;

	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(lum), c, saturation);

	// Luminance-weighted grain, re-rolled ~24 times a second like film.
	vec2 px = floor(uv * vec2(1280.0, 720.0));
	float t = floor(TIME * 24.0);
	float n = hash(px + t * 17.0) - 0.5;
	c += n * grain * (0.5 + (1.0 - lum));

	vec3 cn = vec3(hash(px + t * 3.1), hash(px + t * 5.7 + 11.0), hash(px + t * 7.3 + 23.0)) - 0.5;
	c += cn * color_noise;

	c *= 1.0 + flicker * (hash(vec2(floor(TIME * 12.0), 0.5)) - 0.5);

	float v = smoothstep(0.3, 0.95, length(centered * vec2(1.15, 1.0)));
	c *= 1.0 - vignette * v;

	COLOR = vec4(c, 1.0);
}
