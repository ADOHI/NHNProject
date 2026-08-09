class_name SparringEnemy
extends RefCounted
## 대련장에 서 있는 적 하나. **자리와 무기뿐이다.**
##
## `docs/design/28-combat.md` §28.20.34.
##
## ## 눈금과 시계는 여기 없다
##
## 무너짐 눈금과 「다음 타가 언제인가」는 `SparringBout` 이 들고 있다.
##
## **수명이 다르기 때문이다.** 눈금은 판이 시작할 때 0 이 되고 판이 끝나면 뜻이 없다.
## 자리는 판보다 오래 산다 — 판을 다시 쏴도 적은 그 자리에 서 있다.
## 한 객체에 섞어 두면 다시 시작할 때 **무엇을 지우고 무엇을 남길지**가 매번 헷갈린다.

## 대련장 좌표(픽셀). 화면 좌표와 같은 축을 쓴다 (오른쪽이 +).
var x: float = 0.0

## 이 적이 들고 있는 것. `null` 이면 반격하지 않는다.
var weapon: BackpackItem = null


func _init(p_x: float = 0.0, p_weapon: BackpackItem = null) -> void:
	x = p_x
	weapon = p_weapon
