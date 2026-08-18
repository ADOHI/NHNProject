class_name MonstranceShowcase
extends Control
## 컨셉 견본 — **「현시(顯示)」.** 정지 한 장과 GIF 를 같이 낸다.
##
## > **금이 방사하고, 창이 하나다.**
##
## 층은 이렇게 갈랐다. 장식을 섞은 것이 아니라 **층마다 어느 쪽인지 정한 것**이다
## (docs/design/20-ui-kit.md §20.6.4).
##
## | 층 | 어느 쪽 | 왜 이 층인가 |
## | --- | --- | --- |
## | **구조 · 시선 유도** | 클래식 | 방사는 장식이 아니라 **시선을 한 점으로 모으는 광학**이다 |
## | **재료 · 세공** | 클래식 | 금박 · 타출 · 물린 보석. **화려함이 여기서만 나온다** |
## | **창 안** | 디지털 | 갱신되고 반전되고 잔상이 남는다 |
## | **거동** | 디지털 | 금이 찍혀 들어오고, 눌리면 역류한다 |
##
## ## 한 낱말이 두 층을 다 쥔다
##
## **顯示** 는 화면(display)이고 동시에 **현시대(顯示臺)** — 중심의 작은 창 하나를
## 위해 사방으로 금 광선이 뻗는 금세공품이다. 둘 다 「안에 있는 것을 밖에서 보게
## 만드는 장치」라서 억지가 아니다.
##
## ## 왜 이 게임인가
##
## 그놈들은 유희로 게이트를 열고 인간은 금 때문에 제 발로 들어간다
## ([`02`](../../../docs/design/02-overview.md) §2.6.1). **그래서 금이 화면을 덮고
## 목숨 걸린 숫자는 창 한 칸이다.** 그 비례가 이 세계의 잔인함이다.

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

# --- 색 — 문장학 규칙으로 붙인다 (§20.6.3) --------------------------------
#
# 금속색(금)과 색채(주홍 · 청금석)를 **직접 인접시키지 않는다.** 사이에 심연이 든다.
# 그래서 색이 넷인데 싸우지 않고, 채도를 낮추지 않고 대비를 얻는다.

## 심연 — 금과 색채를 가르는 것. 거의 검정이지만 완전 검정은 아니다.
const VOID := Color(0.043, 0.036, 0.043)

## 청금석 — **정보의 색.** 창 안에만 있다.
const LAPIS := Color(0.055, 0.078, 0.216)
const LAPIS_LIT := Color(0.588, 0.686, 0.945)

## 상아 — 창 안의 본문.
const IVORY := Color(0.929, 0.902, 0.827)

## 진사(辰砂) — **한 화면에 한 자리.** 격자를 깨는 그 한 줄.
const VERMILION := Color(0.851, 0.208, 0.129)

## 금 — 에셋이 없을 때의 대역이고, 머리카락 괘선의 색이다.
const GOLD := Color(0.859, 0.694, 0.373)
const GOLD_DEEP := Color(0.353, 0.251, 0.106)

## 방사 광선 수. 짝수 자리가 긴 벌, 홀수 자리가 짧은 벌이다.
##
## 열여섯인 이유: 부채가 183도라 슬롯이 11.4도이고, 긴 벌 반폭 54px 이 리치 1150 에서
## 2.7도를 먹는다. 갑절로 늘리면 슬롯이 5.7도가 되어 **광선 사이 심연이 사라진다** —
## 심연이 없으면 문장학 규칙(금과 색채를 가른다)이 무너지고 그냥 금색 원판이 된다.
const RAYS := 16

## 반전이 유지되는 시간. **20fps 에서 세 프레임 이상 잡혀야 눌린 것으로 보인다.**
const INVERT_FOR := 0.12

## 창(팝업)의 자리와 크기. 화면 중앙이 아니다 — 방사 중심에서 비켜 있어야
## 광선이 창 뒤로 지나간다.
const PANE := Rect2(96.0, 104.0, 560.0, 332.0)

var _ray: Texture2D
var _gild: Texture2D
var _fissure: Texture2D
var _silk: Texture2D
var _stones: Texture2D
var _font: FontVariation

var _radiance: Monstrance

