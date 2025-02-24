shader_type canvas_item;
render_mode blend_mix;


// Wind settings.
uniform vec2 wind = vec2(0, 0);


uniform float heightOffset : hint_range(-0.5, 0.5) = 0.0;


void vertex() {
	vec4 pos = CANVAS_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	VERTEX.y += wind.y * max(0.0, (1.0-UV.y) - abs(heightOffset));
	VERTEX.x += wind.x * max(0.0, (1.0-UV.y) - abs(heightOffset)) * heightOffset;

}