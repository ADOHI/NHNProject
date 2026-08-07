shader_type canvas_item;
render_mode blend_mix, unshaded;

// 스케치용 영상면. 카메라가 잡고 있는 **날 것의 그림**이다.
// 방향 A·C 가 공유한다. 채택되면 제대로 된 셰이더로 다시 쓴다.

uniform vec4 base_color : source_color = vec4(0.098, 0.094, 0.114, 1.0);
uniform vec4 tint_color : source_color = vec4(0.180, 0.161, 0.204, 1.0);
uniform float grain = 0.030;

float feed_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 p = FRAGCOORD.xy;
	float fall = smoothstep(0.0, 1.0, UV.y);
	float vignette = 1.0 - smoothstep(0.25, 1.05, length((UV - vec2(0.5)) * vec2(1.2, 1.0)));

	vec3 col = mix(base_color.rgb, tint_color.rgb, fall * 0.7);
	col *= mix(0.62, 1.06, vignette);
	col += vec3(feed_hash(floor(p) + floor(TIME * 24.0)) - 0.5) * grain;

	COLOR = vec4(col, 1.0);
}