## 시계 셋. **경과 시간의 함수라 오버슛이 성립한다** (`KitEase` 모듈 주석).
var _clock := 0.0
var _since_gild := 0.0
var _since_press := -1.0

## 상시 모션을 세울 수 있다. 정지 화면으로 판정할 때 쓴다.
var _frozen := false

## 견본 안내를 띄울지. 캡처는 끈다.
var _legend_shown := true

## 시계를 밖에서 잡는지. 캡처 도구가 `add_child()` **전에** 켠다.
##
## **`_ready()` 에서 `set_process(true)` 를 하고 캡처 도구가 뒤에서 `set_process(false)`
## 하게 두면 조용히 씹힌다.** `SceneTree._initialize()` 안의 `add_child()` 는 `_ready()`
## 를 그 자리에서 부르지 않아서, 도구가 끈 다음에 `_ready()` 가 다시 켜 버린다.
## 실제로 그 사고가 났다 — 눌림이 프레임마다 delta 만큼 저절로 흘러서 GIF 에서
## **역류가 한 프레임도 안 걸렸다.** 그래서 깃발을 두고 `_process` 자체를 막는다
## (docs/conventions.md 의 「조용히 거짓말하는 것」).
var _driven := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = FontVariation.new()
	_font.base_font = FONT
	_ray = _try_load("kit_ray")
	_gild = _try_load("kit_gild")
	_fissure = _try_load("kit_fissure")
	_silk = _try_load("kit_silk")
	_stones = _try_load("kit_stones")
	set_process(not _driven)


func _try_load(asset: String) -> Texture2D:
	var path := "res://assets/ui/kit/%s.webp" % asset
	if not ResourceLoader.exists(path):
		push_warning("에셋이 없다: " + path)
		return null
	return load(path) as Texture2D


func _process(delta: float) -> void:
	if _driven:
		return
	if not _frozen:
		_clock += delta
	_since_gild += delta
	if _since_press >= 0.0:
		_since_press += delta
		if _since_press > Monstrance.PRESS_TIME:
			_since_press = -1.0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		press()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_SPACE:
		press()
	elif key.keycode == KEY_R:
		_since_gild = 0.0
	elif key.keycode == KEY_S:
		_frozen = not _frozen


## 눌림. **방사가 중심으로 역류하고 창이 반전한다.**
func press() -> void:
	_since_press = 0.0


## 시계를 밖에서 잡겠다고 선언한다. **`add_child()` 전에 불러야 한다** (`_driven` 주석).
func drive_externally() -> void:
	_driven = true
	set_process(false)


## 캡처 도구가 시계를 직접 잡는다. 창 주기가 60Hz 인지 165Hz 인지에
## 따라 프레임이 달라지면 GIF 를 비교할 수 없다.
func set_clock(clock: float, since_gild: float, since_press: float) -> void:
	_clock = clock
	_since_gild = since_gild
	_since_press = since_press
	queue_redraw()


func _draw() -> void:
	# 방사의 중심은 **화면 중앙이 아니다.** 오른쪽 아래에 있어서 모든 광선이
	# 왼쪽 위로 사선으로 올라간다 — 정지 화면에 쏠린 무게가 생긴다 (§20.6.5).
	var hub := Vector2(size.x * 0.790, size.y * 0.800)
	# 부채가 183도다. 138도로 잡았더니 **화면 왼쪽 아래가 통째로 비었다** — 방사가
	# 한쪽으로 몰리면 쏠린 무게가 아니라 그냥 반쪽이 빈 화면이 된다.
	_radiance = Monstrance.new(hub, RAYS, -3.55, -0.35, 46.0, size.x * 0.90, 54.0, 62.0)

	draw_rect(Rect2(Vector2.ZERO, size), VOID)
	_draw_halo(hub)
	_draw_rays()
	_draw_slab()
	_draw_pane()
	_draw_silk()
	_draw_boss(hub)
	_draw_legend()


