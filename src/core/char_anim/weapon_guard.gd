class_name WeaponGuard
extends RefCounted
## 무기를 든 **자세**. 공격 하나가 「어느 자세에서 시작해 어느 자세로 끝나는가」다.
##
## **이것이 값으로 남아 있어야 동작이 이어진다.** 통합자가 사용자에게 제안한 규칙이
## 있다(아직 확정 아님) — *앞 동작의 마무리 자세가 다음 동작의 시작 자세여야 이어진다.*
## 위로 올려친 뒤에는 위에서 내려찍는 것이 이어진다는 뜻이다.
##
## 그 규칙으로 가면 **체인 조건이 그냥 `앞.to_guard == 뒤.from_guard`** 가 된다.
## 확정되지 않았으므로 판정은 여기서 안 한다 — **값만 남긴다.**
##
## 축을 넷으로 잡았다. 더 잘게 나눌 수 있지만 넷이면 위 · 아래 · 찌르기가 다 나오고,
## 늘리는 것은 쉽고 줄이는 것은 어렵다.

enum Id { NEUTRAL, HIGH, LOW, THRUST }

## 자세 하나가 정하는 것은 셋이다 — 든 손이 쉬는 자리에서 얼마나 벗어났는가(`x` `y`),
## 그리고 **무기가 화면에서 어느 각도인가**(`z`, 반시계 양수).
##
## 손의 회전이 아니라 **무기의 각도**로 적는다. 무기는 손의 자식이라 손 회전에
## `CharWeapon.REST_ANGLE` 이 더해져 화면 각도가 나오는데, 사람이 자세를 읽을 때
## 보는 것은 **검이 어디를 향하는가**이지 손목이 몇 도인가가 아니다.
const POSES: Dictionary[Id, Vector3] = {
	# 쉬는 자세. 검이 비스듬히 아래로 내려가 있다.
	Id.NEUTRAL: Vector3(0.0, 0.0, -0.55),
	# 머리 위로 치켜든 자세. 손이 뒤로 · 위로 가고 검이 뒤 위를 가리킨다.
	Id.HIGH: Vector3(-14.0, 30.0, 2.05),
	# 내려찍고 난 자세. 손이 앞으로 가고 검끝이 땅을 향한다.
	#
	# **두 번 고쳤다.** 처음 `(12, −18, −1.35)` 는 손이 내려간 데다 날이 거의 수직이라
	# 검끝이 `y = −17` 로 바닥을 뚫었다. 다음 값도 **오버슛하는 순간에** 뚫었다 —
	# 마무리 자세만 보고 정했기 때문이다.
	#
	# **검이 길다(캐릭터 키의 45 %).** 손 높이에서 아래로 내리면 무조건 바닥에 닿으므로,
	# 「내려찍기」의 마무리는 **아래**가 아니라 **앞아래**여야 한다.
	Id.LOW: Vector3(16.0, 4.0, -0.72),
	# 찌르기. 손이 앞으로 뻗고 검이 수평으로 앞을 가리킨다.
	Id.THRUST: Vector3(26.0, 6.0, 0.02),
}


static func pose(id: Id) -> Vector3:
	return POSES[id]


## 손이 쉬는 자리에서 벗어난 거리 (캐릭터 공간, `+y` 위).
static func hand_offset(id: Id) -> Vector2:
	var p := POSES[id]
	return Vector2(p.x, p.y)


## 무기가 화면에서 향하는 각도.
static func weapon_angle(id: Id) -> float:
	return POSES[id].z


## 그 자세를 만들려면 손을 얼마나 돌려야 하는가.
##
## 무기가 손의 자식이라 **화면 각도 = 손 회전 + 무기의 쉬는 각도**다. 뒤집어 푼다.
static func hand_rotation(id: Id) -> float:
	return weapon_angle(id) - CharWeapon.REST_ANGLE


static func guard_name(id: Id) -> String:
	match id:
		Id.HIGH:
			return "위"
		Id.LOW:
			return "아래"
		Id.THRUST:
			return "찌르기"
		_:
			return "제자리"
