shader_type canvas_item;

// 화면 전체를 한 장의 등고선 지도로 그린다.
//
// 이 셰이더 하나가 UI 전부를 그린다. 버튼도 팝업도 자기 몸을 그리지 않는다.
// 노드는 자기 사각형과 고도만 여기로 밀어 넣고, 그리는 것은 이 파일뿐이다.
// 그래서 요소끼리의 관계(붙었는가 떨어졌는가, 무엇이 무엇 위에 있는가)가
// 규칙이 아니라 **지형의 계산 결과**로 나온다.
//
// 지켜야 하는 불변식 하나: **고도장은 어디서도 끊기지 않는다.**
// 등고선은 서로 교차할 수 없고 허공에서 끝날 수 없다. 그 둘이 화면에 보이면
// 그것은 조형의 문제가 아니라 장에 불연속을 넣었다는 증거다. 한동안 요소 안쪽에서
// 바탕값을 다른 값으로 바꿔치기해 정상을 평평하게 만들었는데, 그 바꿔치기가
// 정확히 그 사고를 냈다. 지금은 장을 건드리지 않고 **잉크만 지운다**(clear).
//
// gl_compatibility(WebGL2) 제약: 컴퓨트 없음, 반복은 uniform 상한으로 묶는다.

const int MAX_ELEMENTS = 16;

uniform vec2 field_size = vec2(1280.0, 720.0);
uniform int element_count = 0;

// x, y, w, h — 장(場) 좌표계의 픽셀
uniform vec4 element_rect[MAX_ELEMENTS];
// x: 절대 고도(단), y: 모서리 반지름, z: 비탈 폭, w: 웅덩이 깊이
uniform vec4 element_form[MAX_ELEMENTS];
// x: 포커스(0~1), y: 눌림(0~1), z: 비활성(0~1), w: 얹힌 바닥의 고도(단)
uniform vec4 element_state[MAX_ELEMENTS];

uniform float contour_step = 0.5;
uniform float line_half_width = 0.62;

// 몇 번째마다 굵은 줄(계곡선)을 넣는가. 지형도의 index contour 와 같은 장치다.
uniform float index_every = 5.0;
uniform float index_weight = 2.1;

uniform vec4 ground_color : source_color = vec4(0.039, 0.043, 0.051, 1.0);
uniform vec4 line_low : source_color = vec4(0.239, 0.310, 0.384, 1.0);
uniform vec4 line_mid : source_color = vec4(0.400, 0.384, 0.345, 1.0);
uniform vec4 line_high : source_color = vec4(0.902, 0.871, 0.788, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.294, 0.149, 1.0);


float sd_round_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + vec2(radius);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - radius;
}


// 바탕의 결. 아무도 건드리지 않아도 화면이 살아 있게 하는 항이다.
//
// 첫 항은 화면 전체를 가로지르는 일정한 경사다. 경사가 있으면 등고선은 닫힌 고리가
// 아니라 화면을 가로지르는 줄이 되고, 바탕은 지도가 아니라 결(grain)로 읽힌다.
//
// 나머지 항의 진폭은 그 경사에 **거의 맞먹게** 잡았다. 작으면 줄 간격이 화면 어디서나
// 같아져서 — 등간격 평행선은 곧 평지이고 평지는 죽어 보인다 — 벽지가 된다.
// 지금은 간격이 자리마다 40px 에서 150px 까지 달라진다.
//
// **곱한 항**이 idle 의 핵심이다. 더한 항만 있으면 결은 모양을 유지한 채 통째로
// 미끄러진다(벽지 스크롤과 구별되지 않는다). 두 물결을 곱하면 마디마다 진폭이
// 달라지므로 줄이 밀리는 것이 아니라 **좁아졌다 넓어지고 갈라졌다 붙는다.**
float base_field(vec2 p, float t) {
	// 시간에 비례하는 항(t * k)은 **장 전체를 통째로 밀어 올린다.** 그것만으로도
	// 화면은 움직이지만, 보는 사람은 무늬가 흐르는 벽지로 읽는다. 그래서 이 항은
	// 거의 0 에 가깝게 두고, 대신 아래 물결들의 시간 속도를 올려 **자리마다 다른
	// 방향으로** 오르내리게 한다. 같은 20px/s 라도 인상이 다르다.
	float f = dot(p, vec2(0.16, 0.987)) * 0.0072 + t * 0.011;
	f += sin(p.x * 0.0061 - t * 0.205) * 0.26;
	f += sin((p.x * 0.5 + p.y * 0.86) * 0.0043 + t * 0.152) * 0.30;
	f += sin(p.x * 0.0075 + t * 0.34) * sin(p.y * 0.0053 - t * 0.27) * 0.40;
	f += sin(p.x * 0.0031 - t * 0.19) * cos(p.y * 0.0088 + t * 0.23) * 0.26;
	return f;
}


