shader_type canvas_item;
render_mode unshaded;

// Clouds, cities and the chart are dedicated transparent full-canvas textures.
// The river instead reuses the original atlas painting, registered to a fitted
// centreline, so its stationary base and moving overlay remain visually exact.
// Only chart_layer ever passes through a rotation. The real progress Control is
// a sibling node and never enters this shader at all.
uniform sampler2D background_plate : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D city_layer : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D cloud_layer : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D chart_layer : source_color, filter_linear_mipmap, repeat_disable;

uniform float city_speed : hint_range(0.0, 0.5, 0.005) = 0.11;
uniform float city_drift : hint_range(0.0, 0.01, 0.0001) = 0.0025;
uniform float city_opacity : hint_range(0.0, 1.0, 0.01) = 0.88;
uniform float cloud_speed : hint_range(0.0, 1.0, 0.005) = 0.72;
uniform float cloud_drift : hint_range(0.0, 0.03, 0.0001) = 0.016;
uniform float cloud_opacity : hint_range(0.0, 1.0, 0.01) = 0.92;
uniform float water_speed : hint_range(0.0, 4.0, 0.05) = 2.4;
uniform float water_strength : hint_range(0.0, 0.5, 0.005) = 0.32;
uniform float river_opacity : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float river_overlay_opacity : hint_range(0.0, 1.0, 0.01) = 0.84;
uniform float chart_speed : hint_range(-0.08, 0.08, 0.001) = 0.018;
uniform float chart_opacity : hint_range(0.0, 1.0, 0.01) = 0.52;
uniform vec4 water_tint : source_color = vec4(0.47, 0.63, 0.68, 1.0);
uniform vec4 chart_tint : source_color = vec4(0.82, 0.70, 0.48, 1.0);

const float ATLAS_ASPECT = 1.777896;


float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}


float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
}


float fbm(vec2 point) {
	float result = 0.0;
	float weight = 0.5;
	for (int octave = 0; octave < 3; octave++) {
		result += value_noise(point) * weight;
		point = mat2(vec2(1.63, 1.17), vec2(-1.17, 1.63)) * point;
		weight *= 0.5;
	}
	return result;
}


mat2 rotation(float angle) {
	float cosine = cos(angle);
	float sine = sin(angle);
	return mat2(vec2(cosine, -sine), vec2(sine, cosine));
}


vec2 rotate_atlas_uv(vec2 uv, float angle) {
	vec2 point = uv - vec2(0.5);
	point.x *= ATLAS_ASPECT;
	point = rotation(angle) * point;
	point.x /= ATLAS_ASPECT;
	return point + vec2(0.5);
}


float inside_canvas(vec2 uv) {
	return step(0.0, uv.x) * step(uv.x, 1.0)
		* step(0.0, uv.y) * step(uv.y, 1.0);
}


float cloud_group(vec2 source_uv, float group) {
	float left = 1.0 - smoothstep(0.47, 0.53, source_uv.x);
	float top = 1.0 - smoothstep(0.44, 0.50, source_uv.y);
	if (group < 0.5) {
		return left * top;
	}
	if (group < 1.5) {
		return (1.0 - left) * top;
	}
	if (group < 2.5) {
		return left * (1.0 - top);
	}
	return (1.0 - left) * (1.0 - top);
}


