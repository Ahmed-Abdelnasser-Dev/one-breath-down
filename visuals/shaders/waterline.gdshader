shader_type canvas_item;
// Animated wavy sea/sky divider, vertically centered on the real y=0 surface
// line. Horizontally infinite: this rect is re-centered on the camera's X
// every frame (background.gd), so `camera_x` recovers true world_x from UV —
// otherwise the wave pattern would slide with the screen instead of staying
// anchored in the water as the diver swims.

uniform float wave_speed : hint_range(0.0, 5.0) = 1.2;
uniform float wave_freq : hint_range(0.0, 0.05) = 0.012;
uniform float wave_amp : hint_range(0.0, 20.0) = 6.0;
uniform float rect_width : hint_range(8.0, 8000.0) = 2400.0;
uniform float rect_height : hint_range(8.0, 400.0) = 80.0;
uniform float camera_x = 0.0;
uniform float posterize_steps : hint_range(2.0, 16.0) = 5.0;
uniform vec4 foam_color : source_color = vec4(0.9, 0.98, 1.0, 0.9);

void fragment() {
	float world_x = camera_x + (UV.x - 0.5) * rect_width;
	// Two overlaid sine waves so the crest doesn't look perfectly periodic.
	float wave = sin(world_x * wave_freq + TIME * wave_speed) * wave_amp;
	wave += sin(world_x * wave_freq * 2.3 - TIME * wave_speed * 1.7) * wave_amp * 0.4;

	// UV.y = 0.5 is the true surface line (rect is vertically centered on y=0).
	float px_y = (UV.y - 0.5) * rect_height;
	float d = px_y - wave;

	float line_core = 1.0 - smoothstep(0.0, 3.0, abs(d));
	float foam_band = 1.0 - smoothstep(0.0, 11.0, abs(d));
	foam_band = floor(foam_band * posterize_steps) / posterize_steps;

	float alpha = max(line_core * foam_color.a, foam_band * foam_color.a * 0.6);
	COLOR = vec4(foam_color.rgb, alpha);
}
