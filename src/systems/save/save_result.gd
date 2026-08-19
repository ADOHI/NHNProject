class_name SaveResult
extends RefCounted
## 불러오기의 결과와 **그 사유.**
##
## 못 읽었을 때 조용히 새 게임으로 넘어가면, 사용자는 자기 진행이 왜 사라졌는지
## 영영 모른다. 그래서 결과에는 언제나 **사람이 읽을 한 줄**이 붙는다
## (docs/design/34-systems.md §34.4.4).

## 어떻게 끝났나.
enum Status {
	OK,  ## 읽었다
	MISSING,  ## 파일이 없다. 첫 판이면 정상이다
	UNREADABLE,  ## 파일은 있는데 열리지 않는다 (권한 • 잠김)
	NOT_JSON,  ## 열었는데 JSON 이 아니다
	BAD_SHAPE,  ## JSON 은 맞는데 세이브의 모양이 아니다
	VERSION_AHEAD,  ## 더 새 빌드가 쓴 파일이다
}

const _MESSAGES: Array[String] = [
	"불러왔다",
	"저장된 진행이 없다 — 새로 시작한다",
	"저장 파일을 열지 못했다 — 새로 시작한다",
	"저장 파일이 깨졌다 (JSON 이 아니다) — 새로 시작한다",
	"저장 파일의 내용이 세이브가 아니다 — 새로 시작한다",
	"더 새 빌드가 쓴 저장 파일이다 — 새로 시작한다",
]

var status: Status = Status.MISSING

## 읽어 낸 길드. 실패면 null 이다.
var guild: Guild = null

## 씨앗에서 다시 세운 세계. 안 세웠으면 null 이다.
var world: NpcWorld = null

## 이 판의 씨앗. 세계와 게이트 목록이 이 값에서 나온다.
var campaign_seed: int = 0

## 화면에 그대로 나가는 한 줄. 사유에 덧붙일 것이 있으면 여기 붙는다.
var note: String = ""


static func ok(loaded: Guild, seed_value: int, npc_world: NpcWorld = null) -> SaveResult:
	var result := SaveResult.new()
	result.status = Status.OK
	result.guild = loaded
	result.campaign_seed = seed_value
	result.world = npc_world
	return result


## 실패 하나. `detail` 은 사유 뒤에 괄호로 붙는다 — 무엇이 어떻게 깨졌는지가
## 사유만으로는 안 나오는 경우가 있다.
static func failed(status_value: Status, detail: String = "") -> SaveResult:
	var result := SaveResult.new()
	result.status = status_value
	result.note = detail
	return result


func is_ok() -> bool:
	return status == Status.OK


## 화면에 띄울 한 줄.
func message() -> String:
	var line: String = _MESSAGES[clampi(int(status), 0, _MESSAGES.size() - 1)]
	return line if note.is_empty() else "%s (%s)" % [line, note]
