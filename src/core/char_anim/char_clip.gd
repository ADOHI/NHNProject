class_name CharClip
extends RefCounted
## 동작 하나. **시각을 넣으면 포즈가 나오는 순수 함수**다.
##
## 노드도, 이전 프레임도, 난수도 안 본다. 같은 `t` 면 언제나 같은 포즈다.
##
## 위치를 프레임마다 기록하고 지연을 링 버퍼로 만드는 방법을 **쓰지 않는다.**
## 궤도가 시각의 함수이면 지연은 그냥 `orbit(t - d)` 이고, 그래서
##
## * 링 버퍼가 없다 — 파츠마다 지연이 달라도 버퍼를 키울 일이 없다
## * 프레임률이 달라져도 지연 간격이 안 변한다 (웹은 단일 스레드라 프레임이 튄다)
## * 임의의 `t` 를 바로 뽑을 수 있다 — **GIF 캡처가 실시간을 안 기다린다**
##
## 그리고 **지수 접근(`current += (target - current) * k`)을 쓰지 않는다.**
## 그것으로는 목표를 지나칠 방법이 아예 없어서 타격감이 원천적으로 불가능하다.
## `get hit` · `jump` 이 오버슛과 되튐을 요구하므로 처음부터 이 구조로 짠다.
## (`docs/design/25-character-animation.md` §25.3)

## 이 정도 안에 있으면 디딘 것으로 본다(px).
const PLANTED_SLACK := 1.0

var rig: CharRig


func _init(p_rig: CharRig) -> void:
	rig = p_rig


func clip_name() -> String:
	return "쉬는 자세"


## 한 바퀴의 길이(초). 루프가 아닌 동작(`die`)은 전체 길이를 돌려준다.
func loop_seconds() -> float:
	return 1.0


## 루프인가. `false` 면 `t` 를 감싸지 않고 끝에서 멈춘다.
func is_looping() -> bool:
	return true


## 하위 클래스가 구현한다. 기반은 쉬는 자세를 돌려준다 — 못 만들면 터지는 대신 서 있다.
func sample(_t: float, _features: AnimFeatures) -> CharPose:
	return CharPose.from_rig(rig)


## `t` 를 한 바퀴 안으로 접는다. 루프가 아니면 끝에서 멈춘다.
func wrap_time(t: float) -> float:
	var span := loop_seconds()
	if not is_looping():
		return clampf(t, 0.0, span)
	return fposmod(t, span)


## 지연이 걸린 사인파. **모든 것이 「시각의 함수」인 지점이 여기다.**
##
## `cycles` 는 **한 바퀴당 도는 횟수**이고 반드시 정수여야 한다. 무리수 비율이면
## 파형이 절대 되돌아오지 않아 GIF 와 게임 루프의 이음매가 툭 끊긴다.
##
## `features.delay` 가 0 이면 지연이 통째로 사라져 모든 파츠가 같은 위상이 된다.
func wave(cycles: float, t: float, delay: float, f: AnimFeatures) -> float:
	return sin(TAU * cycles * (t - delay * f.delay) / loop_seconds())


## 검끝이 바닥을 뚫었으면 **든 손을 그만큼 들어** 띄운다.
##
## **무기는 파츠가 아니라서 접지 검사가 통째로 못 본다**(§25.13.3). 파츠 여섯이 전부
## 땅 위에 멀쩡히 있어도 검은 박혀 있을 수 있고, 무기가 길수록 더 그렇다.
##
## `swing` 은 이것을 **자세를 풀 때 한 번에** 해결한다(§25.16.3) — 보간이 선형이라
## 양 끝만 맞추면 되기 때문이다. 쓰러지는 동작들은 경로가 선형이 아니므로 여기서
## **재서** 올린다. 어느 쪽이든 원칙은 같다 — **예측하지 말고 측정한다.**
##
## 이미 떠 있으면 아무것도 안 한다.
func keep_weapon_off_floor(pose: CharPose, weapon: CharWeapon) -> void:
	var tip := weapon.tip_position(pose, rig)
	var short_by := CharWeapon.TIP_CLEARANCE - tip.y
	if short_by > 0.0:
		pose.positions[CharWeapon.HOLDER] += Vector2(0.0, short_by)


## 면적을 보존하는 배율. `stretch` 가 0 이면 정확히 `Vector2.ONE` 이다.
##
## `1.0 / 1.0` 이 부동소수점에서도 정확히 `1.0` 이므로 "배율 끄기" 가 근사가 아니라 등식이다.
## **손발을 팔이 닿는 거리 안으로 끌어당긴다** (§25.29).
##
## **방향은 안 건드리고 거리만 줄인다.** 자세가 무엇을 하려던 것인지는 방향에 들어 있고,
## 그것은 그대로 두어야 하기 때문이다. 그래서 **과장이 사라지는 게 아니라 각도로 남는다.**
##
## 모든 클립이 자세를 내놓기 직전에 부른다.
## **디딘 발은 안 건드린다.** 땅이 이긴다 (§25.13.4) — 발이 땅에 붙어 있는데 끌어당기면
## 그 순간 **발이 미끄러진다.** 디딘 발이 멀면 그건 발이 아니라 **몸이 너무 간 것**이라,
## 발을 옮겨서 고칠 문제가 아니다.
func rein_in_limbs(pose: CharPose) -> void:
	for part in CharPart.COUNT:
		var limit := rig.reach_limit(part)
		if limit == INF:
			continue
		if CharPart.is_foot(part) and foot_is_planted(pose, part):
			continue
		var socket := pose.socket_of(part, rig)
		var arm := pose.positions[part] - socket
		if arm.length() > limit:
			pose.positions[part] = socket + arm.normalized() * limit


## 그 발이 지금 **땅을 디디고 있나.**
func foot_is_planted(pose: CharPose, part: CharPart.Id) -> bool:
	if not CharPart.is_foot(part):
		return false
	return pose.part_lowest(part, rig) <= rig.ground_y(part) + PLANTED_SLACK


static func volume_scale(stretch: float) -> Vector2:
	var sy := 1.0 + stretch
	return Vector2(1.0 / sy, sy)
