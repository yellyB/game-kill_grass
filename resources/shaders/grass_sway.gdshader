shader_type canvas_item;

// Sway parameters
uniform float sway_speed : hint_range(0.5, 10.0) = 5.0;
uniform float sway_amount : hint_range(0.0, 0.3) = 0.12;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.7;

void vertex() {
	// Get world position for phase variation (so grass doesn't sway in sync)
	vec2 world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;

	// Phase based on world position - creates wave-like wind effect
	float phase = world_pos.x * 0.02 + world_pos.y * 0.01;

	// Sway amount increases toward the top of the grass (VERTEX.y is negative for top)
	float height_factor = clamp(-VERTEX.y / 50.0, 0.0, 1.0);

	// Multiple sine waves for more natural movement
	float sway = sin(TIME * sway_speed + phase) * sway_amount;
	sway += sin(TIME * sway_speed * 1.7 + phase * 1.3) * sway_amount * 0.5;
	sway *= wind_strength;

	// Apply sway only to upper parts of grass
	VERTEX.x += sway * height_factor * 50.0;
}

void fragment() {
	// COLOR already contains the instance color from MultiMesh
	// Just pass through with slight adjustment
	COLOR.a = 1.0;
}
