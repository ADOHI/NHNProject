class_name CharScreenFxLayer
extends Node2D
## **화면 연출을 그리는 층.** 계산은 `CharScreenFx` 가 하고 여기는 칠하기만 한다.
##
## `docs/design/25-character-animation.md` §25.28.
##
## 캐릭터가 무엇을 하든 상관이 없어서 **때리는 쪽에도 맞는 쪽에도** 똑같이 걸린다.
##
## ## 두 층인 이유
##
## **속도선은 캐릭터 뒤, 임팩트 프레임은 앞이다.**
##
## 처음에 한 층으로 앞에만 뒀더니 배경을 덮는 칠이 **캐릭터까지 덮어** 과한 눈금에서
## 얼굴이 사라졌다. 배경만 어두워지고 캐릭터는 그대로여야 **캐릭터가 더 밝게 뜬다** —
## 그것이 이 장치가 노리는 것이다.

## 배경을 덮을 때 쓰는 색. 어두운 쪽이라 선이 밝게 뜬다.
const WIPE := Color(0.05, 0.06, 0.09)
const LINE := Color(0.95, 0.97, 1.0)
const FLASH := Color(1.0, 1.0, 1.0)
## 흑백 반전을 근사한다. **진짜 반전은 셰이더라 웹에서 비싸고**, 겹쳐 칠하면 거의 같다.
const INVERT := Color(0.02, 0.02, 0.05)

var fx := CharScreenFx.new()

## `true` 면 임팩트 프레임(앞), `false` 면 속도선(뒤).
var foreground := false

var _size := Vector2(720.0, 720.0)
var _focus := Vector2.ZERO
var _heading := Vector2.LEFT
var _strength := 0.0
var _flash := 0.0
var _inverted := false


func setup(size: Vector2, p_foreground: bool) -> void:
	_size = size
	foreground = p_foreground
	# **음수를 주면 안 된다.** 자식의 음수 `z_index` 는 **부모가 그린 배경보다도 뒤로** 가서
	# 아무것도 안 보인다 — 실제로 그렇게 했다가 선이 통째로 사라졌다.
	# `0` 이면 부모의 배경 위, 캐릭터(`10`) 아래다.
	z_index = 100 if p_foreground else 0


## 이 순간의 화면 연출을 정한다. **시각을 넣으면 그림이 정해진다** — 누적이 없다.
func show_at(at: float, impact_at: float, focus: Vector2, heading: Vector2) -> void:
	_focus = focus
	_heading = heading
	_strength = fx.line_strength(at, impact_at)
	_flash = fx.flash_alpha(at, impact_at)
	_inverted = fx.is_inverted(at, impact_at)
	queue_redraw()


func _draw() -> void:
	if foreground:
		_draw_impact_frame()
	else:
		_draw_speed_lines()


## **배경이 사라지고 선만 남는 것** — 일본 격투 애니메이션의 가장 강한 장치다.
func _draw_speed_lines() -> void:
	if _strength <= 0.001:
		return
	var wipe := fx.wipe_amount(_strength)
	if wipe > 0.001:
		draw_rect(Rect2(Vector2.ZERO, _size), Color(WIPE, wipe))
	var ink := fx.line_alpha(_strength)
	if ink <= 0.001:
		return
	for pair in fx.line_field(_size, _focus, _heading, _strength):
		draw_line(pair[0], pair[1], Color(LINE, ink), 2.0)


## **1~2 프레임 완전 백색 또는 흑백 반전.** 화면 전체다.
func _draw_impact_frame() -> void:
	if _flash > 0.001:
		draw_rect(Rect2(Vector2.ZERO, _size), Color(FLASH, _flash))
	elif _inverted:
		draw_rect(Rect2(Vector2.ZERO, _size), Color(INVERT, 0.88))