float river_spine(vec2 uv, out vec2 tangent, out float along,
		out float half_width) {
	// Hand-fitted to the river in the original atlas. Calculations use
	// aspect-corrected coordinates, so width and closest-segment direction are
	// visually uniform rather than stretched by the 16:9 UV space.
	vec2 points[11] = {
		vec2(0.205, 0.365), vec2(0.176, 0.404), vec2(0.208, 0.443),
		vec2(0.178, 0.484), vec2(0.207, 0.524), vec2(0.151, 0.575),
		vec2(0.186, 0.635), vec2(0.238, 0.681), vec2(0.287, 0.716),
		vec2(0.344, 0.748), vec2(0.400, 0.775)
	};
	float widths[11] = {
		0.014, 0.018, 0.020, 0.026, 0.032, 0.042,
		0.045, 0.040, 0.035, 0.028, 0.020
	};
	vec2 point = vec2(uv.x * ATLAS_ASPECT, uv.y);
	float best_distance = 10.0;
	tangent = vec2(0.0, 1.0);
	along = 0.0;
	half_width = 0.01;
	for (int index = 0; index < 10; index++) {
		vec2 a = vec2(points[index].x * ATLAS_ASPECT, points[index].y);
		vec2 b = vec2(points[index + 1].x * ATLAS_ASPECT, points[index + 1].y);
		vec2 segment = b - a;
		float t = clamp(dot(point - a, segment) / dot(segment, segment), 0.0, 1.0);
		float distance_to_segment = length(point - (a + segment * t));
		if (distance_to_segment < best_distance) {
			best_distance = distance_to_segment;
			tangent = normalize(vec2(segment.x / ATLAS_ASPECT, segment.y));
			along = (float(index) + t) / 10.0;
			half_width = mix(widths[index], widths[index + 1], t);
		}
	}
	return best_distance;
}


float sd_round_box(vec2 point, vec2 half_size, float radius) {
	vec2 q = abs(point) - half_size + radius;
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - radius;
}


float title_protection(vec2 uv) {
	float distance_to_title = sd_round_box(
		uv - vec2(0.5, 0.49), vec2(0.275, 0.175), 0.055);
	return 1.0 - smoothstep(-0.008, 0.030, distance_to_title);
}


vec3 alpha_over(vec3 under, vec4 layer, float opacity) {
	return mix(under, layer.rgb, clamp(layer.a * opacity, 0.0, 1.0));
}


