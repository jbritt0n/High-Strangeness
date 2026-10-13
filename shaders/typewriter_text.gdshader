shader_type canvas_item;

// Worn typewriter ink for Label/Button text: ragged glyph edges, uneven ribbon
// density, ink dropouts, a slight red/cyan registration split and a projector
// flicker. A Label's built-in shadow is drawn with the same material; it is
// recognised by its alpha (keep font_shadow_color.a < 0.95) and drawn as a
// soft, smeared ink shadow instead.

uniform float seed = 0.0;
uniform float ink_wear : hint_range(0.0, 1.0) = 0.45;
uniform float aberration_px = 1.2;
uniform float flicker : hint_range(0.0, 1.0) = 0.35;
// 0..1, driven from script for the occasional "high strangeness" twitch.
uniform float glitch : hint_range(0.0, 1.0) = 0.0;

float hash(float n) { return fract(sin(n) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
			mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 sp = FRAGCOORD.xy;
	float n1 = vnoise(sp * 0.45 + seed * 31.0);   // fine grain: ragged edges
	float n2 = vnoise(sp * 0.06 + seed * 7.0);    // coarse: ribbon density
	float a = texture(TEXTURE, UV).a;

	if (COLOR.a < 0.95) {
		// Shadow pass: smeared, slightly blotchy ink offset behind the letter.
		float b = a * 0.36;
		b += texture(TEXTURE, UV + vec2(px.x * 2.0, 0.0)).a * 0.16;
		b += texture(TEXTURE, UV - vec2(px.x * 2.0, 0.0)).a * 0.16;
		b += texture(TEXTURE, UV + vec2(0.0, px.y * 2.0)).a * 0.16;
		b += texture(TEXTURE, UV - vec2(0.0, px.y * 2.0)).a * 0.16;
		COLOR = vec4(COLOR.rgb, COLOR.a * b * (0.8 + 0.2 * n2));
	} else {
		float off = aberration_px * (1.0 + glitch * 7.0);
		float ar = texture(TEXTURE, UV + vec2(px.x * off, 0.0)).a;
		float ab = texture(TEXTURE, UV - vec2(px.x * off, -px.y * off * 0.3)).a;

		float thr = 0.22 + 0.32 * n1;
		float body = smoothstep(thr - 0.1, thr + 0.1, a);
		float ink = mix(1.0, smoothstep(0.05, 0.85, n2 * 0.7 + n1 * 0.5), ink_wear);
		float speck = step(0.94, hash2(floor(sp * 0.6) + seed)) * ink_wear;
		float cov = body * ink * (1.0 - speck * 0.85);

		float fr = smoothstep(thr - 0.1, thr + 0.1, ar) * (1.0 - body);
		float fb = smoothstep(thr - 0.1, thr + 0.1, ab) * (1.0 - body);
		vec3 col = COLOR.rgb * (0.86 + 0.14 * n2);
		vec3 rgb = col * cov + vec3(1.0, 0.28, 0.14) * fr * 0.75 + vec3(0.25, 0.7, 1.0) * fb * 0.5;
		float alpha = clamp(cov + fr * 0.75 + fb * 0.5, 0.0, 1.0);

		float fl = 1.0 - flicker * 0.22 * hash(floor(TIME * 24.0) + seed * 3.0);
		COLOR = vec4(rgb / max(alpha, 0.001), alpha * COLOR.a * fl);
	}
}
