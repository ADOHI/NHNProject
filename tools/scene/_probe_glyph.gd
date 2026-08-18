extends SceneTree


func _initialize() -> void:
	var font: Font = load("res://assets/fonts/song_myung/SongMyung-Regular.ttf")
	var rids := font.get_rids()
	print("rids: ", rids.size())
	var rid: RID = rids[0]
	var index := TextServerManager.get_primary_interface().font_get_glyph_index(
		rid, 48, "참".unicode_at(0), 0
	)
	print("glyph index: ", index)
	var got := TextServerManager.get_primary_interface().font_get_glyph_contours(rid, 48, index)
	print("keys: ", got.keys())
	if got.has("points"):
		var pts: PackedVector3Array = got["points"]
		print("points: ", pts.size(), " first5: ", Array(pts).slice(0, 5))
		print("contours: ", got["contours"])
		print("orientation: ", got.get("orientation"))
	quit(0)
