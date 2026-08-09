#!/usr/bin/env python
"""방의 **광원 자리와 깊이 배율**을 방 시각화 레인의 코드로 계산해 받아 온다.

    python tools/pull_room_lights.py <room-studio 루트> <방 폴더> [출력.json]

예:

    python tools/pull_room_lights.py C:/Users/adohi/2dAnim/room-studio ^
        C:/Users/adohi/2dAnim/room-studio/out/the_sunken_keep/gallery_of_the_warden ^
        .renders-lighting/room/gallery_of_the_warden.lights.json

# 이 파일은 **임시다. 지워지는 조건이 정해져 있다**

엔진이 알아야 하는 값 셋이 매니페스트에 **없다** (2026-08-09 확인):

| 없는 것 | 어디에 있나 | 엔진이 왜 필요한가 |
| --- | --- | --- |
| 불꽃 자리 (램프의 화면 좌표) | `stage.emitter_report()` 가 계산하고 **버린다** | 그 자리에 실시간 빛을 **안 켜기 위해**. 그리고 대원 빛의 색을 맞추려고 |
| `sun.strength` | `recipe.json` 에 있는데 매니페스트가 `dx·dy·length` 만 싣는다 | 「이 방에 해가 없다」가 엔진에 전달되는 유일한 값이다 |
| `depth_scale` | `recipe.json` 에만 있다 | 이게 없으면 소품의 **화면 크기를 못 구한다.** 가림 폴리곤을 놓을 자리가 안 나온다 |

**그러므로 이 스크립트가 하는 일은 「값을 옮겨 적는 것」이 아니라 「저쪽 코드를 불러서
계산시키는 것」이다.** 사람이 좌표를 타이핑하는 순간 그 값은 두 벌이 되고, 방 시각화
레인이 이미 그 사고를 겪었다 (빛 좌표가 세 곳에 있었고 벽의 최대 밝기가 램프와
77~95px 어긋났다 — `room-studio/docs/LIGHTING.md`).

**매니페스트가 이 셋을 실으면 이 파일을 지운다.** 그때까지만 산다.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    studio = Path(argv[1]).resolve()
    room_dir = Path(argv[2]).resolve()
    out_path = Path(argv[3]) if len(argv) > 3 else None

    sys.path.insert(0, str(studio / "src"))
    from room_studio.build import build, load_recipe  # noqa: PLC0415
    from room_studio.dungeon import Dungeon  # noqa: PLC0415

    dungeon_json = _find_dungeon(room_dir)
    dungeon = Dungeon.load(dungeon_json) if dungeon_json else None
    recipe, root = load_recipe(room_dir / "recipe.json")
    stage = build(recipe, root, dungeon=dungeon)

    emitters = []
    for emitter, (name, x, y, reach, strength) in zip(stage.emitters, stage.emitter_report()):
        emitters.append(
            {
                "prop": name,
                "screen": [round(x, 2), round(y, 2)],
                "reach_px": round(reach, 2),
                "strength": strength,
                "color": list(emitter.color),
                "pool": emitter.pool,
            }
        )

    data = {
        "room_id": recipe["room_id"],
        "source": "room-studio stage.emitter_report() — 사람이 적은 값이 아니다",
        "screen": list(stage.screen),
        "world_w": stage.world_w,
        "depth_scale": float(recipe.get("depth_scale", 0.0)),
        "sun": {
            "dx": stage.sun.dx,
            "dy": stage.sun.dy,
            "length": stage.sun.length,
            "strength": stage.sun.strength,
        },
        "emitters": emitters,
    }

    text = json.dumps(data, ensure_ascii=False, indent=2)
    if out_path is None:
        print(text)
        return 0
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(text, encoding="utf-8")
    print(f"적었다: {out_path}  (광원 {len(emitters)}개)")
    for e in emitters:
        print(f"  {e['prop']}: {e['screen']}  reach={e['reach_px']}px  strength={e['strength']}")
    return 0


def _find_dungeon(room_dir: Path) -> Path | None:
    for candidate in (
        room_dir / "dungeon.json",
        room_dir.parent / "dungeon.json",
        room_dir.parent.parent / "dungeon.json",
    ):
        if candidate.exists():
            return candidate
    return None


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
