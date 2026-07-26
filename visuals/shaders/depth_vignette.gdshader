shader_type canvas_item;
// Screen-space vignette with two jobs, driven every frame from
// scripts/background/background.gd:
//   `intensity` — overall strength (Midnight depth, or low breath)
//   `panic`     — how much of that is *suffocation* rather than depth, which
//                 swings the colour from deep-water navy to arterial red.
// The falloff is quantized to a coarse grid and posterized so it reads as
// pixel-art blocks rather than a smooth photographic gradient
// (visual-bible §5: "No smooth gradients, anywhere").

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float panic : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.012, 0.02, 0.051, 1.0);
uniform vec4 panic_color : source_color = vec4(0.44, 0.03, 0.05, 1.0);
// Horizontal cell count. 60 across a 480px-wide viewport = 8px blocks.
uniform float cells = 60.0;
uniform float posterize_steps = 5.0;

void fragment() {
	// Snap to a chunky grid before measuring distance, so the ring steps in
	// blocks. Cells are kept square by scaling for the 16:9 viewport.
	vec2 grid = vec2(cells, cells * 9.0 / 16.0);
	vec2 uv = (floor(UV * grid) + 0.5) / grid;

	vec2 centered = uv - vec2(0.5);
	float dist = length(centered) * 1.4;

	// Radius shrinks and the edge sharpens as intensity rises. Panic closes it
	// tighter still — the walls come in when you are out of air.
	float radius = mix(1.1, 0.35, intensity) - panic * 0.16;
	float softness = mix(0.6, 0.25, intensity);
	float lit = smoothstep(radius, radius - softness, dist);

	float darkness = (1.0 - lit) * intensity;
	darkness = floor(darkness * posterize_steps + 0.5) / posterize_steps;

	vec3 col = mix(vignette_color.rgb, panic_color.rgb, panic);
	COLOR = vec4(col, darkness);
}
