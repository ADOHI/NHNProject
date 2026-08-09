extends SceneTree
## 건물 그림 규격을 **코어에서 뽑아** 파일로 낸다. 발주서와 밑그림이 이것을 읽는다.
##
##     godot --headless --path . -s res://tools/dump_hideout_art_spec.gd
##
## ## 왜 손으로 안 적는가
##
## 규격을 문서에 손으로 적으면 코드와 갈린다. 그리고 **갈린 것은 그림이 도착한 날에야
## 드러난다** — 그때는 이미 다 뽑은 뒤다.
##
## 그래서 숫자의 출처는 `HideoutBuildingArt` 하나이고, 발주서도 밑그림도 여기서 나온
## `hideout-building-art.json` 만 읽는다. 레이맨 파츠 레인의 `parts.json` 과 같은 형태다.

const _OUT := "res://docs/design/hideout-building-art.json"


func _initialize() -> void:
	var spec := {
		"note": "생성물이다. 손으로 고치지 마라 — tools/dump_hideout_art_spec.gd 가 만든다.",
		"view": _view_spec(),
		"rules": _rules(),
		"buildings": _buildings(),
	}
	var file := FileAccess.open(_OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(spec, "  ") + "\n")
	file.close()
	print("[spec] %s" % _OUT)
	for entry in spec["buildings"]:
		print(
			(
				"[spec] %-8s 발자국 %s  캔버스 %s  기준점 %s  뒤 %d칸 가림"
				% [
					entry["label"],
					entry["footprint"],
					entry["canvas"],
					entry["pivot"],
					entry["hides_cells_behind"],
				]
			)
		)
	quit()


func _view_spec() -> Dictionary:
	var iso := IsoProjection.new()
	return {
		"projection": "쿼터뷰 3:1",
		"tile_width_px": iso.tile_width(),
		"tile_height_px": iso.tile_height(),
		"pitch_degrees": snappedf(rad_to_deg(asin(iso.tile_height() / iso.tile_width())), 0.01),
		"cell_height_px": IsoProjection.CELL_HEIGHT_PX,
	}


func _rules() -> Dictionary:
	return {
		"pivot": "바닥 마름모의 아래꼭짓점. 캔버스 왼쪽 위에서 잰다",
		"pivot_reason": "그림이 위로 자라도 땅에 닿는 자리가 안 움직여야 한다",
		"storey_height_px": IsoProjection.CELL_HEIGHT_PX * HideoutBuildingArt.STOREY_CELLS,
		"max_storeys": HideoutBuildingArt.MAX_STOREYS,
		"margin_px": HideoutBuildingArt.MARGIN_PX,
		"occlusion": "N 층은 바로 뒤 2N 칸을 완전히 가린다",
		"door_face": "남서쪽 벽(화면에서 왼쪽 아래를 보는 면) 한 곳뿐",
		"door_reason": "카메라도 건물도 돌지 않는다. 네 방향을 그릴 이유가 없다",
		"style": "미정 — 아지트 화풍이 정해지면 여기에 문장이 들어간다",
	}


func _buildings() -> Array:
	var rows := []
	for kind in Facility.all():
		var footprint := HideoutBuilding.footprint_for(kind)
		for storeys in range(1, HideoutBuildingArt.MAX_STOREYS + 1):
			rows.append(_row(kind, footprint, storeys))
	return rows


func _row(kind: int, footprint: Vector2i, storeys: int) -> Dictionary:
	var canvas := HideoutBuildingArt.canvas_size(footprint, storeys)
	var anchor := HideoutBuildingArt.pivot(footprint, storeys)
	var ground := HideoutBuildingArt.ground_size(footprint)
	var polygon := []
	for point in HideoutBuildingArt.ground_polygon(footprint, storeys):
		polygon.append([point.x, point.y])
	return {
		"facility": kind,
		"label": Facility.label(kind),
		"storeys": storeys,
		"footprint": [footprint.x, footprint.y],
		"canvas": [canvas.x, canvas.y],
		"pivot": [anchor.x, anchor.y],
		"ground_size": [ground.x, ground.y],
		"ground_polygon_north_east_south_west": polygon,
		"hides_cells_behind": HideoutBuildingArt.hidden_cells_behind(storeys),
		"file": "%s_%dl.png" % [_slug(kind), storeys],
	}


## 파일 이름에 쓸 영문 이름. 한글 파일명은 도구마다 인코딩이 갈린다.
func _slug(kind: int) -> String:
	match kind:
		Facility.Kind.WORKSHOP:
			return "workshop"
		Facility.Kind.INTEL_ROOM:
			return "intel_room"
		Facility.Kind.CONTACT_POINT:
			return "contact_point"
		_:
			return "building"
