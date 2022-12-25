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
float rand(float time, ivec2 coords) {
	return fract(sin(dot(vec2(coords) - 0.1, vec2(12.9898,78.233)) + time) * 43758.5453);
}

// Compute the movement performed by the cell at the specified UV.
// Customize this function to alter material physics.
bool isMovingFrom(sampler2D tex, ivec2 uv, float time, out ivec2 uvNew) {
	// Calculate the UVs of the neigbours.
	ivec2 uvUp        = uv + ivec2( 0, -1);
	ivec2 uvDown      = uv + ivec2( 0, +1);
	ivec2 uvLeft      = uv + ivec2(-1,  0);
	ivec2 uvRight     = uv + ivec2(+1,  0);
	ivec2 uvUpLeft    = uv + ivec2(-1, -1);
	ivec2 uvUpRight   = uv + ivec2(+1, -1);
	ivec2 uvDownLeft  = uv + ivec2(-1, +1);
	ivec2 uvDownRight = uv + ivec2(+1, +1);
	
	// Get the color of this pixel and its neighbours.
	vec4 here      = texelFetch(tex, uv         , 0);
	vec4 up        = texelFetch(tex, uvUp       , 0);
	vec4 down      = texelFetch(tex, uvDown     , 0);
	vec4 left      = texelFetch(tex, uvLeft     , 0);
	vec4 right     = texelFetch(tex, uvRight    , 0);
	vec4 upLeft    = texelFetch(tex, uvUpLeft   , 0);
	vec4 upRight   = texelFetch(tex, uvUpRight  , 0);
	vec4 downLeft  = texelFetch(tex, uvDownLeft , 0);
	vec4 downRight = texelFetch(tex, uvDownRight, 0);
	
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
		
		ivec2 uvNeighbor = uv + rand;
		
		if (texelFetch(tex, uvNeighbor, 0) == air) {
			uvNew = uvNeighbor;
			return true;
		}
	}

	return false;
}

// Check if any of the neighbors of the cell at the specified UV wants to occupy the cell.
// Modify this function to customize the radius of interaction between cells.
bool isMovingTo(sampler2D tex, ivec2 uv, float time, out ivec2 uvSource) {
	vec4 here = texelFetch(tex, uv, 0);
	
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

				ivec2 uvNeighbor = uv + ivec2(x, y) * rand;

				ivec2 uvNew;
				if (isMovingFrom(tex, uvNeighbor, time, uvNew) && uvNew == uv) {
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
bool isMorphing(sampler2D tex, ivec2 uv, float time, out vec4 material) {
	// Get the color of this pixel and its neighbours.
	vec4 here      = texelFetch(tex, uv                , 0);
	vec4 up        = texelFetch(tex, uv + ivec2( 0, -1), 0);
	vec4 down      = texelFetch(tex, uv + ivec2( 0, +1), 0);
	vec4 left      = texelFetch(tex, uv + ivec2(-1,  0), 0);
	vec4 right     = texelFetch(tex, uv + ivec2(+1,  0), 0);
	vec4 upLeft    = texelFetch(tex, uv + ivec2(-1, -1), 0);
	vec4 upRight   = texelFetch(tex, uv + ivec2(+1, -1), 0);
	vec4 downLeft  = texelFetch(tex, uv + ivec2(-1, +1), 0);
	vec4 downRight = texelFetch(tex, uv + ivec2(+1, +1), 0);
	
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
	ivec2 uv = ivec2(UV / TEXTURE_PIXEL_SIZE);
	
	vec4 newMaterial;
	if (isMorphing(TEXTURE, uv, TIME, newMaterial)) {
		// The particle in this cell morphed into a different material.
		COLOR = newMaterial;
	}
	else {
		ivec2 uvNew;
		if (isMovingFrom(TEXTURE, uv, TIME, uvNew)) {
			// The occupant of this cell is trying to move to another cell...
			ivec2 uvSource;
			if (isMorphing(TEXTURE, uvNew, TIME, newMaterial)) {
				// Failed to move because the destination morphed.
				COLOR = textureLod(TEXTURE, UV, 0);
			}
			else if (isMovingTo(TEXTURE, uvNew, TIME, uvSource) && uvSource == uv) {
				// The occupant moved to another cell, clear this cell.
				COLOR = air;
			}
			else {
				// The occupant failed to move because another particle moved in first.
				COLOR = texelFetch(TEXTURE, uv, 0);
			}
		}
		else {
			ivec2 uvSource;
			if (isMovingTo(TEXTURE, uv, TIME, uvSource)) {
				if (isMorphing(TEXTURE, uvSource, TIME, newMaterial)) {
					// A particle wanted to move into this cell, but couldn't do it because it morphed.
					COLOR = texelFetch(TEXTURE, uv, 0);
				}
				else {
					// A particle moved into this cell.
					COLOR = texelFetch(TEXTURE, uvSource, 0);
				}
			}
			else {
				// No change to the particle in this cell.
				COLOR = texelFetch(TEXTURE, uv, 0);
			}
		}
	}
}
