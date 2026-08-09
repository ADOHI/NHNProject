class_name WeaponMotion
extends RefCounted
## 무기가 **얼마나 나가고 얼마나 닿는가.** 캐릭터 애니 레인이 실측한 값이다.
##
## `docs/design/28-combat.md` §28.20.30.
##
## 사용자 확정: *"무기 액션할때 각 무기 움직임이 애니메이션 말고 실제 캐릭터를
## 얼마나 움직일지도 계산되어야 해. 내리치기가 전진 공격으로 나간다던지 하는것 말이야"*
##
## ## 칸 수가 아니라 **모양**이다
##
## `3x1` 창과 `2x2` 철퇴는 칸 수가 비슷한데 전진이 두 배 넘게 다르다.
## **창은 안 나가고 철퇴는 파고든다.** 그래서 칸 수로는 못 뽑고 **감싸는 상자**로 찾는다.
##
## 애니 레인이 길이 축과 무게 축을 이미 갈라 놨다 — 모양에서 둘이 따로 나온다.
##
## ## `reach` 는 전진을 **포함한다**
##
## `닿는 거리 = 팔 + 무기 길이 + 전진`. 빼고 재면 단검이 실제보다 훨씬 짧은 무기가 된다.
##
## 실제로 표를 뒤집어 보면 `팔 + 무기 길이`(= 리치 − 전진)가 **긴 변에만** 달려 있다:
## 1 → 79 · 2 → 91 · 3 → 99.3 · 4 → 106. `2x1` 과 `2x2` 가 똑같이 91 이다.

## 감싸는 상자 [긴 변, 짧은 변] -> [한 타에 나가는 거리, 닿는 거리].
##
## **이 표는 애니 레인의 실측이다. 손으로 고치지 마라** — 저쪽이 옮기면 여기가 옮겨진다.
## 개전 거리를 제일 짧은 리치보다 얼마나 안쪽에 두나. **닿는다는 것만 보장하면 된다.**
const _OPENING_MARGIN := 8.0

const _TABLE := {
	Vector2i(1, 1): Vector2(25.0, 104.0),
	Vector2i(2, 1): Vector2(16.0, 107.0),
	Vector2i(3, 1): Vector2(10.7, 110.0),
	Vector2i(4, 1): Vector2(12.0, 118.0),
	Vector2i(2, 2): Vector2(22.0, 113.0),
}


## 이 아이템의 [전진, 리치].
##
## 표에 없는 모양은 **같은 긴 변의 얇은 것**으로 근사한다 (예: `3x2` 도끼 -> `3x1`).
## 근사라는 것을 알고 쓰라고 여기 적어 둔다. 표가 늘면 근사가 줄어든다.
static func _entry(item: BackpackItem) -> Vector2:
	var box := item.bounds_size()
	var key := Vector2i(maxi(box.x, box.y), mini(box.x, box.y))
	if _TABLE.has(key):
		return _TABLE[key]
	var thin := Vector2i(clampi(key.x, 1, 4), 1)
	if _TABLE.has(thin):
		return _TABLE[thin]
	return _TABLE[Vector2i(1, 1)]


## 한 타에 몸이 실제로 나가는 거리.
static func advance_px(item: BackpackItem) -> float:
	return _entry(item).x


## 닿는 거리. **전진을 포함한 값이다.**
static func reach_px(item: BackpackItem) -> float:
	return _entry(item).y


## 팔 + 무기 길이. 전진을 뺀 순수 사거리 — 긴 변에만 달려 있다.
static func static_reach_px(item: BackpackItem) -> float:
	var entry := _entry(item)
	return entry.y - entry.x


## 표에 있는 리치 중 **제일 짧은 것**. 누구든 닿는 거리를 잡을 때 쓴다.
##
## ## 왜 상수로 안 박고 표에서 뽑나
##
## **애니 레인 값이 움직이면 우리 거리 전부가 같이 움직여야 한다** (§28.20.50).
## 실제로 몸 비례를 고치면 팔 길이가 바뀌어 리치가 통째로 옮겨진다.
## 96 이나 16 같은 수를 여기저기 박아 두면 **그날 한쪽만 고쳐진다.**
static func min_reach_px() -> float:
	var least := INF
	for entry: Vector2 in _TABLE.values():
		least = minf(least, entry.y)
	return least


## 표에 있는 리치 중 **제일 긴 것**.
static func max_reach_px() -> float:
	var most := 0.0
	for entry: Vector2 in _TABLE.values():
		most = maxf(most, entry.y)
	return most


## **누구든 닿는 개전 거리.** 제일 짧은 무기보다 조금 안쪽이다.
static func opening_gap_px() -> float:
	return min_reach_px() - _OPENING_MARGIN


## **작은 무기는 못 닿고 큰 무기는 닿는 켜 간격** (§28.20.38).
##
## 앞 켜를 `opening_gap_px()` 에 두면 뒤 켜가 **제일 짧은 리치와 제일 긴 리치의 한가운데**
## 에 선다. 그래야 「뒷줄에 닿나」가 물음이 된다 —
## 0 에 가까우면 두 켜가 한 켜가 되고, 크면 뒷줄이 영영 무의미해진다.
static func splitting_rank_depth() -> float:
	return (min_reach_px() + max_reach_px()) * 0.5 - opening_gap_px()


## 이 모양이 표에 그대로 있는가. 없으면 근사값을 쓰고 있다는 뜻이다.
static func is_measured(item: BackpackItem) -> bool:
	var box := item.bounds_size()
	return _TABLE.has(Vector2i(maxi(box.x, box.y), mini(box.x, box.y)))