## 후광 — 삼각 부채를 하나씩 그려 만든 방사 그라디언트.
##
## `draw_polygon` 은 꼭짓점마다 색을 받으므로 삼각형 하나로 「중심은 밝고 바깥은
## 투명」을 만들 수 있다. 셰이더도 텍스처도 필요 없고, 광선 **아래**에 깔려서
## 금이 어둠에서 떠오르게 한다.
func _draw_halo(hub: Vector2) -> void:
	# **후광이 짧아서 광선 끝이 검정 위에서 죽었다.** 부채 리치보다 길어야 한다.
	var steps := 40
	var reach := size.x * 1.45
	var lit := Color(0.545, 0.353, 0.110, 0.72)
	var gone := Color(0.114, 0.071, 0.086, 0.0)
	for i in range(steps):
		var a0 := (
			_radiance.angle_from
			+ (_radiance.angle_to - _radiance.angle_from) * (float(i) / float(steps))
		)
		var a1 := (
			_radiance.angle_from
			+ (_radiance.angle_to - _radiance.angle_from) * (float(i + 1) / float(steps))
		)
		draw_polygon(
			PackedVector2Array(
				[
					hub,
					hub + Vector2(cos(a0), sin(a0)) * reach,
					hub + Vector2(cos(a1), sin(a1)) * reach,
				]
			),
			PackedColorArray([lit, gone, gone])
		)


## 방사 — 이 화면의 대부분. **광선마다 위상이 다르다.**
##
## 광선 하나를 회전 배치해 스물넷을 만든다. 텍스처가 하나라 용량이 싸고,
## 회전이 각각이라 세공 무늬가 같은 방향으로 정렬되지 않는다.
func _draw_rays() -> void:
	var reach_scale := _radiance.press_reach(_since_press)
	for i in range(RAYS):
		var gild := _radiance.gild_progress(i, _since_gild)
		if gild <= 0.002:
			continue
		var rect := _radiance.ray_rect(i, reach_scale * gild)
		draw_set_transform(_radiance.center, _radiance.ray_rotation(i), Vector2.ONE)
		if _ray != null:
			# 뿌리 쪽이 밝고 끝이 잦아든다. 금이 **중심에서 나온다**는 표시다.
			var body := Color(0.98, 0.92, 0.84, 0.72 + 0.28 * gild)
			draw_texture_rect(_ray, rect, false, body)
			_draw_sheen(i, rect)
		else:
			draw_rect(rect, GOLD_DEEP)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 상시 광택 — 광선을 훑고 지나가는 밝은 띠. **이것이 상시 모션 전부다.**
##
## 같은 텍스처의 **일부 구역**을 밝게 한 번 더 얹는다. 재질이 이미 금이라
## 밝게 곱하면 정반사로 읽힌다 — 별도 에셋도 가산 블렌드 재질도 필요 없다.
func _draw_sheen(i: int, rect: Rect2) -> void:
	var at := _radiance.sheen_at(i, _clock)
	var band := 0.17
	var v0 := clampf(at - band, 0.0, 1.0)
	var v1 := clampf(at + band, 0.0, 1.0)
	if v1 - v0 < 0.01:
		return
	var full := _ray.get_size()
	# 텍스처는 뿌리가 아래(v=1)라 광택 위치를 뒤집어 읽는다.
	var region := Rect2(Vector2(0.0, full.y * (1.0 - v1)), Vector2(full.x, full.y * (v1 - v0)))
	var slice := Rect2(
		Vector2(rect.position.x, rect.position.y + rect.size.y * (1.0 - v1)),
		Vector2(rect.size.x, rect.size.y * (v1 - v0))
	)
	# 띠 가운데에서 가장 세다. 끝이 딱 끊기면 사각형으로 보인다.
	var strength := sin(PI * clampf(at, 0.0, 1.0))
	draw_texture_rect_region(_ray, slice, region, Color(1.62, 1.42, 1.02, 0.28 + 0.30 * strength))


