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
