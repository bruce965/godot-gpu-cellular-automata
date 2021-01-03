shader_type canvas_item;
render_mode blend_disabled, unshaded;

const vec4 air   = vec4(  0,   0,   0,   0) / 255.;
const vec4 dirt  = vec4(156,  68,   0, 255) / 255.;
const vec4 stone = vec4(134, 134, 134, 255) / 255.;
const vec4 water = vec4( 32, 125, 253, 255) / 255.;
const vec4 sand  = vec4(207, 156, 110, 255) / 255.;
const vec4 wood  = vec4( 95,  20,   0, 255) / 255.;
const vec4 grass = vec4(  0,  95,   0, 255) / 255.;
const vec4 lava  = vec4(255,  78,   0, 255) / 255.;
const vec4 fire  = vec4(255,   0,   0, 255) / 255.;
const vec4 steam = vec4(136, 164, 201, 255) / 255.;

// Random number generator.
float rand(float time, vec2 coords) {
	return fract(sin(dot(coords - 0.1, vec2(12.9898,78.233)) + time) * 43758.5453);
}

// Compute the movement performed by the cell at the specified UV.
// Customize this function to alter material physics.
bool isMovingFrom(sampler2D tex, vec2 uv, vec2 pixelSize, float time, out vec2 uvNew) {
	// Calculate the UVs of the neigbours.
	vec2 uvUp        = uv + vec2( 0, -1) * pixelSize;
	vec2 uvDown      = uv + vec2( 0, +1) * pixelSize;
	vec2 uvLeft      = uv + vec2(-1,  0) * pixelSize;
	vec2 uvRight     = uv + vec2(+1,  0) * pixelSize;
	vec2 uvUpLeft    = uv + vec2(-1, -1) * pixelSize;
	vec2 uvUpRight   = uv + vec2(+1, -1) * pixelSize;
	vec2 uvDownLeft  = uv + vec2(-1, +1) * pixelSize;
	vec2 uvDownRight = uv + vec2(+1, +1) * pixelSize;
	
	// Get the color of this pixel and its neighbours.
	vec4 here      = texture(tex, uv         );
	vec4 up        = texture(tex, uvUp       );
	vec4 down      = texture(tex, uvDown     );
	vec4 left      = texture(tex, uvLeft     );
	vec4 right     = texture(tex, uvRight    );
	vec4 upLeft    = texture(tex, uvUpLeft   );
	vec4 upRight   = texture(tex, uvUpRight  );
	vec4 downLeft  = texture(tex, uvDownLeft );
	vec4 downRight = texture(tex, uvDownRight);
	
	// powders
	if (here == sand) {
		if (down == air) {
			uvNew = uvDown;
			return true;
		}

		// move randomly either left or right
		bool moveRight = rand(time, uv) > 0.5;

		if ((moveRight ? downRight : downLeft) == air) {
			uvNew = moveRight ? uvDownRight : uvDownLeft;
			return true;
		}
	}
	
	// liquids
	else if (here == water || here == lava) {
		if (down == air) {
			uvNew = uvDown;
			return true;
		}

		// move randomly either left or right
		bool moveRight = rand(time, uv) > 0.5;

		if ((moveRight ? downRight : downLeft) == air) {
			uvNew = moveRight ? uvDownRight : uvDownLeft;
			return true;
		}

		if ((moveRight ? right : left) == air) {
			uvNew = moveRight ? uvRight : uvLeft;
			return true;
		}
	}
	
	// gases
	if (here == fire || here == steam) {
		// move randomly
		ivec2 rand = ivec2(
			rand(time     , uv) > 0.5 ? +1 : -1,
			rand(time + 3., uv) > 0.5 ? +1 : -1
		);
		
		vec2 uvNeighbor = uv + vec2(rand) * pixelSize;
		
		if (texture(tex, uvNeighbor) == air) {
			uvNew = uvNeighbor;
			return true;
		}
	}

	return false;
}

// Check if any of the neighbors of the cell at the specified UV wants to occupy the cell.
// Modify this function to customize the radius of interaction between cells.
bool isMovingTo(sampler2D tex, vec2 uv, vec2 pixelSize, float time, out vec2 uvSource) {
	vec4 here = texture(tex, uv);
	
	if (here == air) {
		ivec2 rand = ivec2(
			rand(time + 1., uv) > 0.5 ? +1 : -1,
			rand(time + 2., uv) > 0.5 ? +1 : -1
		);

		// Check if any of the neighbors is moving to occupy this cell...
		for (int y = -1; y <= +1; y++) {
			for (int x = -1; x <= +1; x++) {
				if (ivec2(x, y) == ivec2(0, 0))
					continue;

				vec2 uvNeighbor = uv + vec2(ivec2(x, y) * rand) * pixelSize;

				vec2 uvNew;
				if (isMovingFrom(tex, uvNeighbor, pixelSize, time, uvNew) && uvNew == uv) {
					// Neighbor moved to this cell.
					uvSource = uvNeighbor;
					return true;
				}
			}
		}
	}

	// No particle is interested to move to this cell.
	return false;
}