void fragment() {
	vec2 p = UV * field_size;
	float t = TIME;

	// 바탕과 요소를 따로 센다. 색은 절대 고도가 아니라 **요소가 만든 기복**의
	// 함수여야 한다. 바탕에는 전체 경사가 있어서 아래로 갈수록 고도가 커지는데,
	// 절대 고도로 색을 정하면 화면 아래쪽 바탕이 통째로 밝아진다.
	float ground = base_field(p, t);
	float relief = 0.0;
	float dig = 0.0;
	float swell = 0.0;
	float moat_total = 0.0;
	float ripple = 0.0;
	float focus_weight = 0.0;
	float hachure = 0.0;
	float clear_weight = 0.0;
	float stacked_inside = 0.0;
	float stacked_band = 0.0;

	for (int i = 0; i < element_count; i++) {
		vec4 rect = element_rect[i];
		vec4 form = element_form[i];
		vec4 state = element_state[i];

		vec2 center = rect.xy + rect.zw * 0.5;
		vec2 half_size = rect.zw * 0.5;
		float skirt = form.z;
		float stack = state.w;
		float lift = form.x - stack;

		// 영향권 밖은 건너뛴다. 아래의 어떤 항보다도 넓게 잡아야 한다 —
		// 여기서 값이 남은 채로 잘리면 그 사각형 경계에 **곧은 가짜 등고선**이 생긴다.
		vec2 reject = abs(p - center) - half_size - vec2(max(skirt * 3.6, 300.0));
		if (max(reject.x, reject.y) > 0.0) {
			continue;
		}

		vec2 rel = p - center;
		float d = sd_round_box(rel, half_size, form.y);

		// 바깥 고리일수록 네모를 잊는다.
		//
		// 거리장의 등위선은 원본 사각형을 그대로 오프셋한 것이라, 손대지 않으면
		// 맨 바깥 고리까지 같은 모서리 반지름을 유지한다. 지형에서 그런 일은
		// 일어나지 않는다. 거리 자체를 흔들어, 정상 윤곽은 또렷하고 **두 번째
		// 고리부터** 풀어지게 한다. 이 흔들림도 시간에 따라 돈다.
		float wander = sin(p.x * 0.0293 + p.y * 0.0171 + t * 0.53) * 3.6;
		wander += sin(p.x * 0.0121 - p.y * 0.0384 - t * 0.41) * 2.9;
		// 흔들림을 **고정된 14px** 안에서 켠다. 비탈 폭에 비례시키면 팝업처럼 비탈이
		// 넓은 요소에서는 안쪽 고리가 흔들리기 전에 이미 톤 띠로 뭉쳐, 균일한 굵기의
		// 획 하나 — 곧 카드 테두리 — 로 읽힌다.
		d += wander * smoothstep(0.0, 14.0, d);

		// 넓고 아주 낮은 부풀음. 요소에서 200px 넘게 떨어진 바탕 줄까지 휘게 한다.
		// 지수 감쇠가 아니라 **유한한 창**을 쓴다. 지수는 끝이 없어서 아래의 사각형
		// 조기 탈출 경계에서 값이 뚝 끊기고, 그 자리에 화면을 세로로 가로지르는
		// 곧은 가짜 등고선이 생긴다(실제로 생겼다).
		// 웅덩이를 가진 요소(팝업)는 부풀지 않는다. 넓은 부풀음과 웅덩이는 서로
		// 반대 방향이라 겹치면 상쇄되어, 뒤로 물러나야 할 지반이 도리어 밝아진다.
		swell += lift * 0.12 * smoothstep(255.0, 0.0, max(d, 0.0)) * step(form.w, 0.01);

		// 웅덩이. 비탈이 끝나는 곳부터 지반을 눌러 내린다.
		float outer = max(d - skirt, 0.0);
		// 지수 감쇠는 끝이 없어서 조기 탈출 경계에서 0.4단이 남은 채 잘렸고,
		// 화면을 세로로 가로지르는 곧은 줄이 실제로 생겼다. 유한한 창을 곱한다.
		moat_total += (
			form.w
			* exp(-outer / 110.0)
			* smoothstep(-2.0, 10.0, d - skirt)
			* (1.0 - smoothstep(0.0, 260.0, outer))
		);

		// 포커스. 봉우리에서 물결이 끊임없이 바깥으로 밀려 나간다.
		//
		// 물결에 **회전**을 함께 건다. 반지름만의 함수로 두면 마루가 요소를 두른
		// 닫힌 고리가 되고, 그건 어느 프레임에서 잘라도 포커스 링이다.
		// 세 갈래 마루가 돌면서 동시에 퍼지므로 고리가 닫히지 않는다.
		if (state.x > 0.001) {
			float ring = max(d, 0.0);
			// 감쇠에도 유한한 창을 씌운다. 지수는 끝이 없어서 조기 탈출 경계에서
			// 값이 남은 채 잘리고, 그 사각형 변을 따라 줄의 굵기 등급이 통째로
			// 바뀌는 곧은 이음매가 생긴다(실제로 세로 이음매 두 개가 생겼다).
			float reach = exp(-ring / 95.0) * (1.0 - smoothstep(120.0, 260.0, ring));
			float swirl = 0.62 + 0.38 * sin(atan(rel.y, rel.x) * 3.0 - t * 1.9);
			ripple += state.x * 0.62 * sin(ring * 0.075 - t * 3.0) * reach * swirl;
			// 강세색이 요소 바로 위에 얹히면 그것은 그냥 **포커스 링**이다.
			// 가까운 30px 을 비워, 색이 요소를 두르는 대신 **떠나가는 마루에만** 실리게 한다.
			focus_weight = max(focus_weight, state.x * reach * smoothstep(6.0, 30.0, ring));
		}

		if (lift >= 0.0) {
			// 비탈은 **가장자리에서 가장 가파르고** 밖으로 갈수록 완만해진다.
			//
			// 이 한 줄이 "테두리를 긋지 않았다"는 주장의 전부다. a/(a+d) 는 d=0 에서
			// 기울기가 최대라, 고리가 가장자리에 2~3px 간격으로 몰렸다가 바깥에서
			// 15px 이상으로 벌어진다. 앞서 쓴 지수·거듭제곱 곡선은 d=0 에서 기울기가
			// 0 이어서 맨 안쪽 고리가 일정 간격으로 떨어졌고, 그래서 획을 여러 겹
			// 두른 것처럼 보였다.
			// 비탈이 넓을수록 완만하게. 0.25 로 두었더니 팝업(6단)의 고리 넷이
			// 9px 안에 뭉쳐 균일한 굵은 획이 됐고, 심사에서 모달 카드로 읽혔다.
			float a = skirt * 0.45;
			float plateau = a / (a + max(d, 0.0));

			// 꼬리를 **유한하게** 끊는다. a/(a+d) 는 아무리 멀어도 0 이 되지 않아서,
			// 고원 위에 얹힌 버튼이 고원 전체에서 아주 근소하게 이기고 만다.
			// 그러면 아래의 "가장 높은 요소가 지우기를 정한다" 규칙이 무너져,
			// 팝업 안쪽이 통째로 지워지지 않고 바탕의 결이 제목 위를 지나간다.
			plateau *= smoothstep(skirt * 3.5, skirt * 1.5, max(d, 0.0));

			float top = stack + lift * plateau;
			relief = max(relief, top);

			// 정상 평면에는 잉크를 얹지 않는다. 장을 고치는 것이 아니라 그리지 않는 것이다.
			// 비활성은 이 손질을 받지 못해 바탕의 결이 글자 위를 그대로 지나간다.
			float inside = (1.0 - smoothstep(-5.0, 0.0, d)) * step(0.05, lift);
			clear_weight = max(clear_weight, inside * (1.0 - state.z));

			// **무언가 위에 얹힌** 요소는 따로 센다. 팝업 고원은 제 안쪽을 전부
			// 지우려 드는데 그 안에는 고원 위 버튼의 비탈도 들어 있어서, 지우기만
			// 두면 그 고리가 통째로 사라진다. 얹힌 요소의 비탈이 지나는 자리만
			// 지우기에서 빼 준다. 얹힌 것이 없는 화면(버튼만 있는 화면)에서는
			// 둘 다 0 이라 이 규칙은 아무 일도 하지 않는다.
			if (stack > 0.5) {
				stacked_inside = max(stacked_inside, inside);
				float band = smoothstep(-2.0, 2.0, d);
				band *= 1.0 - smoothstep(skirt * 2.0, skirt * 3.5, d);
				stacked_band = max(stacked_band, band);
			}
		} else {
			// 눌림은 봉우리를 낮추는 것이 아니라 **구덩이를 판다.**
			// 비탈이 바깥이 아니라 안쪽에 생겨 등고선이 사각형 안으로 말려 들어간다.
			//
			// 파는 깊이는 겹치기(min)가 아니라 따로 모았다가 마지막에 더한다.
			// min 으로 합치면 구덩이 밖(pit = 0)에서도 `min(relief, 0)` 이 걸려
			// 그 요소의 영향권 안에 있는 **다른 모든 봉우리가 지면까지 깎인다.**
			// 실제로 그렇게 되어 눌린 버튼 주변 다섯 개가 통째로 사라졌다.
			// 바닥이 넓어야 글자가 읽힌다. 반지름을 짧게 잡으면 그만큼 일찍 1 에
			// 도달해 **평평한 바닥**이 생기고, 등고선은 안쪽 테두리에만 남는다.
			// 넓게 잡았더니 고리가 글자 획을 잘라 라벨이 아예 판독 불가가 됐다.
			float radius = max(min(half_size.x, half_size.y) * 0.55, 1.0);
			float pit = smoothstep(0.0, 1.0, clamp(-d / radius, 0.0, 1.0));
			dig = min(dig, lift * pit);

			// 구덩이의 갈고리. 지도에서 우묵한 곳을 표시하는 기호 그대로다.
			// 등고선만으로는 솟은 것과 꺼진 것의 그림이 같아서, 안쪽을 향한 이
			// 짧은 빗금이 눌렸다는 사실을 색에 기대지 않고 말하는 유일한 수단이다.
			// 길이를 자리마다 달리해야 균일한 핀이 박힌 부품으로 보이지 않는다.
			bool near_side = abs(rel.x) * half_size.y > abs(rel.y) * half_size.x;
			float along = near_side ? rel.y : rel.x;
			float teeth = step(fract(along / 10.0), 0.16);
			float length_px = 2.6 + 2.0 * sin(along * 0.21 + t * 1.1);
			float band = step(0.0, -d) * step(-d, length_px);
			hachure = max(hachure, state.y * teeth * band);
		}
	}

	// 얹힌 요소의 비탈이 지나는 자리는 지우지 않는다.
	// 단 그 요소의 **정상 안에서는** 다시 지운다 — 옆에 붙은 형제의 비탈이
	// 내 글자 위를 침범하지 않도록. 세 항 모두 연속이라 어디에도 금이 가지 않는다.
	clear_weight *= 1.0 - stacked_band * (1.0 - stacked_inside);

	relief += dig + swell - moat_total + ripple;

	float height = ground + relief;
	float c = height / contour_step;
	float slope = fwidth(c);

	// 줄 굵기의 위계. 다섯 줄마다 하나를 굵게 긋는다.
	//
	// 굵기가 하나뿐이면 화면 전체가 같은 무게로 깔려 경사를 읽을 수 없고, 그때
	// 등고선은 지형이 아니라 무늬가 된다. 지형도가 계곡선을 두는 이유가 이것이다.
	float band_id = floor(c);
	float is_index = 1.0 - step(0.5, abs(mod(band_id, index_every)));
	float half_width = line_half_width * mix(1.0, index_weight, is_index);

	float pixels = abs(fract(c) - 0.5) / max(slope, 1e-5);
	float ink = 1.0 - smoothstep(half_width, half_width + 1.0, pixels);

	// 줄이 화면 해상도보다 촘촘해지는 구간(가파른 비탈)은 그냥 두면 흰 덩어리가 된다.
	// 그래서 해상 불가능한 만큼 농도를 깎아 **면이 아니라 톤**으로 내려앉게 한다.
	// 기준 굵기로 잰다. 계곡선의 굵기로 재면 굵은 줄이 더 많이 깎여
	// 애써 준 위계가 도로 평평해진다.
	float density = clamp(slope * 2.0 * (line_half_width + 0.5), 0.0, 1.0);
	ink *= 1.0 - density * 0.45;

	// 기울기가 0 에 가까운 곳의 줄은 계산이 갈피를 못 잡는다. 문턱을 아주 낮게 두어
	// 넓게 벌어진 줄은 살리고 수치적으로 무의미한 것만 자른다.
	ink *= smoothstep(0.0006, 0.0022, slope);

	ink = max(ink, hachure * 0.8);
	ink *= 1.0 - clear_weight;

	// 색은 기복의 함수다. 꺼진 곳은 차갑고 솟은 곳은 밝다. 바탕은 그 사이.
	vec3 line = mix(line_low.rgb, line_mid.rgb, smoothstep(-1.2, -0.02, relief));
	line = mix(line, line_high.rgb, smoothstep(0.15, 2.0, relief));
	line *= mix(0.52, 1.0, is_index);

	// 강세색은 **포커스 물결의 마루에만** 얹힌다. 요소를 붉게 두르는 것이 아니라
	// 색이 마루를 타고 돌면서 바깥으로 흘러 나간다. 화면에서 채도를 가진 것은 이것뿐이다.
	float crest = clamp(ripple / 0.26, 0.0, 1.0);
	line = mix(line, accent_color.rgb, crest * focus_weight);

	vec3 result = mix(ground_color.rgb, line, clamp(ink, 0.0, 1.0));

	// 넓은 저채도 면에서 나오는 띠(banding)를 흩는다.
	float grain = fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
	result += (grain - 0.5) * 0.008;

	COLOR = vec4(result, 1.0);
}
