class_name SparringField
extends RefCounted
## 대련장의 **거리**. 대원이 어디 있고 적이 어디 있는가.
##
## `docs/design/28-combat.md` §28.20.27.
##
## ## 왜 지금 만드나
##
## 사용자가 확정했다: *"무기 액션할때 각 무기 움직임이 애니메이션 말고 실제 캐릭터를
## 얼마나 움직일지도 계산되어야 해. 내리치기가 전진 공격으로 나간다던지 하는것 말이야"*
##
## 그러려면 **둘 다 위치를 가져야 한다.** 지금까지 대련장은 적이 네모 하나고
## 거리가 없었다. 자리를 먼저 만들어 두면 애니 레인의 값이 오는 즉시 붙는다.
##
## ## 아직 안 만드는 것 — 짐작으로 숫자를 넣지 않는다
##
## 애니 레인이 낼 값 둘이 아직 없다.
##
## | 값 | 뜻 |
## | --- | --- |
## | `advance_px(칸수)` | 한 타에 몸이 실제로 나가는 거리 |
## | `reach_px(칸수)` | 닿는 거리 = 팔 + 무기 길이 + 전진 |
##
## **전진은 무기 길이의 역함수다** — `전진 = 목표 간격 - (팔 + 무기 길이)`.
## **짧은 무기가 더 파고든다.** 단검은 붙어야 닿고 창은 제자리에서 닿는다.
##
## 지금 짐작으로 넣으면 값이 왔을 때 두 번 짠다. 그래서 **거리만** 만든다.
##
## ## 「전진 뒤 제자리로 돌아오나」는 미정이다
##
## 사용자가 정한다. **남으면 5타 체인이 다섯 번 밀고 들어간다.**
## 그래서 `advance` 를 여기서 처리하지 않고 자리만 비워 둔다.

## 1픽셀 = 1단위. 화면 좌표와 같은 축을 쓴다 (오른쪽이 +).
var attacker_x: float = 0.0
var target_x: float = 0.0


func _init(p_attacker_x: float = 0.0, p_target_x: float = 240.0) -> void:
	attacker_x = p_attacker_x
	target_x = p_target_x


## 둘 사이의 거리. 항상 0 이상이다.
func gap() -> float:
	return absf(target_x - attacker_x)


## 대원이 적을 바라보는 방향 (+1 오른쪽 / -1 왼쪽).
func facing() -> float:
	return 1.0 if target_x >= attacker_x else -1.0


## 대원을 그만큼 앞으로 민다. **적을 지나치지는 않는다.**
##
## 지나치게 두면 전진이 쌓였을 때 대원이 적 뒤로 빠져 방향이 뒤집힌다.
## 값이 오기 전이라 아직 아무도 안 부르지만, 부를 때 이 성질이 있어야 한다.
func advance(distance: float) -> void:
	if distance <= 0.0:
		return
	var moved := attacker_x + facing() * distance
	if facing() > 0.0:
		attacker_x = minf(moved, target_x)
	else:
		attacker_x = maxf(moved, target_x)


func reset(p_attacker_x: float, p_target_x: float) -> void:
	attacker_x = p_attacker_x
	target_x = p_target_x