// Check if the particle in a cell is morphing into a different material.
// Modify the function to alter interactions between different materials.
bool isMorphing(sampler2D tex, vec2 uv, vec2 pixelSize, float time, out vec4 material) {
	// Get the color of this pixel and its neighbours.
	vec4 here      = texture(tex, uv         );
	vec4 up        = texture(tex, uv + vec2( 0, -1) * pixelSize);
	vec4 down      = texture(tex, uv + vec2( 0, +1) * pixelSize);
	vec4 left      = texture(tex, uv + vec2(-1,  0) * pixelSize);
	vec4 right     = texture(tex, uv + vec2(+1,  0) * pixelSize);
	vec4 upLeft    = texture(tex, uv + vec2(-1, -1) * pixelSize);
	vec4 upRight   = texture(tex, uv + vec2(+1, -1) * pixelSize);
	vec4 downLeft  = texture(tex, uv + vec2(-1, +1) * pixelSize);
	vec4 downRight = texture(tex, uv + vec2(+1, +1) * pixelSize);
	
	if (here == water) {
		// Water in contact with lava turns into steam.
		if (up == lava || down == lava || left == lava || right == lava) {
			material = steam;
			return true;
		}
		
		// Water in continuous contact with hot steam slowly turns into steam.
		if (up == steam || down == steam || left == steam || right == steam) {
			if (rand(time, uv) < 0.01) {
				material = steam;
				return true;
			}
		}
		
		// Water may be absorbed from grass.
		if (up == grass || down == grass || left == grass || right == grass)
		{
			if (rand(time, uv) < 0.01) {
				material = grass;
				return true;
			}
		}
	}
	else if (here == steam) {
		// Steam in continuous contact with cold air slowly turns back into water.
		if (up == air && down == air && left == air && right == air) {
			if (rand(time, uv) < 0.005) {
				material = water;
				return true;
			}
		}
	}
	else if (here == lava) {
		// Lava solidifies in water.
		if (up == water || down == water || left == water || right == water) {
			material = stone;
			return true;
		}
		
		// Lava in contact with cold stone, slowly solidifies.
		if (up == stone || down == stone || left == stone || right == stone) {
			if (rand(time, uv) < 0.01) {
				material = stone;
				return true;
			}
		}
	}
	else if (here == wood || here == grass) {
		// Flammable materials in contact with fire or lava may catch fire.
		if (
			up == lava || down == lava || left == lava || right == lava ||
			up == fire || down == fire || left == fire || right == fire
		) {
			float flammability = here == grass ? 0.5 : 0.1;
			
			if (rand(time, uv) < flammability) {
				material = fire;
				return true;
			}
		}
	}
	else if (here == stone || here == dirt) {
		// Stone and dirt in contact with lava slowly melt.
		if (up == lava || down == lava || left == lava || right == lava) {
			if (rand(time, uv) < 0.001) {
				material = lava;
				return true;
			}
		}
	}
	else if (here == fire) {
		// Fire self-extinguishes after a while.
		if (rand(time, uv) < 0.01) {
			material = air;
			return true;
		}
	}
	
	return false;
}

void fragment() {
	vec4 newMaterial;
	if (isMorphing(TEXTURE, UV, TEXTURE_PIXEL_SIZE, TIME, newMaterial)) {
		// The particle in this cell morphed into a different material.
		COLOR = newMaterial;
	}
	else {
		vec2 uvNew;
		if (isMovingFrom(TEXTURE, UV, TEXTURE_PIXEL_SIZE, TIME, uvNew)) {
			// The occupant of this cell is trying to move to another cell...
			vec2 uvSource;
			if (isMorphing(TEXTURE, uvNew, TEXTURE_PIXEL_SIZE, TIME, newMaterial)) {
				// Failed to move because the destination morphed.
				COLOR = texture(TEXTURE, UV);
			}
			else if (isMovingTo(TEXTURE, uvNew, TEXTURE_PIXEL_SIZE, TIME, uvSource) && uvSource == UV) {
				// The occupant moved to another cell, clear this cell.
				COLOR = air;
			}
			else {
				// The occupant failed to move because another particle moved in first.
				COLOR = texture(TEXTURE, UV);
			}
		}
		else {
			vec2 uvSource;
			if (isMovingTo(TEXTURE, UV, TEXTURE_PIXEL_SIZE, TIME, uvSource)) {
				if (isMorphing(TEXTURE, uvSource, TEXTURE_PIXEL_SIZE, TIME, newMaterial)) {
					// A particle wanted to move into this cell, but couldn't do it because it morphed.
					COLOR = texture(TEXTURE, UV);
				}
				else {
					// A particle moved into this cell.
					COLOR = texture(TEXTURE, uvSource);
				}
			}
			else {
				// No change to the particle in this cell.
				COLOR = texture(TEXTURE, UV);
			}
		}
	}
	
	if ((UV / TEXTURE_PIXEL_SIZE).y == 1.)
		COLOR = dirt;
}