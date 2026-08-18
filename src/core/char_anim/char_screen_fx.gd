class_name CharScreenFx
extends RefCounted
## **화면에 거는 연출** — 속도선 · 임팩트 프레임 · 카메라.
##
## `docs/design/25-character-animation.md` §25.28.
##
## §25.23 의 잔상·호가 **캐릭터에** 걸리는 것이라면, 이것들은 **화면 전체에** 걸린다.
## 그래서 파츠도 무기도 안 건드리고, **캐릭터가 무엇을 하든 상관없이** 얹힌다.
##
## §25.26 에서 「도형이라 싸고 효과가 가장 크다」고 적은 것이 이 셋이다.
##
## ## 축마다 넷
##
## §25.23 의 규칙 그대로 — **없음 · 약 · 세 · 과.**
## **과한 것이 반드시 있어야 한다.** 경계를 알려면 넘어가 본 것이 있어야 한다.
##
## ## 왜 순수 함수인가
##
## 여기도 **시각을 넣으면 그림이 나온다.** 누적 상태가 없어서 캡처와 실시간이 같고,
## 되감아도 같은 그림이 나온다 — §25.3 의 「기록하지 않는다」가 여기서도 값을 한다.

enum Level { NONE, WEAK, STRONG, OVER }

## 눈금 이름. 캡처와 벤치가 같은 말을 쓰게 하려는 것이다.
const LEVEL_NAMES: Array[String] = ["none", "weak", "strong", "over"]

## 속도선이 몇 줄인가.
const LINE_COUNT: Array[int] = [0, 14, 30, 64]

## 배경을 얼마나 덮는가. **`1` 이면 배경이 사라지고 선만 남는다** — 일본 격투 애니메이션.
const LINE_WIPE: Array[float] = [0.0, 0.25, 0.62, 1.0]

## 선의 짙기.
const LINE_INK: Array[float] = [0.0, 0.30, 0.55, 0.85]

## 캐릭터 주위로 비워 두는 반지름(px). **여기를 안 비우면 얼굴 앞이 지저분하다.**
##
## 선은 캐릭터 **뒤에** 깔리므로 이 원은 넓지 않아도 된다 (§25.28.2).
const LINE_CLEAR: Array[float] = [0.0, 120.0, 96.0, 72.0]

## 임팩트 프레임이 몇 초 가는가. **1~2 프레임이다** — 길면 정지로 읽힌다.
##
## **가장 낮은 눈금도 한 프레임보다는 길다.** 처음에 `0.033` 을 넣었는데 25 fps 는
## 한 프레임이 `0.040` 초라 **표본 사이로 빠져나갔다** — 「약」이 눈금에 있는데
## 화면에서 아무 일도 안 일어났다. §25.19.2 에서 히트스톱이 반 프레임도 안 되어
## 아무 일도 안 했던 것과 **같은 실패**다.
const FLASH_HOLD: Array[float] = [0.0, 0.048, 0.088, 0.18]

## 임팩트 프레임의 짙기. `1` 이면 **화면이 완전히 하얗다.**
##
## **켜져 있는 동안 일정하다.** 처음에 시간에 따라 줄게 했더니, 하나뿐인 표본이 꺼지기
## 직전에 걸려 짙기가 `0.03` 으로 잡혔다 — **번쩍임은 「몇 프레임 켜져 있는 것」이지
## 「밝기가 줄어드는 것」이 아니다.** 격투게임의 임팩트 프레임도 꽉 찬 한두 장이다.
const FLASH_INK: Array[float] = [0.0, 0.55, 0.9, 1.0]

## 흑백 반전이 몇 초 가는가. 백색 다음에 온다. **여기도 한 프레임보다 길어야 한다.**
const INVERT_HOLD: Array[float] = [0.0, 0.0, 0.045, 0.085]

## 닿을 때 얼마나 밀고 들어가는가.
const ZOOM_IN: Array[float] = [0.0, 0.06, 0.16, 0.34]

## 줌이 풀리는 데 걸리는 시간(초).
const ZOOM_EASE: Array[float] = [0.0, 0.18, 0.26, 0.42]

## 화면이 얼마나 흔들리는가(px).
const SHAKE: Array[float] = [0.0, 4.0, 11.0, 26.0]

## 흔들림이 잦아드는 빠르기.
const SHAKE_DECAY := 9.0

## 흔들림 한 번의 주기(초).
const SHAKE_PERIOD := 0.055

var speed_lines := Level.NONE
var impact := Level.NONE
var camera := Level.NONE


static func level_from(name: String) -> Level:
	var at := LEVEL_NAMES.find(name)
	return Level.NONE if at < 0 else at as Level


## 셋을 한꺼번에 같은 눈금으로. 나란히 놓고 볼 때 쓴다.
static func all_at(level: Level) -> CharScreenFx:
	var fx := CharScreenFx.new()
	fx.speed_lines = level
	fx.impact = level
	fx.camera = level
	return fx


