class_name TraitDistribution
extends RefCounted
## 인물 하나의 성향 6축을 뽑는 분포.
##
## docs/design/24-npc-relations.md §24.16.3 의 근거를 코드로 옮긴 것이다.
##
## ## 축마다 균등 난수를 뽑으면 무엇이 문제인가
##
## 축 하나만 보면 균등 난수도 평평하다. **반응의 세기도 사실 거의 같다** —
## §24.4 의 내적은 축값의 표준편차에 비례하고, -100~+100 균등의 표준편차는 57.7 로
## 이미 상한(100)의 절반을 넘는다. 그것을 크게 키우려면 전원을 ±100 근처로 몰아야 하고
## 그러면 §24.3 이 못 박은 "연속값" 이 사실상 이진값이 된다.
##
## **진짜 문제는 인물이 읽히지 않는다는 것이다.** 축 여섯이 각각 독립 균등이면
## 모든 인물이 통계적으로 똑같은 「어중간한 값 여섯 개의 자루」가 된다.
## 뚜렷한 사람도 무색한 사람도 없어서 **기억될 인물을 고를 근거가 세계에 없다.**
##
## ## 그래서 「극(pole) 축의 개수」를 먼저 뽑는다
##
## 인물마다 극 축이 몇 개인지를 분포에서 먼저 정하고, 그 축들만 극값을 준다.
## 결과로 인구가 **뚜렷함으로 갈린다** — 극이 없는 무색한 사람도 있고
## 다섯 축이 극인 극단주의자도 있다. 그것이 렉카가 누구를 쓸지, 플레이어가 누구를
## 기억할지의 근거가 된다.
##
## 극의 경계(POLE_MIN)가 **표집 경계와 같다.** 그래서 "저 사람은 무모한 사람이다" 가
## 읽는 사람의 해석이 아니라 레코드의 사실이 된다.
##
## ## 축 사이에 방향 상관을 넣지 않는다
##
## 어느 축이 극이 될지는 균등하게 고르고 부호는 축마다 독립이다.
## §24.3 이 "선↔악 과 의리↔실리는 겹치지 않는다" 를 설계 근거로 못 박았고,
## 상관을 넣으면 그 절이 예로 든 **「내 팀을 살리려고 다른 팀을 털었다」**
## (의리 +, 선 −) 인물이 생성되지 않는다.
##
## 부호를 상관시키면 세계가 선인과 악인 두 부류로 갈려 **모든 사건의 반응이
## 두 값만 갖는다.** 어긋난 조합이 있어야 "의리는 인정하지만 방식이 틀렸다" 가 나온다.

## 극의 절댓값 하한. 표집 경계이자 "그런 사람" 이라 불리는 경계다.
const POLE_MIN := 60

## 이 절댓값 아래는 **쪽이 없다.** 「약하게 무모하다」가 아니라 「무모·신중에 의견이 없다」다.
##
## docs/design/24-npc-relations.md §24.25.1. 초상 레인이 실호출로 잡았다 —
## 위계 5 를 넘겼더니 GPT 가 **"자유를 중시한다"** 로 읽어 열전에 넣었다.
## **5 는 위계에 대해 아무 의견이 없다는 뜻인데 반대쪽 신념이 됐다.**
##
## 30 인 이유: 축값이 -100~100 이므로 30 은 한쪽 폭(100)의 **3할**이다.
## 이 아래로는 사람이 그 축을 두고 어느 쪽이라 부르지 않는다.
const NEUTRAL_MAX := 30

## 극 축을 k 개 가질 상대 가중치 (k = 0 ~ 6).
##
## 기대값 2.5개. 봉우리를 2에 두고 양쪽으로 흘린다 —
## 극이 없는 무색한 사람 4%, 넷 이상인 극단적인 사람 22% 다.
## **0 과 6 을 0 으로 두지 않는다.** 세계에 예외가 없으면 예외가 특별하지 않다.
const POLE_COUNT_WEIGHTS := [4, 20, 30, 24, 14, 6, 2]


## 인물 하나의 성향 6축. stride 6 배열로 돌려준다 —
## 인물당 배열 객체를 만들지 않으려고 호출자가 이것을 큰 배열에 이어 붙인다
## (PersonRegistry 참고).
static func sample_person(rng: RandomNumberGenerator) -> PackedInt32Array:
	var pole_axes := _pick_pole_axes(rng, pick_pole_count(rng))
	var values := PackedInt32Array()
	for axis in NpcAxis.count():
		var is_extreme: bool = pole_axes.has(axis)
		var magnitude := (
			rng.randi_range(POLE_MIN, NpcAxis.MAX_VALUE)
			if is_extreme
			else rng.randi_range(0, POLE_MIN - 1)
		)
		values.append(magnitude if rng.randf() < 0.5 else -magnitude)
	return values


## 이 인물이 극 축을 몇 개 가질지.
static func pick_pole_count(rng: RandomNumberGenerator) -> int:
	var total := 0
	for weight in POLE_COUNT_WEIGHTS:
		total += int(weight)
	var roll := rng.randi() % maxi(total, 1)
	var running := 0
	for count in POLE_COUNT_WEIGHTS.size():
		running += int(POLE_COUNT_WEIGHTS[count])
		if roll < running:
			return count
	return POLE_COUNT_WEIGHTS.size() - 1


## 이 값은 쪽이 없는가. **말하지 않아야 하는 구간이다.**
static func is_neutral(value: int) -> bool:
	return absi(value) < NEUTRAL_MAX


## 이 값이 극인가. 도구 · 테스트 · 표시가 같은 기준을 쓰게 하려고 함수로 둔다.
static func is_pole(value: int) -> bool:
	return absi(value) >= POLE_MIN


## 인물당 극 축의 기대 개수. 가중치를 베껴 적지 않고 세어서 돌려준다.
static func expected_pole_count() -> float:
	var total := 0.0
	var weighted := 0.0
	for count in POLE_COUNT_WEIGHTS.size():
		var weight := float(POLE_COUNT_WEIGHTS[count])
		total += weight
		weighted += weight * float(count)
	return weighted / maxf(total, 1.0)


## 극 축이 k 개일 비율(0~1). 도구가 실측과 나란히 놓고 본다.
static func expected_ratio(pole_count: int) -> float:
	if pole_count < 0 or pole_count >= POLE_COUNT_WEIGHTS.size():
		return 0.0
	var total := 0.0
	for weight in POLE_COUNT_WEIGHTS:
		total += float(weight)
	return float(POLE_COUNT_WEIGHTS[pole_count]) / maxf(total, 1.0)


## 극 축 k 개를 겹치지 않게 고른다. 어느 축이 극이 되는지에 편향을 두지 않는다.
static func _pick_pole_axes(rng: RandomNumberGenerator, wanted: int) -> PackedInt32Array:
	var axes := PackedInt32Array()
	for axis in NpcAxis.count():
		axes.append(axis)
	# 부분 피셔-예이츠. 축이 여섯뿐이라 전체를 섞어도 되지만 앞 k 개만 필요하다.
	var taken := mini(wanted, axes.size())
	for slot in taken:
		var other := slot + rng.randi() % (axes.size() - slot)
		var held := axes[slot]
		axes[slot] = axes[other]
		axes[other] = held
	return axes.slice(0, taken)
