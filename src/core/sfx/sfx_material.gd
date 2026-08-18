class_name SfxMaterial
extends RefCounted
## 재질 = 무엇으로 만들어졌나. 무게(크기)와 **직교하는 축**이다
## (docs/design/29-sound.md §29.4).
##
## 무게가 정하는 것은 셋뿐이다 — 기본 주파수 · 감쇠 길이 · 저역 차단.
## 재질은 그 셋을 배수로 밀고, 대신 **배음 구조와 잡음 비율**을 정한다.
## 둘이 곱해져서 재질 6 × 무게 4 = 24 가지가 손으로 맞춘 값 없이 나온다.
##
## 여기 있는 것은 "무기 13종" 이 아니다. 무기가 늘어도 이 표는 안 늘어난다.

enum Kind {
	METAL,  ## 검 · 갑옷 · 금속 문
	WOOD,  ## 몽둥이 · 방패 · 나무 상자
	FLESH,  ## 살에 꽂히는 타격 · 피격
	STONE,  ## 돌바닥 · 벽 · 게이트
	CLOTH,  ## 천 · 가죽 · 백팩
	DIRT,  ## 흙 · 자갈 발소리
}

## 자유-자유 막대의 실제 횡진동 모드비다. 검처럼 가늘고 긴 금속이 이렇게 운다.
##
## 정수배(1, 2, 3...)가 아니라 **비조화**라서 음정이 아니라 "쇳소리" 로 들린다.
## 이 숫자를 지어내지 않았다 — 막대 진동의 해석해다.
const _BAR_MODES: Array[float] = [1.0, 2.756, 5.404, 8.933]

static var _cache: Dictionary = {}

## 음 대 잡음 비율. 1 이면 순수한 울림, 0 이면 순수한 잡음.
var tone_ratio: float

## 기본음에 얹히는 배음의 비율. 첫 항은 항상 1.0 이다.
var partials: Array[float]

## 감쇠 배수. 재질의 감쇠비이지 크기가 아니다 — 그래서 무게와 곱해진다.
var damping: float

## 저역 차단 배수. 클수록 밝다.
var brightness: float

## 무게 1 에서의 기준 기본 주파수 (Hz). 무게가 이 값을 나눈다.
var base_hz: float

## 소리가 나는 동안 기본음이 떨어지는 비율. 부딪힌 물체가 에너지를 잃는 것.
var pitch_drop: float


func _init(
	p_tone_ratio: float,
	p_partials: Array[float],
	p_damping: float,
	p_brightness: float,
	p_base_hz: float,
	p_pitch_drop: float
) -> void:
	tone_ratio = p_tone_ratio
	partials = p_partials
	damping = p_damping
	brightness = p_brightness
	base_hz = p_base_hz
	pitch_drop = p_pitch_drop


## 재질 하나를 얻는다. 같은 재질은 같은 인스턴스를 돌려준다 (값이 안 변하므로).
static func of(kind: Kind) -> SfxMaterial:
	if _cache.has(kind):
		return _cache[kind]
	var made := _build(kind)
	_cache[kind] = made
	return made


static func _build(kind: Kind) -> SfxMaterial:
	match kind:
		Kind.METAL:
			# 배음이 많고 오래 운다. 밝다.
			return SfxMaterial.new(0.72, _BAR_MODES, 1.90, 1.50, 620.0, 0.08)
		Kind.WOOD:
			# 배음이 적고 금방 죽는다. 금속보다 낮다.
			return SfxMaterial.new(0.55, [1.0, 2.57, 4.94] as Array[float], 0.85, 0.95, 380.0, 0.20)
		Kind.FLESH:
			# 거의 잡음이다. 울리지 않는다 — 살은 자기 에너지를 즉시 먹는다.
			return SfxMaterial.new(0.14, [1.0, 1.60] as Array[float], 0.70, 0.42, 190.0, 0.38)
		Kind.STONE:
			# 비조화 배음이지만 금속과 달리 즉시 죽는다.
			return SfxMaterial.new(0.34, [1.0, 2.30, 3.87] as Array[float], 0.60, 0.75, 260.0, 0.16)
		Kind.CLOTH:
			# 음이 거의 없다. 짧은 잡음 한 줌.
			return SfxMaterial.new(0.05, [1.0] as Array[float], 0.45, 0.60, 200.0, 0.05)
		Kind.DIRT:
			# 천보다 더 둔하고 더 낮다.
			return SfxMaterial.new(0.08, [1.0] as Array[float], 0.40, 0.35, 120.0, 0.08)
		_:
			return SfxMaterial.new(0.30, [1.0] as Array[float], 0.50, 1.00, 300.0, 0.15)


## 화면에 쓸 이름. 한글이다 — 프로토 화면이 한국어이므로.
static func label(kind: Kind) -> String:
	match kind:
		Kind.METAL:
			return "금속"
		Kind.WOOD:
			return "나무"
		Kind.FLESH:
			return "살"
		Kind.STONE:
			return "돌"
		Kind.CLOTH:
			return "천"
		Kind.DIRT:
			return "흙"
		_:
			return "알 수 없음"
