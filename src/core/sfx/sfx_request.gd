class_name SfxRequest
extends RefCounted
## 소리 요청 — **계약 층**이다 (docs/design/29-sound.md §29.2).
##
## 호출하는 쪽은 파일 이름을 모른다. "3칸짜리 금속이 살을 때렸다" 를 말하면 되고,
## 그게 무슨 소리가 되는지는 아래층(SfxSynth 또는 나중의 샘플)이 정한다.
##
## 이 클래스가 안 바뀌는 것이 핵심이다. 원천을 갈아 끼울 때
## 전투 코드와 UI 코드는 한 줄도 안 고친다.

## 소리의 종류. 재질과 무게로 못 나누는, **생성 방식 자체가 다른** 넷.
enum Kind {
	IMPACT,  ## 부딪힘. 잡음 + 울림 + 지수 감쇠
	WHOOSH,  ## 공기를 가름. 휘두르기 예비 구간
	TICK,  ## 아주 짧은 딸깍. UI 커서 · 조각 도착
	TONE,  ## 음정이 있는 짧은 신호. 확인 · 취소 · 열림
}

## 음정이 움직이는 방향. 열림과 닫힘을 무게만으로는 못 가른다.
enum Bend {
	FLAT,  ## 안 움직인다
	UP,  ## 올라간다 — 열림 · 확인 · 얻음
	DOWN,  ## 내려간다 — 닫힘 · 취소 · 막힘
}

const MIN_WEIGHT := 1.0
const MAX_WEIGHT := 4.0

var kind: Kind
var material: SfxMaterial.Kind
## 1..4. 무기 칸 수와 같은 축이다 (src/core/char_anim/char_weapon.gd 의 cells).
var weight: float
var bend: Bend
## 변주 씨. 같은 씨는 항상 같은 소리다 — 테스트가 성립하려면 결정적이어야 한다.
var seed: int
## 최종 음량 배수. 배치 층이 상황에 따라 줄일 때만 쓴다.
var gain: float


func _init(
	p_kind: Kind,
	p_material: SfxMaterial.Kind,
	p_weight: float = 1.0,
	p_bend: Bend = Bend.FLAT,
	p_seed: int = 0,
	p_gain: float = 1.0
) -> void:
	kind = p_kind
	material = p_material
	weight = clampf(p_weight, MIN_WEIGHT, MAX_WEIGHT)
	bend = p_bend
	seed = p_seed
	gain = p_gain


## 부딪힘. 가장 많이 쓰는 것이라 이름을 짧게 둔다.
static func impact(
	material_kind: SfxMaterial.Kind, weight: float, variation_seed: int = 0
) -> SfxRequest:
	return SfxRequest.new(Kind.IMPACT, material_kind, weight, Bend.FLAT, variation_seed)


## 공기를 가름.
static func whoosh(
	material_kind: SfxMaterial.Kind, weight: float, variation_seed: int = 0
) -> SfxRequest:
	return SfxRequest.new(Kind.WHOOSH, material_kind, weight, Bend.FLAT, variation_seed)


## 짧은 딸깍.
static func tick(
	material_kind: SfxMaterial.Kind, weight: float = 1.0, variation_seed: int = 0
) -> SfxRequest:
	return SfxRequest.new(Kind.TICK, material_kind, weight, Bend.FLAT, variation_seed)


## 음정이 있는 신호.
static func tone(
	material_kind: SfxMaterial.Kind,
	weight: float = 1.0,
	p_bend: Bend = Bend.FLAT,
	variation_seed: int = 0
) -> SfxRequest:
	return SfxRequest.new(Kind.TONE, material_kind, weight, p_bend, variation_seed)


## 씨만 바꾼 사본. 체인 5타가 같은 소리로 안 들리게 하는 데 쓴다 (§29.6).
func with_seed(variation_seed: int) -> SfxRequest:
	return SfxRequest.new(kind, material, weight, bend, variation_seed, gain)


## 무게만 바꾼 사본. 무기 칸 수를 배치 층이 꽂을 때 쓴다.
func with_weight(new_weight: float) -> SfxRequest:
	return SfxRequest.new(kind, material, new_weight, bend, seed, gain)


## 음량만 바꾼 사본.
func with_gain(new_gain: float) -> SfxRequest:
	return SfxRequest.new(kind, material, weight, bend, seed, new_gain)


## 캐시 열쇠. 씨는 뺀다 — 씨는 재생 시점에 흔들리므로 굽는 단위가 아니다.
##
## 씨를 포함하면 캐시가 무한히 늘어난다. 대신 §29.6 의 변주 폭 안에서
## 미리 구운 몇 벌을 돌려쓴다 (SfxBank).
##
## **`gain` 은 반드시 들어가야 한다.** SfxSynth 가 정규화할 때 gain 을 곱하므로
## 같은 재질 · 무게라도 gain 이 다르면 다른 파형이다. 뺐더니 "대기" 와 "재개" 가
## 같은 열쇠로 묶여 한쪽 음량이 다른 쪽 것으로 재생됐다.
func bake_key() -> String:
	return "%d:%d:%.2f:%d:%.2f" % [kind, material, weight, bend, gain]