void fragment() {
	vec4 original = texture(TEXTURE, UV);
	// Recover CanvasItem modulation so the overlay can still fade as a whole.
	vec4 canvas_modulate = clamp(COLOR / max(original, vec4(0.001)),
		vec4(0.0), vec4(1.0));
	vec3 animated_color = texture(background_plate, UV).rgb;

	// The original constellations and chart circles are one transparent layer.
	// No clouds, cities, river, or decorative bottom line exist in this texture.
	vec2 chart_uv = rotate_atlas_uv(UV, -TIME * chart_speed);
	vec4 chart = texture(chart_layer, clamp(chart_uv, vec2(0.0), vec2(1.0)));
	chart.a *= inside_canvas(chart_uv) * chart_opacity
		* (1.0 - smoothstep(0.82, 0.88, UV.y));
	chart.rgb = mix(chart.rgb, chart_tint.rgb, 0.16);
	animated_color = alpha_over(animated_color, chart, 1.0);

	// Left and right landmarks drift independently without any rotation.
	float city_time = TIME * city_speed;
	vec2 left_city_uv = UV - vec2(sin(city_time * 0.73),
		sin(city_time * 0.51)) * city_drift;
	vec4 left_city = texture(city_layer,
		clamp(left_city_uv, vec2(0.0), vec2(1.0)));
	left_city.a *= (1.0 - smoothstep(0.49, 0.58, left_city_uv.x))
		* inside_canvas(left_city_uv);
	animated_color = alpha_over(animated_color, left_city, city_opacity);

	vec2 right_city_uv = UV - vec2(sin(city_time * 0.61 + 1.7),
		sin(city_time * 0.83 + 0.4)) * city_drift * vec2(0.86, 1.0);
	vec4 right_city = texture(city_layer,
		clamp(right_city_uv, vec2(0.0), vec2(1.0)));
	right_city.a *= smoothstep(0.49, 0.58, right_city_uv.x)
		* inside_canvas(right_city_uv);
	animated_color = alpha_over(animated_color, right_city, city_opacity);

	// Four independent cloud banks over a genuinely cloud-free plate. Each
	// transform is translation only, with a different slow period/phase—never
	// rotation. The larger amplitude is still only 1.6% of the canvas but makes
	// the drift readable during an ordinary loading interval.
	float cloud_time = TIME * cloud_speed;
	vec2 cloud_offsets[4] = {
		vec2(sin(cloud_time * 0.47), sin(cloud_time * 0.31 + 0.8))
			* cloud_drift,
		vec2(sin(cloud_time * 0.39 + 1.4), sin(cloud_time * 0.53 + 2.2))
			* cloud_drift * vec2(0.86, 0.72),
		vec2(sin(cloud_time * 0.57 + 2.7), sin(cloud_time * 0.43 + 1.1))
			* cloud_drift * vec2(0.78, 0.92),
		vec2(sin(cloud_time * 0.35 + 3.8), sin(cloud_time * 0.61 + 2.9))
			* cloud_drift * vec2(0.91, 0.79)
	};
	for (int group = 0; group < 4; group++) {
		vec2 cloud_uv = UV - cloud_offsets[group];
		vec4 cloud = texture(cloud_layer,
			clamp(cloud_uv, vec2(0.0), vec2(1.0)));
		cloud.a *= cloud_group(cloud_uv, float(group)) * inside_canvas(cloud_uv);
		animated_color = alpha_over(animated_color, cloud, cloud_opacity);
	}

	// Restore the atlas' ACTUAL river painting as the stationary base. A second
	// copy of that same texture scrolls downstream along the closest spine
	// tangent. Both are clipped by one fixed spine/colour mask, so no generated
	// river art or constant diagonal motion can leak onto its banks.
	vec2 river_tangent;
	float river_along;
	float river_half_width;
	float river_distance = river_spine(UV, river_tangent,
		river_along, river_half_width);
	float spine_alpha = 1.0 - smoothstep(river_half_width * 0.76,
		river_half_width, river_distance);
	float blue_signal = original.b - original.r * 0.88;
	float river_paint = smoothstep(-0.045, 0.105, blue_signal);
	float river_alpha = spine_alpha * mix(0.38, 1.0, river_paint);
	animated_color = alpha_over(animated_color,
		vec4(original.rgb, river_alpha), river_opacity);

	float scroll = fract(TIME * water_speed * 0.085);
	float scroll_span = 0.036;
	vec2 flow_uv_a = UV - river_tangent * (scroll * scroll_span);
	vec2 flow_uv_b = UV - river_tangent * ((scroll - 1.0) * scroll_span);
	vec3 flow_a = texture(TEXTURE, clamp(flow_uv_a, vec2(0.0), vec2(1.0))).rgb;
	vec3 flow_b = texture(TEXTURE, clamp(flow_uv_b, vec2(0.0), vec2(1.0))).rgb;
	// Keep one sample travelling downstream for most of its cycle. Cross-fade
	// only near the wrap; blending the two opposite offsets for the entire old
	// cycle visually cancelled the motion and made the river appear static.
	float reset_blend = smoothstep(0.72, 1.0, scroll);
	vec3 moving_river = mix(flow_a, flow_b, reset_blend);
	float flow_noise = fbm(vec2(river_along * 18.0,
		river_distance * 140.0) + vec2(-TIME * 0.14, TIME * 0.025));
	float flow_phase = river_along * 92.0 - TIME * water_speed * 3.6
		+ flow_noise * 2.4;
	float highlight = pow(0.5 + 0.5 * sin(flow_phase), 7.0);
	moving_river = mix(moving_river, water_tint.rgb,
		water_strength * (0.14 + highlight * 0.38));
	moving_river += vec3(0.95, 0.90, 0.76) * highlight * water_strength * 0.46;
	animated_color = alpha_over(animated_color,
		vec4(moving_river, river_alpha), river_overlay_opacity);

	// Preserve the exact baked wordmark and its immediate glow, motionless.
	animated_color = mix(animated_color, original.rgb, title_protection(UV));

	vec2 vignette_uv = UV * (vec2(1.0) - UV.yx);
	float vignette = pow(clamp(16.0 * vignette_uv.x * vignette_uv.y,
		0.0, 1.0), 0.16);
	animated_color *= mix(0.91, 1.0, vignette);
	COLOR = vec4(animated_color, original.a) * canvas_modulate;
}