## 금 판 — 창을 물고 있는 세공판. **직사각형이 아니다.**
##
## 오른쪽 아래 모서리를 잘라 낸다. 그쪽이 방사의 중심이라 판이 광선에 **깎인** 것으로
## 읽히고, 사방이 반듯한 판은 어느 UI 에나 있다.
func _draw_slab() -> void:
	var box := PANE.grow(30.0)
	var cut := 74.0
	var shape := PackedVector2Array(
		[
			box.position,
			Vector2(box.end.x, box.position.y),
			Vector2(box.end.x, box.end.y - cut),
			Vector2(box.end.x - cut, box.end.y),
			Vector2(box.position.x, box.end.y),
		]
	)
	# 심연을 한 겹 먼저 깐다 — 금과 뒤의 금 광선 사이를 가르는 것이 문장학 규칙이다.
	var moat := PackedVector2Array()
	var mid := box.get_center()
	for p in shape:
		moat.append(mid + (p - mid) * 1.035)
	draw_colored_polygon(moat, Color(VOID.r, VOID.g, VOID.b, 0.90))
	if _gild != null:
		# **크림색으로 날았다.** 금박 에셋 자체가 밝아서 흰색으로 곱하면 대리석이 된다.
		draw_colored_polygon(shape, Color(0.60, 0.47, 0.32), _uvs(shape, _gild, 1.0), _gild)
	else:
		draw_colored_polygon(shape, GOLD_DEEP)
	# **금 간 금.** 갈라진 도금을 금 위에 얹는다 — 게임의 제목이 이것이다.
	if _fissure != null:
		draw_colored_polygon(
			shape, Color(0.13, 0.09, 0.07, 0.82), _uvs(shape, _fissure, 0.55), _fissure
		)
	# 판 테두리의 심연 한 줄. 금끼리 맞닿는 자리를 가른다.
	var closed := PackedVector2Array(shape)
	closed.append(shape[0])
	draw_polyline(closed, Color(0.09, 0.07, 0.06), 2.0)


## 다각형에 텍스처를 앉힐 UV. **빈 배열로 넘기지 않는다** — 엔진이 정하게 두면
## 판 위치를 옮길 때마다 무늬가 조용히 딸려 움직인다.
func _uvs(shape: PackedVector2Array, texture: Texture2D, zoom: float) -> PackedVector2Array:
	var span := texture.get_size() * zoom
	var out := PackedVector2Array()
	for p in shape:
		out.append(p / span)
	return out


## 창(팝업) — **정보는 여기에만 있다.** 금 안에 물린 청금석 판이다.
##
## 팝업을 반투명 판으로 화면을 덮어 만들지 않는다. 성물함에서 창은 **물려 있는 것**이고,
## 물린 것은 테가 아니라 **턱**으로 잡힌다. 그래서 창 위쪽에만 금 턱이 드리운다.
func _draw_pane() -> void:
	var pressed := _since_press >= 0.0 and _since_press < INVERT_FOR
	draw_rect(PANE, LAPIS)
	# 물린 턱의 그늘. 창이 금 **아래**에 있다는 표시다.
	var lip := PANE
	lip.size.y = 14.0
	draw_rect(lip, Color(0.0, 0.0, 0.0, 0.45))
	var inner := PANE.position + Vector2(30.0, 44.0)

	_glyphs("귀환 여부", inner, 27, IVORY if not pressed else LAPIS)
	if pressed:
		# 눌림 = 반전. 4판에서 살린 것이고, 여기서도 두 층에서 같은 뜻이다 —
		# 금세공에서는 빛이 뒤집힌 것이고 화면에서는 그 구역이 갱신된 것이다.
		var bar := Rect2(inner - Vector2(8.0, 26.0), Vector2(PANE.size.x - 44.0, 36.0))
		draw_rect(bar, IVORY)
		_glyphs("귀환 여부", inner, 27, LAPIS)
	draw_line(
		Vector2(inner.x, inner.y + 16.0),
		Vector2(PANE.end.x - 30.0, inner.y + 16.0),
		Color(GOLD.r, GOLD.g, GOLD.b, 0.75),
		1.0
	)

	var lines := [
		"이 방을 지나면 되돌아올 길이 닫힌다.",
		"스쿼드 넷 중 둘이 부상으로 기록되어 있다.",
	]
	for i in range(lines.size()):
		_glyphs(lines[i], Vector2(inner.x, inner.y + 52.0 + float(i) * 26.0), 16, IVORY)

	# 계측 — 목숨 걸린 숫자다. **화면에서 가장 작다.** 그 비례가 이 게임이다.
	var rows := [["인접 위험도 합", "14"], ["직전 턴 대비", "+2"], ["도달 가능 방", "3"]]
	for i in range(rows.size()):
		var y := inner.y + 124.0 + float(i) * 24.0
		var row_lit := _row_refresh(i)
		_glyphs(rows[i][0] as String, Vector2(inner.x, y), 14, LAPIS_LIT.lerp(IVORY, row_lit))
		var value := rows[i][1] as String
		var value_x := PANE.end.x - 30.0 - _width_of(value, 18)
		_glyphs(value, Vector2(value_x, y + 2.0), 18, IVORY.lerp(VERMILION, row_lit * 0.5))
		draw_line(
			Vector2(inner.x, y + 6.0),
			Vector2(PANE.end.x - 30.0, y + 6.0),
			Color(LAPIS_LIT.r, LAPIS_LIT.g, LAPIS_LIT.b, 0.22),
			1.0
		)

	# **「들어간다」는 창에 없다.** 그것은 방사의 중심에 물린 보석이다 (§20.6.2).
	#
	# 들어가는 쪽은 금이고 물러나는 쪽은 창 안의 판이다. 그 비대칭이 이 세계다 —
	# 제 발로 들어가는 선택만 화려하게 차려져 있다.
	_plate_button("물러난다", Vector2(inner.x, PANE.end.y - 58.0), true)
	_plate_button("기록 열람", Vector2(inner.x + 196.0, PANE.end.y - 58.0), false)


