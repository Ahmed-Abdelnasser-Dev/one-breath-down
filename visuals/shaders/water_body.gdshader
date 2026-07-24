shader_type canvas_item;
// Procedural depth-tinted water color with animated water surface wave line,
// water-sky transparency separation, and sunlit zone caustics. Infinite in all directions.

uniform float camera_y = 0.0;
uniform float camera_x = 0.0;
uniform float rect_height : hint_range(64.0, 4000.0) = 1400.0;
uniform float rect_width : hint_range(64.0, 4000.0) = 2400.0;
uniform float posterize_steps : hint_range(4.0, 64.0) = 24.0;

// Stops match docs/visual-bible.md §2.3 — harmonized against the shipped reef/far-band art
uniform vec4 color_sunlit : source_color = vec4(0.161, 0.420, 0.780, 1.0);
uniform vec4 color_shallow : source_color = vec4(0.098, 0.278, 0.522, 1.0);
uniform vec4 color_twilight_in : source_color = vec4(0.071, 0.169, 0.388, 1.0);
uniform vec4 color_twilight_out : source_color = vec4(0.035, 0.090, 0.200, 1.0);
uniform vec4 color_midnight : source_color = vec4(0.012, 0.020, 0.051, 1.0);

// Surface wave and foam properties
uniform vec4 color_foam : source_color = vec4(0.85, 0.95, 1.0, 0.9);

// Absolute world-depth stops in px (PIXELS_PER_METRE=20, see run_manager.gd).
const float STOP0 = 0.0;
const float STOP1 = 1000.0;   // Sunlit -> Twilight (50m)
const float STOP2 = 2000.0;
const float STOP3 = 3000.0;   // Twilight -> Midnight (150m)
const float STOP4 = 4500.0;   // fully midnight from here on, forever

vec3 depth_color(float world_y) {
	float d = max(world_y, 0.0);
	if (d < STOP1) {
		return mix(color_sunlit, color_shallow, smoothstep(STOP0, STOP1, d)).rgb;
	} else if (d < STOP2) {
		return mix(color_shallow, color_twilight_in, smoothstep(STOP1, STOP2, d)).rgb;
	} else if (d < STOP3) {
		return mix(color_twilight_in, color_twilight_out, smoothstep(STOP2, STOP3, d)).rgb;
	}
	return mix(color_twilight_out, color_midnight, smoothstep(STOP3, STOP4, d)).rgb;
}

void fragment() {
	float world_y = camera_y + (UV.y - 0.5) * rect_height;
	float world_x = camera_x + (UV.x - 0.5) * rect_width;

	// Animated surface wave height calculation
	float wave = sin(world_x * 0.025 + TIME * 2.2) * 3.5 + cos(world_x * 0.05 - TIME * 1.5) * 2.0;
	float surface_dist = world_y - wave;

	if (surface_dist < -12.0) {
		COLOR = vec4(0.0);
	} else {
		vec3 col = depth_color(world_y);

		// Underwater caustics / sunbeams in Sunlit Zone
		if (world_y > 0.0 && world_y < 1200.0) {
			float sunlit_fade = clamp(1.0 - world_y / 1000.0, 0.0, 1.0);
			float ray1 = sin((world_x * 0.015 + world_y * 0.01) + TIME * 1.2);
			float ray2 = cos((world_x * 0.025 - world_y * 0.015) - TIME * 0.9);
			float rays = max(0.0, ray1 * ray2);
			rays = pow(rays, 3.0) * 0.22 * sunlit_fade;
			col += vec3(rays * 0.7, rays * 0.95, rays);
		}

		// Posterization into discrete steps for pixel-art consistency
		col = floor(col * posterize_steps + 0.5) / posterize_steps;

		// Water surface transition and foam crest
		float alpha = clamp(smoothstep(-12.0, 4.0, surface_dist), 0.0, 1.0);
		if (surface_dist >= -8.0 && surface_dist <= 5.0) {
			float foam_intensity = smoothstep(0.0, 1.0, 1.0 - abs(surface_dist - 0.0) / 5.0);
			col = mix(col, color_foam.rgb, foam_intensity * 0.75);
		}

		COLOR = vec4(col, alpha);
	}
}

