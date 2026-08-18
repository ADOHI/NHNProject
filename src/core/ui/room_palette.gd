class_name RoomPalette
extends RefCounted
## 방 위젯의 **역할 → 토큰**. 색 값을 직접 들고 있지 않다.
##
## 컨셉이 아직 안 정해졌고 다섯 후보의 배색이 전부 다르다
## (검정·주황 / 뼈색·청록 / 노랑·마젠타 / 남색·라임 / 흰색·빛의 삼원색).
## 그래서 방 위젯이 색을 직접 적으면 컨셉이 정해지는 순간 전부 고쳐야 한다.
##
## 여기서는 **역할만 정하고** 값은 컨셉에서 꽂는다. 컨셉이 바뀌면 이 파일은 안 바뀐다.
##
## ## 역할이 다섯인데 컨셉의 색은 셋이다
##
## 이것이 이 설계의 진짜 제약이다. 다섯 컨셉 모두 판·강세·글자 **세 색**뿐이라
## 역할마다 색을 하나씩 줄 수가 없다. 그래서 역할을 색이 아니라 **형태**로 가르고
## (→ `RoomMark`), 색은 둘만 쓴다.
##
## | 역할 | 무엇으로 |
## | --- | --- |
## | 바탕 | 판 색 |
## | 숫자 | 글자 색 |
## | **보상** | **강세 색** (쐐기를 채운다) |
## | **위협** | **글자 색** (빗금을 긋는다) |
## | **출입구** | **색 없음** — 실루엣이 말한다 |
##
## 보상만 강세를 쓴다. 둘 다 강세를 쓰면 보스방에서 쐐기와 빗금이 같은 색이 되어
## 「겹쳐 찍기」가 안 보인다.

## 방이 지금 어떤 처지인가. 종류(`RoomMark.Kind`)와 **직교한다** —
## 보스방이면서 못 가는 방일 수 있다.
enum State {
	REACHABLE,  ## 지금 갈 수 있다
	BLOCKED,  ## 고도가 막았다. 위험도 합에는 그대로 포함된다 (07 §7.2.7)
	HERE,  ## 스쿼드가 여기 있다
}

## 무대(판이 얹히는 바탕) 색. 모든 컨셉이 같은 어두운 무대를 쓴다.
const STAGE := Color(0.086, 0.086, 0.094)

var ground: Color = Color.BLACK
var ink: Color = Color.WHITE
var accent: Color = Color.RED


func _init(ground_color: Color, ink_color: Color, accent_color: Color) -> void:
	ground = ground_color
	ink = ink_color
	accent = accent_color


## 컨셉 이름으로 배색을 가져온다. 값의 단일 출처는 각 모션 클래스다 —
## 여기에 색을 복사해 두면 컨셉을 고칠 때 두 곳이 어긋난다.
static func for_concept(name: String) -> RoomPalette:
	match name.to_lower():
		"shear":
			return RoomPalette.new(ShearMotion.BODY, ShearMotion.INK, ShearMotion.ACCENT)
		"hold":
			return RoomPalette.new(HoldMotion.BODY, HoldMotion.INK, HoldMotion.ACCENT)
		"squash":
			return RoomPalette.new(SquashMotion.BODY, SquashMotion.INK, SquashMotion.ACCENT)
		"afterimage":
			return RoomPalette.new(
				AfterimageMotion.BODY, AfterimageMotion.INK, AfterimageMotion.ACCENT
			)
		_:
			return RoomPalette.new(SlamMotion.BODY, SlamMotion.INK, SlamMotion.ACCENT)


## 방 바탕을 채울 색. 못 가는 방은 **채우지 않는다** (알파 0).
##
## 흐리게 칠하지 않는 이유: 흐린 채움은 「덜 중요한 방」으로 읽히는데,
## 못 가는 방의 위험도는 합에 그대로 들어가므로 **덜 중요하지 않다** (07 §7.2.7).
## 채움이 없으면 「설 수 없는 자리」가 되고, 그건 사실과 맞는다.
func fill_for(state: State) -> Color:
	match state:
		State.BLOCKED:
			return Color(ground, 0.0)
		State.HERE:
			return accent
		_:
			return ground


## 방 윤곽선. 못 가는 방만 선이 있다 — 채움이 없으니 선이 대신 자리를 말한다.
##
## **글자 색을 쓰면 안 된다.** 채움이 없으므로 이 선은 판 위가 아니라 **무대 위**에
## 놓인다. 글자 색을 그대로 쓰다가 밝은 판을 쓰는 컨셉(SHEAR · HOLD · AFTERIMAGE)에서
## 검은 선이 어두운 무대에 묻혀 **방이 통째로 사라졌다.**
func outline_for(state: State) -> Color:
	if state == State.BLOCKED:
		return Color(_readable_on(STAGE), 0.70)
	return Color(ink, 0.0)


## 어느 바탕에 얹어도 읽히는 색을 고른다. 판 색과 글자 색 중 **대비가 큰 쪽**이다.
##
## 「여기 있다」에서 채움을 강세로 바꾸고 글자를 판 색으로 뒤집는 규칙을 쓰다가
## 테스트에 걸렸다 — SHEAR 는 강세가 **밝은 청록**이라 밝은 뼈색 글자가 묻혔다.
## 강세가 어두운 컨셉(SLAM · SQUASH)과 밝은 컨셉(SHEAR · HOLD)이 섞여 있으므로
## 뒤집는 방향을 고정할 수 없고, **매번 재야** 한다.
func _readable_on(background: Color) -> Color:
	var to_ground: float = absf(background.get_luminance() - ground.get_luminance())
	var to_ink: float = absf(background.get_luminance() - ink.get_luminance())
	return ground if to_ground > to_ink else ink


func number_for(state: State) -> Color:
	match state:
		State.BLOCKED:
			# 채움이 없어 숫자도 무대 위에 놓인다.
			return Color(_readable_on(STAGE), 0.72)
		State.HERE:
			return _readable_on(accent)
		_:
			return _readable_on(ground)


## 보상 쐐기. 스쿼드가 있는 방에서는 바탕과 강세가 뒤바뀌므로 쐐기도 뒤집는다.
func reward_for(state: State) -> Color:
	match state:
		State.BLOCKED:
			return Color(_readable_on(STAGE), 0.60)
		State.HERE:
			# 바탕이 이미 강세색이라 쐐기는 그 위에서 읽히는 색으로 뒤집는다.
			return _readable_on(accent)
		_:
			return accent


func threat_for(state: State) -> Color:
	match state:
		State.BLOCKED:
			return Color(_readable_on(STAGE), 0.60)
		State.HERE:
			return _readable_on(accent)
		_:
			return _readable_on(ground)