## 줄 하나가 갱신되는 순간. **한 줄씩 차례로** 밝아지고 잦아든다.
##
## 주사선을 화면에 긋지 않는다(배격 목록 — 「미래 기기」의 기본값이다).
## 갱신은 **줄 단위**로 일어나고, 그건 실제 전자 표시기가 하는 일이다.
func _row_refresh(index: int) -> float:
	var period := 2.4
	var mine := fposmod(_clock - float(index) * 0.28, period)
	if mine > 0.22:
		return 0.0
	return exp(-mine * 14.0)


## 판 버튼 — 금박 조각. **눌림은 반전이다.**
func _plate_button(label: String, at: Vector2, primary: bool) -> void:
	var box := Rect2(at, Vector2(_width_of(label, 18) + 44.0, 38.0))
	var pressed := _since_press >= 0.0 and _since_press < INVERT_FOR and primary
	if primary:
		# **금박 텍스처를 판으로 쓰면 글자가 안 읽혔다** — 무늬가 글자와 같은 대비폭에
		# 있어서 서로를 먹는다. 판은 단색 금으로 깔고, 세공은 **테두리에만** 둔다.
		draw_rect(box, LAPIS if pressed else GOLD)
		if _gild != null and not pressed:
			var trim := box
			trim.size.y = 5.0
			draw_texture_rect(_gild, trim, false, Color(0.72, 0.58, 0.40))
			trim.position.y = box.end.y - 5.0
			draw_texture_rect(_gild, trim, false, Color(0.42, 0.32, 0.20))
		_glyphs(label, at + Vector2(22.0, 26.0), 18, IVORY if pressed else Color(0.13, 0.09, 0.04))
	else:
		# 부차 버튼은 금을 안 쓴다. **금이 흔해지면 버튼이 안 갈린다.**
		draw_line(
			Vector2(box.position.x, box.end.y),
			Vector2(box.end.x, box.end.y),
			Color(GOLD.r, GOLD.g, GOLD.b, 0.8),
			2.0
		)
		_glyphs(label, at + Vector2(22.0, 26.0), 18, IVORY)


