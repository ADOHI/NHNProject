class_name MemberNames
extends RefCounted
## 대원과 영입 후보의 이름을 뽑는다.
##
## 이름을 따로 떼어 둔 이유는 **이름이 이 게임에서 기능이기 때문이다.**
## docs/design/08-ui-ux.md §8.3.2 — NPC 가 이름으로 불리고 행적이 서술되어야
## 화면에 안 나와도 살아 있는 경쟁자가 된다. 영입의 감흥도 거기서 나온다
## (docs/design/14-squad.md §14.5).
##
## 지금은 조합기일 뿐이지만, 나중에 세계 갱신(docs/design/15-world.md)이
## 같은 이름 풀을 써야 하므로 한곳에 둔다.

const _SURNAMES := ["서", "한", "윤", "장", "배", "구", "오", "임", "표", "차", "노", "심"]

const _GIVEN := [
	"지호",
	"나래",
	"현우",
	"세연",
	"도경",
	"유리",
	"태산",
	"민재",
	"소원",
	"강일",
	"하람",
	"영준",
]


## 아직 쓰지 않은 이름을 하나 뽑는다.
##
## used 는 호출자가 들고 있는 이름 집합이다. 중복된 이름이 두 명 있으면
## 기사에서 누구 얘기인지 알 수 없게 되고, 그 순간 이름이 기능을 잃는다.
static func pick(rng: RandomNumberGenerator, used: Dictionary) -> String:
	for _attempt in 32:
		var name := (
			"%s%s"
			% [_SURNAMES[rng.randi() % _SURNAMES.size()], _GIVEN[rng.randi() % _GIVEN.size()]]
		)
		if not used.has(name):
			used[name] = true
			return name
	var fallback := "무명 %d" % (used.size() + 1)
	used[fallback] = true
	return fallback
