class_name TitleLayers
extends RefCounted
## **겹의 배치표.** 무엇이 어디에 어느 깊이로 앉는가.
##
## 타이틀 화면은 한 장이 아니라 겹이다. 한 장이면 아무것도 못 움직인다 —
## 겹을 따로 뽑는 이유가 그것이고, 그러면 **어디에 앉힐지를 정하는 표**가 필요해진다
## (docs/design/21-title.md §21.13).
##
## 여기는 순수 데이터다. 노드도 텍스처도 모르고 자리와 깊이만 안다.
## 그래서 그림이 아직 없어도 배치를 검사할 수 있고, 그림이 바뀌어도 배치는 남는다.
##
## ---
##
## **깊이가 곧 시차이자 그리는 순서다.**
##
##   0.0  배경   거의 안 움직인다
##   ...  중앙   화면의 주인공. 빛이 여기서 난다
##   ...  중경   인간. 시차를 두고 다가온다
##   ...  원경   악마. 눈이 굴러가고 웃음이 흔들린다
##   1.0  전경   가장 빨리 흐른다
##
## 원경(악마)이 중경(인간)보다 **뒤**라는 것이 헷갈리기 쉽다. 이름은 원경이지만
## 화면에서는 인간 뒤 · 배경 앞이다. 시선의 사슬이 그 순서를 요구한다 —
## 악마가 인간을 내려다보려면 인간보다 뒤에 있어야 한다.

## 겹이 하는 일. 움직임의 종류가 여기서 갈린다.
enum Role {
	## 던전 공간. 거의 안 움직인다
	BACKDROP,
	## 상자와 갈라진 금. 빛도 여기서 난다
	HOARD,
	## 인간 헌터. 한 번에 하나씩 다가온다
	HUNTER,
	## 눈 하나 달린 악마. 눈이 굴러가고 웃음이 흔들린다
	DEMON,
	## 가장 앞. 가장 빨리 흐른다
	FOREGROUND,
}


## 겹 하나의 사양.
class Spec:
	extends RefCounted

	## 그림 파일 이름이자 겹의 이름.
	var id := ""

	var role := Role.BACKDROP

	## 화면 안에서의 자리(0~1). 겹의 **가운데**가 앉는 곳이다.
	var anchor := Vector2(0.5, 0.5)

	## 화면 짧은 변에 대한 크기 비율. 0 이면 화면을 꽉 채운다(배경·전경).
	var span := 0.0

	## 깊이(0~1). 시차의 세기이자 그리는 순서다.
	var depth := 0.0

	## 이 겹이 무엇을 보는가. 시선의 사슬이 여기에 적힌다.
	var watching := ""

	func _init(
		id_value: String,
		role_value: Role,
		anchor_value: Vector2,
		span_value: float,
		depth_value: float,
		watching_value: String = ""
	) -> void:
		id = id_value
		role = role_value
		anchor = anchor_value
		span = span_value
		depth = depth_value
		watching = watching_value


## 배경이 화면을 넘어 그려지는 비율. 시차로 흘러도 가장자리가 드러나면 안 된다.
const OVERSCAN := 1.12

## 원경에 곱하는 색. **깊이는 자리만으로 나지 않는다.**
##
## 이 값을 세 번 고쳤고 그 과정이 곧 근거다.
##
## | 값 | 무슨 일이 났나 |
## | --- | --- |
## | 차갑게 (0.88, 0.93, 1.0) | 악마가 청회색 벽에 **녹아 사라졌다** |
## | 따뜻하게 (1.0, 0.95, 0.90) | 심사자 둘이 **"근경 컷아웃"** 이라고 똑같이 지적했다 |
## | **차갑고 어둡게** | 아래 |
##
## 첫 번째가 사라진 진짜 원인은 색이 아니라 **가장자리를 0 까지 깎은 것**이었다.
## 그것을 고치고 나니 차갑게 밀어도 형체가 남는다. 그래서 공기 원근으로 되돌리되
## **어둡게까지 같이 민다** — 심사자 둘이 따로 같은 말을 했다. *배경 건축은 뿌옇게
## 물러나 있는데 같은 깊이의 악마만 채도와 명암이 다 살아 있다.*
##
## 밝기를 낮추는 것이 색을 미는 것보다 세다. 이 방의 유일한 광원이 가운데 금이라
## **금에서 먼 것은 어두워야 하고, 악마는 가장 멀다.**
const DEMON_HAZE := Color(0.72, 0.80, 0.92, 0.92)

## 전경에 곱하는 색. **전경은 거의 실루엣이어야 한다.**
##
## 생성된 바위가 방보다 밝게 나와서 화면 아래를 눈처럼 덮었다. 유일한 광원이
## 가운데 금인 화면에서 **가장 가까운 겹이 가장 밝으면 빛의 근거가 무너진다.**
## 곱하기라 위 가장자리의 따뜻한 테두리 빛은 상대적으로 남는다 —
## 어두워지면서 테두리만 살아나는 것이 실루엣이다.
const FOREGROUND_SHADE := Color(0.50, 0.57, 0.68)