## 진사 비단 한 줄 — **격자를 지키지 않는 유일한 것.**
##
## 그놈들의 중계다. 기울어 있고 판을 넘어가고 화면 밖에서 들어와 화면 밖으로 나간다.
## 격식 있는 그릇에 저질 내용이 끼어드는 것이 이 세계가 사람의 죽음을 다루는 방식이고,
## 그 어긋남을 숨기지 않고 화면의 사건으로 쓴다.
func _draw_silk() -> void:
	var drift := fposmod(_clock * 26.0, 240.0)
	var at := Vector2(-118.0 + drift * 0.5, size.y * 0.735)
	var band := Rect2(Vector2.ZERO, Vector2(880.0, 58.0))
	draw_set_transform(at, -0.052, Vector2.ONE)
	if _silk != null:
		draw_texture_rect(_silk, band, false, Color(1.0, 0.97, 0.95))
	else:
		draw_rect(band, VERMILION)
	var line := "ㅋㅋㅋ 두 명 남았단다 여기서 접으면 개꿀잼인데"
	# **금실 자수 위에 바로 얹으니 글자가 먹혔다.** 자수와 글자가 같은 대비폭에 있다.
	# 비단 위에 심연 한 겹을 깔고 그 위에 쓴다 — 문장학 규칙이 여기서도 그대로 쓰인다.
	var width := _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	draw_rect(Rect2(146.0, 14.0, width + 28.0, 30.0), Color(0.05, 0.03, 0.03, 0.80))
	draw_line(Vector2(146.0, 44.0), Vector2(174.0 + width, 44.0), VERMILION, 2.0)
	draw_string(_font, Vector2(160.0, 36.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, IVORY)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 방사의 중심 — 물린 보석. **화면에서 가장 작고 가장 정밀한 것이고, 이것이 버튼이다.**
##
## 광선 스물넷이 여기로 모이므로 시선이 저절로 온다. 방사가 곧 시선 유도이고,
## 그래서 이 층이 장식이 아니라 기능이다 (§20.6.4).
func _draw_boss(hub: Vector2) -> void:
	var reach := _radiance.press_reach(_since_press)
	var span := 176.0 * (1.0 + (1.0 - reach) * 0.55)
	var box := Rect2(hub - Vector2(span, span) * 0.5, Vector2(span, span))
	# 보석 뒤의 심연. 금과 청금석이 맞닿지 않게 가른다.
	#
	# **한 겹으로 그리면 검은 원판이 뚫린 것처럼 보였다.** 세 겹으로 번지게 한다.
	for step in range(3):
		var radius := span * (0.50 + 0.055 * float(step))
		draw_circle(hub, radius, Color(VOID.r, VOID.g, VOID.b, 0.92 - 0.28 * float(step)))
	if _stones != null:
		draw_texture_rect(_stones, box, false, Color(1.0, 0.98, 0.96))
	else:
		draw_circle(hub, span * 0.44, GOLD)
	# **광선 위에 바로 얹으니 잘리고 먹혔다.** 심연 한 겹을 깔고 보석 왼쪽에 세운다.
	var label := "들어간다"
	var label_w := _width_of(label, 21)
	var seat := Vector2(hub.x - span * 0.5 - label_w - 46.0, hub.y - 19.0)
	draw_rect(Rect2(seat, Vector2(label_w + 26.0, 38.0)), Color(0.05, 0.03, 0.03, 0.88))
	_glyphs(label, seat + Vector2(13.0, 26.0), 21, GOLD)
	# 보석에서 라벨로 이어지는 금 실선 한 줄. 둘이 한 조작이라는 표시다.
	draw_line(
		seat + Vector2(label_w + 26.0, 19.0),
		hub - Vector2(span * 0.46, 0.0),
		Color(GOLD.r, GOLD.g, GOLD.b, 0.85),
		2.0
	)


## 견본 안내. 캡처할 때는 꺼진다.
##
## **가운뎃점(U+00B7)도 한자도 화면에 쓰지 않는다.** 폰트(SongMyung 하나)에 없어서
## 웹 빌드에서 두부(□)가 된다 — 데스크톱에서는 대체 글꼴이 가려 주므로 눈으로는
## 안 보인다. **글리프 검사가 「顯示」를 실제로 잡았다.** 한자는 문서와 주석에만 둔다.
func _draw_legend() -> void:
	if not _legend_shown:
		return
	var at := Vector2(30.0, size.y - 22.0)
	_glyphs(
		"현시 - 금이 방사하고 창이 하나다      Space 눌림 / R 개시 / S 정지",
		at,
		13,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.42)
	)


## 글자를 한 자씩 앉힌다. 자간을 조금 벌린다 — 금 위의 글자는 붙으면 안 읽힌다.
func _glyphs(text: String, at: Vector2, font_size: int, color: Color) -> void:
	var x := at.x
	for i in range(text.length()):
		var glyph := text.substr(i, 1)
		draw_string(_font, Vector2(x, at.y), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		x += _font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 1.2


func _width_of(text: String, font_size: int) -> float:
	var total := 0.0
	for i in range(text.length()):
		var glyph := text.substr(i, 1)
		total += _font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 1.2
	return total


## 안내를 끄면 판정용 그림이 된다.
func set_guide_visible(shown: bool) -> void:
	_legend_shown = shown
	queue_redraw()
