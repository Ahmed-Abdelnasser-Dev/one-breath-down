shader_type canvas_item;
render_mode blend_add;
// Underwater light shimmer — present through the sunlit + twilight zones,
// unlike god_rays which is pinned to the fixed surface band. This rect
// follows the camera on both axes every frame (background.gd), so
// `camera_pos` recovers true world position from UV, keeping the shimmer
// anchored in the water instead of looking glued to the screen. Posterized
// for a chunky 16-bit look instead of smooth AAA caustics.

uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec4 caustic_color : source_color = vec4(0.6, 0.9, 1.0, 1.0);
uniform float pattern_scale : hint_range(0.001, 0.05) = 0.012;
uniform float speed : hint_range(0.0, 2.0) = 0.4;
uniform float posterize_steps : hint_range(2.0, 16.0) = 5.0;
uniform vec2 rect_size = vec2(2400.0, 1400.0);
uniform vec2 camera_pos = vec2(0.0, 0.0);

float caustic_pattern(vec2 p, float t) {
	float c = sin(p.x + t) * cos(p.y - t * 1.3);
	c += sin((p.x + p.y) * 0.7 - t * 0.8);
	c += sin((p.x - p.y) * 0.5 + t * 1.1);
	return c / 3.0;
}

void fragment() {
	vec2 world_pos = camera_pos + (UV - 0.5) * rect_size;
	float t = TIME * speed;
	float c = caustic_pattern(world_pos * pattern_scale, t) * 0.5 + 0.5;
	c = floor(c * posterize_steps) / posterize_steps;
	float alpha = c * strength * 0.22;
	COLOR = vec4(caustic_color.rgb, alpha);
}
