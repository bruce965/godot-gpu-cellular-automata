shader_type canvas_item;

const vec4 black = vec4(0, 0, 0, 1);
const vec4 white = vec4(1, 1, 1, 1);

// Random number generator.
float rand(vec2 coords) {
	return fract(sin(dot(coords, vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
	// Get the color of this pixel and its neighbours.
	vec4 here = texture(TEXTURE, UV);
	vec4 up = texture(TEXTURE, UV + vec2(0, -1) * TEXTURE_PIXEL_SIZE);
	vec4 down = texture(TEXTURE, UV + vec2(0, +1) * TEXTURE_PIXEL_SIZE);
	
	// Use the color of this pixel.
	COLOR = here;
	
	// Randomize the color a bit, to make it more interesting.
	vec2 coords = UV - mod(UV, TEXTURE_PIXEL_SIZE);
	COLOR = mix(COLOR, black, rand(coords) * 0.1);
	
	// If the materia below is different, make it a little darker.
	if (here != down)
		COLOR = mix(COLOR, black, 0.2);
	
	// Or else, if the material above is different, make it a litte lighter.
	else if (here != up)
		COLOR = mix(COLOR, white, 0.2);
}