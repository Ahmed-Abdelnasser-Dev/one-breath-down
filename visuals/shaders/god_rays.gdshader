shader_type canvas_item;
render_mode blend_add;
// Sunlit-zone light shafts. Additive so it only ever brightens the water
// beneath it, never darkens. `strength` is driven every frame from
// scripts/background/background.gd based on camera depth, fading the rays
// out once the diver leaves the sunlit zone.
//
// The world is infinite horizontally, so this rect is re-centered on the
// camera's X every frame rather than sized to cover a fixed play area. That
// means UV alone no longer identifies a stable point in the world — `camera_x`
// (set alongside the reposition) recovers true world_x so the ray pattern
// stays anchored in the water instead of sliding with the screen.

uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec4 ray_color : source_color = vec4(0.8, 0.95, 1.0, 1.0);
uniform float ray_freq : hint_range(0.001, 0.05) = 0.006;
uniform float ray_speed : hint_range(0.0, 2.0) = 0.15;
uniform float rect_width : hint_range(8.0, 8000.0) = 2400.0;
uniform float camera_x = 0.0;
uniform float posterize_steps : hint_range(2.0, 16.0) = 6.0;

void fragment() {
	float world_x = camera_x + (UV.x - 0.5) * rect_width;

	float depth_fade = 1.0 - UV.y; // brightest near the surface (UV.y = 0)
	float shear = UV.y * 90.0; // shafts rake sideways with depth
	float x = (world_x + shear) * ray_freq + TIME * ray_speed;
	float rays = pow(0.5 + 0.5 * sin(x * TAU), 6.0);
	rays = floor(rays * posterize_steps) / posterize_steps;
	float shimmer = 0.85 + 0.15 * sin(TIME * 1.3 + world_x * 0.02);
	float alpha = rays * depth_fade * shimmer * strength * 0.35;
	COLOR = vec4(ray_color.rgb, alpha);
}
