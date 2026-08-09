extends SceneTree
## **사건 50개 중 실제로 소리가 나는 것은 몇 개인가** (docs/design/29-sound.md §29.3.10).
##
## 물음이 셋이고 서로 다르다.
##
## 1. **소리가 붙어 있나** — 표(`SfxCatalog`)와 미리 섞은 표(`SfxAtlas`)에 있나
## 2. **누가 부르나** — `Sfx.play(...)` 호출부가 코드에 있나
## 3. **없는 것이 결정인가 빠뜨린 것인가** — 이 둘이 지금 구별이 안 된다
##
## **2번이 0이어도 1번은 100 % 일 수 있다.** 그 상태가 지금이다 — 소리는 다 만들어 뒀고
## 부르는 쪽은 다른 브랜치에 있어서 아직 안 꽂혔다. 그걸 **세어서** 보여 준다.
##
##     godot --headless --path . -s res://tools/audit_sfx_events.gd

const SCAN_DIRS := ["res://src"]

## 소리 층 자신은 세지 않는다.
##
## **문서 주석의 사용 예시가 호출부로 잡혔다** — `sfx_player.gd` 의 클래스 설명에
## `Sfx.play(SfxEvent.Kind.HIT_LANDED, weapon.cells)` 라고 적어 둔 것이 그대로 걸렸다.
## 여기서 세려는 것은 **바깥 코드가 소리 층을 부르는가** 이므로 층 자신은 빼야 한다.
const SKIP_DIRS := ["res://src/core/sfx", "res://src/systems/audio", "res://src/proto/sfx"]

## 소리를 **일부러 안 다는 쪽이 나을 수 있는** 사건.
##
## **결정이 아니라 제안이다.** 여기 있다고 지금 조용해지지 않는다 —
## 판단은 사용자와 통합자가 한다 (CLAUDE.md 개발 원칙 5).
##
## 기준은 하나다. **한 번의 플레이어 판단에 소리 하나.**
## 유닛이 여럿일 때 프레임마다 나는 것, 플레이어가 시킨 적 없는 내부 상태 변화는
## 소리가 붙으면 정보가 아니라 소음이 된다.
const CHATTY_RISK := {
	SfxEvent.Kind.MOVE_HOLDING: "유닛마다 매 프레임 들락거린다. 플레이어가 시킨 적 없다",
	SfxEvent.Kind.MOVE_RESUMED: "위와 짝. 대기와 재개가 번갈아 나면 떨림으로 들린다",
	SfxEvent.Kind.MOVE_YIELD: "여럿이 비켜설 때 한꺼번에 난다",
	SfxEvent.Kind.MOVE_REPATH: "흐름장 재계산은 내부 사정이다. 플레이어가 알 이유가 없다",
	SfxEvent.Kind.FOOT_SCUFF: "대기 중 4초마다. 조용한 장면에서 거슬린다",
	SfxEvent.Kind.CHAIN_LINK: "체인 12칸이면 12번. 한 번의 발사가 한 번으로 들려야 한다",
}


func _init() -> void:
	var called := _scan_call_sites()

	var with_sound := 0
	var precomputed := 0
	var wired := 0
	var proposed_silent := 0
	var missing: Array[String] = []

	for event in SfxEvent.all():
		var request := SfxCatalog.request_for(event)
		if SfxLibrary.has_material(request) or SfxRender.mode == SfxRender.Source.SYNTH:
			with_sound += 1
		if not SfxAtlas.path_for(request, 0).is_empty():
			precomputed += 1
		if called.has(event):
			wired += 1
		elif not CHATTY_RISK.has(event):
			missing.append(SfxEvent.label(event))
		if CHATTY_RISK.has(event):
			proposed_silent += 1

	var total := SfxEvent.all().size()
	print("")
	print("=== 사건 감사 ===")
	print("사건 전체                    %d" % total)
	print("소리가 붙어 있다              %d  (%.0f %%)" % [with_sound, 100.0 * with_sound / total])
	print("미리 섞은 표에 있다            %d  (%.0f %%)" % [precomputed, 100.0 * precomputed / total])
	print("**부르는 코드가 있다**         %d  (%.0f %%)" % [wired, 100.0 * wired / total])
	print("조용한 편이 나을 수 있다(제안)  %d" % proposed_silent)
	print("")

	if wired == 0:
		print("호출부가 하나도 없다. 예상된 상태다 —")
		print("배치 대상 코드가 combat / char-anim / ui-kit-2 브랜치에 있어")
		print("이 레인이 건드리면 충돌한다. 통합 뒤에 한 줄씩 꽂으면 된다.")
	else:
		print("꽂힌 사건:")
		for event in called:
			print("   %s" % SfxEvent.label(event))

	print("")
	print("--- 조용한 편이 나을 수 있는 것 (제안, 지금은 소리 남) ---")
	for event in CHATTY_RISK:
		print("   %-14s %s" % [SfxEvent.label(event), CHATTY_RISK[event]])

	print("")
	print("--- 아직 안 꽂힌 것 %d개 ---" % missing.size())
	var line := ""
	for name in missing:
		line += name + " "
		if line.length() > 60:
			print("   " + line)
			line = ""
	if not line.is_empty():
		print("   " + line)
	quit()


## `Sfx.play(SfxEvent.Kind.XXX` 를 실제로 부르는 곳을 찾는다.
##
## **문자열로 찾는 것이 맞다.** 코드에 없는 것을 코드로 물어볼 방법이 없고,
## 여기서 세는 것은 "표에 있나" 가 아니라 "누가 부르나" 이기 때문이다.
func _scan_call_sites() -> Array:
	var found: Array = []
	for root in SCAN_DIRS:
		_scan(root, found)
	return found


func _scan(path: String, found: Array) -> void:
	if SKIP_DIRS.has(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for name in dir.get_directories():
		_scan("%s/%s" % [path, name], found)
	for name in dir.get_files():
		if not name.ends_with(".gd"):
			continue
		var file := FileAccess.open("%s/%s" % [path, name], FileAccess.READ)
		if file == null:
			continue
		var text := file.get_as_text()
		file.close()
		if not text.contains("Sfx.play("):
			continue
		for event in SfxEvent.all():
			if found.has(event):
				continue
			var token := "SfxEvent.Kind.%s" % SfxEvent.Kind.keys()[event]
			if text.contains(token) and text.contains("Sfx.play("):
				found.append(event)
