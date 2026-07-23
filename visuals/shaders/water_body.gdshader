shader_type canvas_item;
// Procedural depth-tinted water color. Infinite in all directions: color
// comes from a live `camera_y` uniform (background.gd re-centers and
// re-tints this rect on the camera every frame) rather than a gradient
// texture baked to a fixed world height, so it works at any depth. Beyond
// STOP4 the color simply holds at midnight forever instead of stopping.
// Posterized into discrete bands to read as chunky 16-bit pixel art instead
// of a smooth modern gradient.

uniform float camera_y = 0.0;
uniform float rect_height : hint_range(64.0, 4000.0) = 1400.0;
uniform float posterize_steps : hint_range(4.0, 64.0) = 24.0;

uniform vec4 color_sunlit : source_color = vec4(0.2, 0.6, 0.7, 1.0);
uniform vec4 color_shallow : source_color = vec4(0.1, 0.4, 0.55, 1.0);
uniform vec4 color_twilight_in : source_color = vec4(0.06, 0.22, 0.38, 1.0);
uniform vec4 color_twilight_out : source_color = vec4(0.03, 0.1, 0.2, 1.0);
uniform vec4 color_midnight : source_color = vec4(0.01, 0.02, 0.05, 1.0);

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
	vec3 col = depth_color(world_y);
	col = floor(col * posterize_steps + 0.5) / posterize_steps;
	COLOR = vec4(col, 1.0);
}
