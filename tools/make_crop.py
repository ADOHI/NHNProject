"""정지 컷에서 **부품 하나만 크게** 잘라 낸다.

    python tools/make_crop.py .renders/62-clear_bazaar.png .renders/62-clear_crisp.png 20,586,650,700 2

전체 화면으로는 **맑은지 안 맑은지가 안 보인다.** 660px 짜리 화면에서 부품 하나는
600×60 이고, 그 안에서 찢김 1px 과 알갱이 한 알은 화면을 통째로 볼 때 눈에 안 든다.
「덜 시끄럽다」와 「맑다」가 갈리는 자리가 바로 거기라(§20.47) 부품을 원래 크기의
몇 배로 놓고 봐야 판정이 된다.

**늘리기는 최근접(`NEAREST`)이다.** 부드럽게 늘리면 보간이 가장자리를 만들어 줘서
없던 매끄러움이 생기고, 그러면 이 그림이 재려던 것을 이 그림이 지운다.
"""

import sys

from PIL import Image


def main() -> int:
    if len(sys.argv) < 4:
        print("usage: make_crop.py <읽을 png> <내보낼 png> <x,y,x2,y2> [배율]")
        return 2
    source, target, span = sys.argv[1], sys.argv[2], sys.argv[3]
    times = int(sys.argv[4]) if len(sys.argv) > 4 else 2
    box = tuple(int(part) for part in span.split(","))
    if len(box) != 4:
        print("네모는 x,y,x2,y2 넷이다: %s" % span)
        return 2
    cut = Image.open(source).convert("RGB").crop(box)
    big = cut.resize((cut.width * times, cut.height * times), Image.NEAREST)
    big.save(target)
    print("%s  %dx%d  (%d배)" % (target, big.width, big.height, times))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
