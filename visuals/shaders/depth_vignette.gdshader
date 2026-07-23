shader_type canvas_item;
// Screen-space vignette that tightens the visible "light radius" in the
// Midnight zone (GDD: "near-black, small light radius"). `intensity` is
// driven every frame from scripts/background/background.gd based on depth;
// 0 = fully invisible, 1 = tight dark ring around the diver.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.02, 0.05, 1.0);

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 1.4;

	// Radius shrinks and edge sharpens as intensity rises.
	float radius = mix(1.1, 0.35, intensity);
	float softness = mix(0.6, 0.25, intensity);
	float lit = smoothstep(radius, radius - softness, dist);

	float darkness = (1.0 - lit) * intensity;
	COLOR = vec4(vignette_color.rgb, darkness);
}
