class_name RekkaFeed
extends RefCounted
## 판 한 판의 피드. **편끼리 이어져야 하는 것들을 여기서 센다.**
##
## ## 왜 상태가 필요한가
##
## 모델은 턴마다 새로 불려서 자기가 방금 뭘 썼는지 모른다 —
## 이 저장소에서는 모델이 없으니 자산과 예비 문안이 그 자리에 있고, 사정은 같다.
## **한 편만 보면 안 보이고 스무 편째에 보이는 결함**을 막으려면 누군가 세어야 한다
## (docs/design/19-rekka-voice.md §19.B.4).
##
## | 이어 세는 것 | 안 세면 |
## | --- | --- |
## | 몇 번째 편인가 | 접두어와 문안 고르기가 매 편 같은 자리에서 시작한다 |
## | 지금까지 쓴 댓글 수 | 편끼리 닉이 겹친다. 실측 닉 139개 중 서로 다른 것 113개 |
## | 소금(시드) | 판이 바뀌어도 같은 배열이 돈다 |
##
## ## 화면을 모른다
##
## 이 클래스는 `Node` 도 화면도 모른다 (개발 원칙 2). 화면은 `post_added` 를 듣고
## 자기 자리에 붙이기만 한다. 그래서 같은 피드를 인게임과 주둔지가 함께 쓴다
## (08-ui-ux.md §8.3.4.1).

## 한 편이 붙었다. 화면이 여기에 붙는다.
signal post_added(entry: RekkaFeedEntry)

## 판의 모든 편. 앞이 오래된 것이다. **화면이 뒤집어 보여 준다** (§8.2 — 최신이 위).
var entries: Array[RekkaFeedEntry] = []

## 접두어와 문안 고르기를 판마다 다시 섞는 값. 판의 시드를 그대로 쓴다.
var salt: int = 0

var _library: RekkaLibrary = null
var _handle_cursor := 0


func _init(feed_salt: int = 0, library: RekkaLibrary = null) -> void:
	salt = feed_salt
	_library = library if library != null else RekkaLibrary.shared()


## 이번 턴을 한 편으로 만든다. **사건이 없어도 편은 나온다.**
##
## 조용한 턴에 기사를 거르면 플레이어는 "아무 일도 없었다" 는 정보를 못 얻는다.
## 부재도 정보다 — `RekkaContext` 가 그 턴에 넘길 것을 따로 갖고 있다 (§19.B.1).
func record_turn(run: DungeonRun, events: Array[GameEvent]) -> RekkaFeedEntry:
	if run == null:
		return null
	var facts := RekkaContext.for_turn(run, events)
	var names := RekkaContext.name_index(run)
	var rooms := room_names_of(run)
	var room_names: Array[String] = []
	for name in rooms:
		room_names.append(str(name))
	var text := RekkaWriter.write(
		events, facts, names, room_names, entries.size(), _handle_cursor, salt, _library
	)
	var entry := RekkaFeedEntry.new(
		_turn_of(run, events), text, RekkaFeedEntry.rooms_in(text, rooms)
	)
	_handle_cursor += RekkaPost.distinct_handle_count(text)
	entries.append(entry)
	post_added.emit(entry)
	return entry


## 최신 편이 앞에 오도록 뒤집은 목록. 화면이 읽는 순서다.
func newest_first() -> Array[RekkaFeedEntry]:
	var found: Array[RekkaFeedEntry] = []
	for i in range(entries.size() - 1, -1, -1):
		found.append(entries[i])
	return found


func latest() -> RekkaFeedEntry:
	return entries[entries.size() - 1] if not entries.is_empty() else null


func count() -> int:
	return entries.size()


func clear() -> void:
	entries.clear()
	_handle_cursor = 0


## 판이 들고 있는 방 이름들. 표시명 -> 방 id.
##
## 두 곳에서 쓴다 — 후처리가 띄어쓰기를 판의 표기로 되돌릴 때(§19.B.9 2차),
## 그리고 글에서 누를 수 있는 방을 고를 때(§13.7).
static func room_names_of(run: DungeonRun) -> Dictionary:
	var found: Dictionary = {}
	if run == null or run.graph == null:
		return found
	for room_id in run.graph.room_ids():
		var room := run.graph.get_room(room_id)
		if room != null and not room.display_name.is_empty():
			found[room.display_name] = room_id
	return found


## 이 편이 몇 번째 턴의 것인가.
##
## **사건의 턴을 쓴다.** `DungeonRun.turn` 은 이동이 끝나면 이미 다음 턴을 가리키므로
## 그것을 쓰면 편의 번호가 하나씩 밀린다.
static func _turn_of(run: DungeonRun, events: Array[GameEvent]) -> int:
	for event in events:
		return event.turn
	return run.turn
