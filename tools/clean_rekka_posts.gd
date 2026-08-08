extends SceneTree
## 모델이 뱉은 게시글에 `RekkaPost` 를 걸어 표본 파일을 만든다.
##
##     godot --headless --path . -s res://tools/clean_rekka_posts.gd
##
## 들어오는 것은 `user://rekka_raw.json` 이고 나가는 것은
## `docs/design/samples/rekka/posts-final.txt` 다.
##
## ## 왜 파이썬이 아니라 여기서 거는가
##
## 후처리는 **게임에 들어갈 코드**다. 표본을 파이썬으로 다듬으면 표본은 깨끗해지고
## 게임이 실제로 그렇게 다듬는지는 검증되지 않는다. 5차 표본이 그랬다
## (docs/design/19-rekka-voice.md §19.A.7 — "지금은 실험 스크립트에만 있다").
## 그래서 표본은 `RekkaPost.clean()` 을 그대로 통과한 것만 싣는다.

const IN_PATH := "user://rekka_raw.json"
const OUT_PATH := "res://docs/design/samples/rekka/posts-final.txt"


func _initialize() -> void:
	var file := FileAccess.open(IN_PATH, FileAccess.READ)
	if file == null:
		print("입력이 없습니다: %s" % IN_PATH)
		quit(1)
		return
	var posts: Array = JSON.parse_string(file.get_as_text())
	file.close()

	var lines: Array[String] = [
		"렉카 게시글 표본 (15차 확정 형식). gpt-5.6-luna 실제 호출 산출.",
		"입력은 tools/dump_rekka_prompts.gd, 후처리는 RekkaPost.clean() 을 그대로 통과했다.",
		"사람이 손댄 곳은 없다.",
	]
	var handle_cursor := 0
	for index in posts.size():
		var post: Dictionary = posts[index]
		var raw: String = post["raw"]
		var rooms: Array[String] = []
		for name in post.get("rooms", []):
			rooms.append(str(name))
		var seed_value := int(post["seed"])
		var cleaned := RekkaPost.clean(raw, index, handle_cursor, rooms, seed_value)
		# 배정은 원래 닉과 일대일이므로 다듬은 뒤에 세어도 수가 같다.
		handle_cursor += RekkaPost.distinct_handle_count(cleaned)
		lines.append("")
		lines.append("---- %d. 시드 %d 턴 %d ----" % [index + 1, seed_value, int(post["turn"])])
		lines.append(cleaned)

	var out := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	out.store_string("\n".join(lines) + "\n")
	out.close()
	print("%d편 -> %s" % [posts.size(), OUT_PATH])
	quit(0)
