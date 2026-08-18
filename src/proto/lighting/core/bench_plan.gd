class_name ProtoLightBenchPlan
extends RefCounted
## **무엇을 어떤 순서로 재는가.** 노드에 의존하지 않는 순수 정의다.
##
## 순서가 중요하다. 웹은 **데워진 정도가 배수를 만든다** (`unit_move/README.md` §22 —
## 계산 중앙값이 40 명에서 1.00 배, 100 명에서 1.38 배). 그래서 **싼 판부터 올린다.**
## 비싼 판을 먼저 돌리면 뒤의 싼 판이 데워진 상태에서 재어져 싸 보인다.
##
## 각 판은 **한 축만** 바꾼다. 조명을 켜는 것과 그림자를 켜는 것과 노멀을 켜는 것이
## 각각 얼마인지 갈라 보려면 그래야 한다.

## 그림자를 드리우는 물건의 최대 수. 판마다 이 중 몇 개만 켠다.
const OCCLUDER_POOL := 64
## 겹쳐 그리는 바탕 겹의 최대 수. 방 그림이 벽·바닥·소품으로 갈리면 겹이 늘고,
## **빛은 겹마다 다시 돈다.**
const LAYER_POOL := 6

## 한 판의 정의.
##
## | 열 | 뜻 |
## | --- | --- |
## | `lights` | 빛 개수 |
## | `radius` | 빛 반지름(px) |
## | `shadow` | `Light2D.ShadowFilter` 또는 -1(그림자 끔) |
## | `normal` | 노멀맵 사용 여부 |
## | `occluders` | 그림자를 드리우는 물건 수 |
## | `layers` | 빛을 받는 바탕 겹 수 |
const STAGES: Array[Dictionary] = [
	{
		"name": "0. 조명 없음 (바탕만)",
		"lights": 0,
		"radius": 0.0,
		"shadow": -1,
		"normal": false,
	},
	{
		"name": "1. 빛 1, 그림자 없음, 노멀 없음",
		"lights": 1,
		"radius": 320.0,
		"shadow": -1,
		"normal": false,
	},
	{
		"name": "2. 빛 1, 그림자 없음, **노멀**",
		"lights": 1,
		"radius": 320.0,
		"shadow": -1,
		"normal": true,
	},
	{
		"name": "3. 빛 1, **그림자 PCF5**, 노멀",
		"lights": 1,
		"radius": 320.0,
		"shadow": Light2D.SHADOW_FILTER_PCF5,
		"normal": true,
	},
	{
		"name": "4. 빛 4, 그림자 PCF5, 노멀",
		"lights": 4,
		"radius": 320.0,
		"shadow": Light2D.SHADOW_FILTER_PCF5,
		"normal": true,
	},
	{
		"name": "5. 빛 4, 그림자 PCF5, 노멀, **화면 전체 크기**",
		"lights": 4,
		"radius": 900.0,
		"shadow": Light2D.SHADOW_FILTER_PCF5,
		"normal": true,
	},
	{
		"name": "6. 빛 8, **PCF13**, 노멀, 화면 전체 크기",
		"lights": 8,
		"radius": 900.0,
		"shadow": Light2D.SHADOW_FILTER_PCF13,
		"normal": true,
	},
	{
		# 16 은 임의의 수가 아니다. `gl_compatibility` 캔버스 렌더러의
		# `MAX_LIGHTS_PER_ITEM = 16` 이다 (`drivers/gles3/rasterizer_canvas_gles3.h`).
		# 물건 하나(=바탕 스프라이트 한 장)에 닿을 수 있는 빛의 상한이므로 **여기가 천장**이다.
		"name": "7. 빛 16 (한 물건 상한), PCF13, 노멀, 화면 전체 크기",
		"lights": 16,
		"radius": 900.0,
		"shadow": Light2D.SHADOW_FILTER_PCF13,
		"normal": true,
	},
	# --- 여기부터는 **일부러 과하게** 건다. 게임에 쓸 값이 아니라 **천장을 찾는 값**이다.
	# 「예산 안이다」를 말하려면 어디서 깨지는지도 알아야 한다.
	{
		"name": "8. [과부하] 빛 16, PCF13, 가림물건 64",
		"lights": 16,
		"radius": 900.0,
		"shadow": Light2D.SHADOW_FILTER_PCF13,
		"normal": true,
		"occluders": 64,
	},
	{
		"name": "9. [과부하] 빛 16, PCF13, 가림물건 64, 바탕 6 겹",
		"lights": 16,
		"radius": 900.0,
		"shadow": Light2D.SHADOW_FILTER_PCF13,
		"normal": true,
		"occluders": 64,
		"layers": 6,
	},
]


## 판에서 값을 꺼낸다. 적지 않은 열은 기본값이 된다 —
## **같은 기본값을 판마다 되풀이해 적으면 언젠가 하나가 어긋난다**
## (방 시각화 레인의 교훈: "사람이 두 번 적을 수 있는 값은 어긋난다").
static func value(stage: Dictionary, key: String) -> Variant:
	if stage.has(key):
		return stage[key]
	match key:
		"occluders":
			return 8
		"layers":
			return 1
		_:
			return null