func is_idle() -> bool:
	return speed_lines == Level.NONE and impact == Level.NONE and camera == Level.NONE


## **속도선이 얼마나 나와 있나.** `0` … `1`.
##
## 닿기 **전부터** 오른다 — 휘두르는 동안 이미 빨라야 하기 때문이다. 닿고는 빨리 준다.
func line_strength(at: float, impact_at: float) -> float:
	if speed_lines == Level.NONE or impact_at < 0.0:
		return 0.0
	var lead := impact_at - at
	if lead > 0.0:
		return clampf(1.0 - lead / 0.20, 0.0, 1.0)
	return clampf(1.0 + lead / 0.12, 0.0, 1.0)


## **선이 그어질 자리.** `(시작, 끝)` 쌍이 줄줄이 들어온다.
##
## 방향은 **검이 지나가는 쪽**에서 온다 — 검이 왼쪽으로 지나가면 선도 왼쪽으로 흐른다.
## 그래서 이 장치는 자세를 **읽고** 나온다. 박아 둔 값이 아니다.
func line_field(size: Vector2, focus: Vector2, heading: Vector2, strength: float) -> Array:
	var lines := []
	if strength <= 0.001 or speed_lines == Level.NONE:
		return lines
	var dir := heading.normalized() if heading.length() > 0.01 else Vector2.LEFT
	var side := Vector2(-dir.y, dir.x)
	var count := int(round(float(LINE_COUNT[speed_lines]) * strength))
	var reach := size.length()
	var clear := LINE_CLEAR[speed_lines]
	for i in count:
		# 한 줄이 늘 같은 자리에 오게 한다. **무작위면 프레임마다 튄다.**
		var spread := (fmod(float(i) * 0.6180339887, 1.0) - 0.5) * reach * 1.25
		var along := (fmod(float(i) * 0.3819660113, 1.0) - 0.5) * reach * 0.8
		var mid := focus + side * spread + dir * along
		var length := reach * (0.18 + 0.40 * fmod(float(i) * 0.7548776662, 1.0)) * strength
		var head := mid + dir * length * 0.5
		var tail := mid - dir * length * 0.5
		# **캐릭터 바로 앞만 비운다.** 띠 전체를 버리면 가운데가 텅 비어 흩어져 보인다 —
		# 처음에 그렇게 했다가 선이 **가장자리로 몰렸다.**
		if mid.distance_to(focus) < clear:
			continue
		lines.append([tail, head])
	return lines


## 배경을 덮는 정도. `1` 이면 배경이 통째로 사라진다.
func wipe_amount(strength: float) -> float:
	return LINE_WIPE[speed_lines] * strength


func line_alpha(strength: float) -> float:
	return LINE_INK[speed_lines] * strength


## **임팩트 프레임의 하얀 정도.** 닿는 순간 1~2 프레임만.
func flash_alpha(at: float, impact_at: float) -> float:
	if impact == Level.NONE or impact_at < 0.0 or at < impact_at:
		return 0.0
	var age := at - impact_at
	var hold := FLASH_HOLD[impact]
	if age >= hold or hold <= 0.0:
		return 0.0
	return FLASH_INK[impact]


## **흑백 반전이 걸렸나.** 백색이 끝난 바로 다음 한두 프레임이다.
func is_inverted(at: float, impact_at: float) -> bool:
	if impact == Level.NONE or impact_at < 0.0:
		return false
	var age := at - impact_at - FLASH_HOLD[impact]
	return age >= 0.0 and age < INVERT_HOLD[impact]


## **카메라.** 닿을 때 밀고 들어갔다 흔들리며 풀린다.
##
## `focus` 를 붙잡고 확대하므로 **캐릭터가 화면 밖으로 안 밀린다.**
func camera_transform(at: float, impact_at: float, focus: Vector2) -> Transform2D:
	if camera == Level.NONE or impact_at < 0.0 or at < impact_at:
		return Transform2D.IDENTITY
	var age := at - impact_at
	var ease_time := ZOOM_EASE[camera]
	var left := 0.0 if ease_time <= 0.0 else clampf(1.0 - age / ease_time, 0.0, 1.0)
	var zoom := 1.0 + ZOOM_IN[camera] * left * left
	var shake := SHAKE[camera] * exp(-SHAKE_DECAY * age)
	var jolt := Vector2(
		sin(TAU * age / SHAKE_PERIOD) * shake, cos(TAU * age / (SHAKE_PERIOD * 0.77)) * shake * 0.6
	)
	# 초점을 붙잡고 확대한다.
	var t := Transform2D.IDENTITY.translated(focus + jolt)
	t = t.scaled(Vector2(zoom, zoom))
	return t.translated(-focus)