## **배치표 전체.** 순서가 곧 그리는 순서(뒤 → 앞)다.
##
## 인간 넷은 시점이 제각각이다 — 사방에서 오는데 전부 정측면이면 사방이 안 된다.
## 뒷모습이 가장 앞(카메라 가까이)에 오는 것이 중요하다. 그러면 화면이
## "구경하는 그림"이 아니라 **내가 그 자리에 있는 그림**이 된다.
static func plan() -> Array[Spec]:
	var specs: Array[Spec] = []
	specs.append(Spec.new("backdrop", Role.BACKDROP, Vector2(0.5, 0.5), 0.0, 0.0))

	# 악마는 인간보다 뒤, 배경보다 앞. 위에 몰아 두고 크기로 원근을 준다.
	# 먼 것부터 앉힌다 — 배열 순서가 곧 그리는 순서다.
	#
	# **상자와 사람의 실루엣을 침범하지 않는다**(§21.13.9). 금 간 금이 주인공인데
	# 원경이 그 위에 겹치면 주인공이 가려진다. 가운데 세로 기둥(상자와 균열이 지나는
	# 자리)은 **가장 먼 하나만** 훨씬 위로 지나가고 나머지 둘은 좌우 끝으로 밀려난다.
	# 크기도 줄였다 — 원경이 근경보다 크면 그것은 원경이 아니다.
	# 겹치지 않는다는 것은 말이 아니라 `test_title_layers.gd` 가 지킨다.
	#
	# **머리가 화면 위로 잘리면 안 된다.** 처음 밀어 올렸을 때 셋 다 정수리가 잘려
	# 벽에 붙은 딱지처럼 보였다. 좌우의 둘은 상자가 아니라 **사람의 위쪽 한계**까지만
	# 내려오면 되므로(그 옆은 비어 있다) 그만큼 내려 앉혀 온몸이 화면 안에 들어온다.
	#
	# 크기는 심사 뒤 한 번 더 줄였다. *"왼쪽 것의 머리 하나가 사람 몸통보다 넓다.
	# 그게 멀리 있으면서 저만큼 크면 자동차만 하다는 뜻이라 뇌가 가깝다고 읽는다."*
	# **원경은 사람보다 작아야 원경이다.**
	specs.append(Spec.new("demon_c", Role.DEMON, Vector2(0.50, 0.135), 0.165, 0.10, "hunter_front"))
	specs.append(Spec.new("demon_b", Role.DEMON, Vector2(0.85, 0.17), 0.23, 0.13, "hunter_right"))
	specs.append(Spec.new("demon_a", Role.DEMON, Vector2(0.15, 0.175), 0.245, 0.18, "hunter_left"))

	# 판 건너편에서 오는 사람. **상자보다 뒤다** — 금 너머에 서 있기 때문이다.
	# 그래서 상자가 이 사람의 다리를 가린다. 그 가림이 곧 깊이다.
	specs.append(Spec.new("hunter_front", Role.HUNTER, Vector2(0.50, 0.44), 0.34, 0.24, "hoard"))

	# 금. 화면의 주인공이고 유일한 광원이다.
	specs.append(Spec.new("hoard", Role.HOARD, Vector2(0.5, 0.60), 0.62, 0.30))

	# 옆에서 오는 둘. 깊이가 서로 달라 겹쳐 보인다 —
	# 다 같은 깊이에 놓으면 오려 붙인 스티커가 된다.
	specs.append(Spec.new("hunter_left", Role.HUNTER, Vector2(0.19, 0.58), 0.46, 0.44, "hoard"))
	specs.append(Spec.new("hunter_right", Role.HUNTER, Vector2(0.81, 0.56), 0.44, 0.48, "hoard"))
	# 뒷모습이 가장 앞이자 가장 크다. **여기가 플레이어의 자리다.**
	specs.append(Spec.new("hunter_back", Role.HUNTER, Vector2(0.63, 0.86), 0.72, 0.72, "hoard"))

	specs.append(Spec.new("foreground", Role.FOREGROUND, Vector2(0.5, 1.0), 0.0, 1.0))
	return specs


## 이름으로 찾기. 시선의 사슬을 이을 때 쓴다.
static func find(specs: Array[Spec], id: String) -> Spec:
	for spec in specs:
		if spec.id == id:
			return spec
	return null


## 그 겹이 화면에서 차지하는 사각형.
##
## 배경과 전경은 화면을 꽉 채우고(`span` 0), 나머지는 짧은 변 기준으로 잰다 —
## 화면이 가로로 길어져도 인물이 늘어나면 안 된다.
static func rect_of(spec: Spec, screen: Vector2, aspect: float) -> Rect2:
	if spec.span <= 0.0:
		var big := screen * OVERSCAN
		return Rect2((screen - big) * 0.5, big)
	var short := minf(screen.x, screen.y)
	var size := Vector2(short * spec.span * aspect, short * spec.span)
	return Rect2(spec.anchor * screen - size * 0.5, size)


## 시차로 밀리는 양. 깊이가 클수록 많이 흐른다.
##
## 배경이 0 이 아니라 아주 작은 값인 이유는, 완전히 고정된 배경 앞에서 다른 겹만
## 움직이면 **배경이 벽지로 보이기** 때문이다. 조금은 따라와야 공간이 된다.
static func drift_of(spec: Spec, sway: Vector2) -> Vector2:
	return sway * (0.06 + spec.depth * 0.94)
