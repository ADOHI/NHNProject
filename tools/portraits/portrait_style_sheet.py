#!/usr/bin/env python
"""초상(전신 일러스트)으로 쓸 화풍 한 장을 고르는 대조표 (`docs/design/27-portraits.md`
§27.31 다음 자리 — 「할 일 ①」).

사슬을 끝까지 돌린 결과(§27.31)가 물음을 좁혔다 — **화풍 벌어짐이 SD 변환 뒤에는
거의 사라진다(5.0 대 4.6). 그래서 화풍은 「초상(전신 일러스트)이 어떻게 보이느냐」로만
고르면 된다.** 이 표는 그 결정 한 장을 위한 것이다.

    python tools/portraits/portrait_style_sheet.py

**인물 고정, 화풍만 변수.** 배경을 뗀 뒤 모습으로 놓는다 — 초상은 액자 안에
들어가므로 배경이 성해야 쓸 수 있다. 네 구획이다.

1. **합격** — `cutout.py` 로 배경을 뗀 뒤(§27.30) 남은 얼룩이 1% 미만이고,
   `measure.garment_colour` 로 잰 옷 색이 ③ 슬롯을 지킨 것.
2. **합격 — 재굴림 권장** — `m_lino` · `p_water`. §27.30.2 는 이 둘을 「후처리로도
   안 떨어진다 — 탈락」으로 적었는데 **재현이 안 됐다** — 시드만 바꿔 다시 뽑으니
   3개 중 2개는 멀쩡했다(§27.33). **탈락이 아니라 확률.** 배치에서 나쁜 판이 나오면
   재굴림하면 된다. 표에 쓴 판은 `#2b` 는 재굴림 1(원 시드가 나빴다), `#3` 는 원 시드다.
3. **참고 — 색 지배 (이전 라운드)** — `hairline` · `cel`. §27.25 의 「선·음영·색」
   축 실험에서 나온 것이고, 배경을 열기 전(닫힌 흰 배경) 판이라 위 구획들과
   생성 조건이 다르다. **그래도 탈락 사유는 지금도 유효하다** — 화풍의 색 지정이
   ③ 슬롯의 옷 색을 이긴다(§27.25.6). 옷 색이 다 같아지면 3000명이 안 갈린다.
4. **재현 시험 근거 (§27.33)** — `#2b` 하나로, 같은 프롬프트를 시드만 바꿔 세 번.
   원 시드만 나빴다는 것을 눈으로 보인다.

숫자는 재실행하면 `.captures/portraits/cast6/` 의 실제 판에서 다시 잰다 —
지어내지 않는다(§27.32). **다만 결론은 한 시드에서 못 내린다** —
탈락처럼 보이는 값을 봤으면 재굴림부터 해라(§27.33, `reroll_check.py`).
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import console  # noqa: E402
import measure  # noqa: E402

console.utf8()

CAST6 = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                     "..", "..", ".captures", "portraits", "cast6")
CAST6 = os.path.normpath(CAST6)

CELL_W, CELL_H, PAD = 236, 344, 10
SECTION_HEAD = 30
CAPTION_H = 46
SHEET_BG = (245, 243, 238)
OK_BORDER = (46, 138, 78)
BAD_BORDER = (196, 60, 48)
REF_BORDER = (150, 130, 40)
CAUTION_BORDER = (196, 140, 30)

#: 합격 — cutout 성함 + 색 지킴 (§27.30, §27.27.2, 이 스크립트가 재확인)
PASS = ["p_oil", "p_gouache", "p_digital", "m_charcoal"]
#: 합격 — 재굴림 권장. **탈락이 아니다** — §27.33 이 재현 안 됨을 확인했다.
#: `#2b` 는 원 시드가 나빴던 것으로 알려져 있어 재굴림 1 판을 대신 보여준다.
CAUTION_REROLL = ["m_lino", "p_water"]
#: 참고 — 색 지배, 닫힌 배경 시절 후보 (§27.25.6 · §27.27.2)
REF_COLOUR = ["hairline", "cel"]
#: `(person, style) -> 대신 보여줄 판.` 원 시드가 나빴던 자리만 재굴림 판으로 바꾼다.
DISPLAY_OVERRIDE = {
    ("2b", "m_lino"): os.path.join("reroll_test", "2b_m_lino_open_r1_cut.png"),
    ("2b", "p_water"): os.path.join("reroll_test", "2b_p_water_open_r1_cut.png"),
}

#: cutout 을 거친 구획(1·2)의 인물. `2b` 는 장소 낱말을 뺀 고친 슬롯(§27.25.8)이다.
PEOPLE = ["2b", "3"]
#: 닫힌 배경 시절 참고 구획(3)의 인물. `cel` 은 `2b` 로 다시 안 뽑았다 — **원본 `2` 를 쓴다.**
PEOPLE_AXIS = ["2", "3"]
NEUTRAL, VIVID = "2b", "3"  # 옷 색 판정 — 숯빛/진홍 표본 (measure.garment_colour 주석)
NEUTRAL_AXIS, VIVID_AXIS = "2", "3"


def _font(size: int):
    from PIL import ImageFont
    for path in (r"C:\Windows\Fonts\malgun.ttf", r"C:\Windows\Fonts\arial.ttf"):
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                pass
    return ImageFont.load_default()


def _cut_path(person: str, style: str) -> str:
    override = DISPLAY_OVERRIDE.get((person, style))
    if override:
        return os.path.join(CAST6, override)
    return os.path.join(CAST6, "cut", f"{person}_{style}_open_cut.png")


def _reroll_path(person: str, style: str, tag: str) -> str:
    """`tag` 는 `orig` · `r1` · `r2`. §27.33 재현 시험 근거 구획에서 쓴다."""
    if tag == "orig":
        return os.path.join(CAST6, "cut", f"{person}_{style}_open_cut.png")
    return os.path.join(CAST6, "reroll_test", f"{person}_{style}_open_{tag}_cut.png")


def _axis_style_path(person: str, style: str) -> str:
    """닫힌 배경 시절 축 후보 (`hairline`, `cel` …) — 배경 제거를 거치지 않았다."""
    return os.path.join(CAST6, f"{person}_style_{style}.png")


def _tile(path: str):
    from PIL import Image
    im = Image.open(path).convert("RGB")
    return im.resize((CELL_W, CELL_H), Image.LANCZOS)


def _colour_line(style: str, is_axis: bool) -> tuple[str, str]:
    """(한 줄, 판정). 숯빛은 낮아야 맞고 진홍은 높아야 맞다."""
    neutral, vivid = (NEUTRAL_AXIS, VIVID_AXIS) if is_axis else (NEUTRAL, VIVID)
    a_path = _axis_style_path(neutral, style) if is_axis else _cut_path(neutral, style)
    b_path = _axis_style_path(vivid, style) if is_axis else _cut_path(vivid, style)
    if not (os.path.exists(a_path) and os.path.exists(b_path)):
        return "색 ?", "?"
    _, c_neutral = measure.garment_colour(a_path)
    _, c_vivid = measure.garment_colour(b_path)
    delta = abs(c_neutral - c_vivid) if (c_neutral >= 0 and c_vivid >= 0) else -1
    verdict = measure.colour_verdict(c_neutral, delta)
    return f"숯C*{c_neutral:.0f} 진홍C*{c_vivid:.0f}", verdict


def build(dest: str) -> str:
    from PIL import Image, ImageDraw

    f_title = _font(20)
    f_head = _font(15)
    f_lab = _font(13)
    f_small = _font(11)

    sections: list[tuple[str, str, list[str], bool, tuple]] = [
        ("1. 합격 — 배경 성함 · 색 지킴 (cutout 뒤)", PASS, False, OK_BORDER),
        ("2. 합격 — 재굴림 권장 (원 시드 하나만으로 탈락시키지 않는다, §27.33)",
         CAUTION_REROLL, False, CAUTION_BORDER),
        ("3. 참고 — 색 지배, 닫힌 배경 시절 후보 (§27.25.6, cutout 이전)", REF_COLOUR, True, REF_BORDER),
    ]

    cols = max(len(s[1]) for s in sections)
    n_people_rows = len(PEOPLE)
    row_h = SECTION_HEAD + n_people_rows * (CELL_H + CAPTION_H + PAD) + PAD
    #: 구획 4 — 재현 시험 근거. 3열(원시드/재굴림1/재굴림2) x 2행(m_lino/p_water), `#2b` 하나.
    RR_TAGS = [("orig", "원 시드"), ("r1", "재굴림 1"), ("r2", "재굴림 2")]
    rr_styles = CAUTION_REROLL
    rr_cols = max(cols, len(RR_TAGS))
    rr_row_h = SECTION_HEAD + len(rr_styles) * (CELL_H + CAPTION_H + PAD) + PAD
    w = PAD + max(cols, len(RR_TAGS)) * (CELL_W + PAD)
    h = PAD + 44 + sum(row_h for _ in sections) + rr_row_h

    sheet = Image.new("RGB", (w, h), SHEET_BG)
    dr = ImageDraw.Draw(sheet)
    dr.text((PAD, 8), "초상(전신 일러스트) 화풍 후보 — 인물 고정 · 배경 뗀 뒤 (cast6)",
             font=f_title, fill=(20, 20, 24))

    y = PAD + 44
    for title, styles, is_axis, border in sections:
        dr.text((PAD, y + 6), title, font=f_head, fill=(30, 30, 34))
        y += SECTION_HEAD
        people = PEOPLE_AXIS if is_axis else PEOPLE
        for r, person in enumerate(people):
            for c, style in enumerate(styles):
                x = PAD + c * (CELL_W + PAD)
                cy = y + r * (CELL_H + CAPTION_H + PAD)
                path = _axis_style_path(person, style) if is_axis else _cut_path(person, style)
                if os.path.exists(path):
                    sheet.paste(_tile(path), (x, cy))
                else:
                    dr.rectangle([x, cy, x + CELL_W, cy + CELL_H], outline=(120, 120, 120))
                    dr.text((x + 6, cy + CELL_H // 2), "판 없음", font=f_lab, fill=(120, 120, 120))
                dr.rectangle([x, cy, x + CELL_W, cy + CELL_H], outline=border, width=4)
                cap_y = cy + CELL_H + 2
                dr.text((x + 2, cap_y), f"{style}  #{person}", font=f_lab, fill=(20, 20, 24))
                bg_dirt = "?"
                if os.path.exists(path):
                    d, _ = measure.background_dirt(path)
                    bg_dirt = f"{d:.1f}%"
                dr.text((x + 2, cap_y + 16), f"배경얼룩 {bg_dirt}", font=f_small, fill=(80, 80, 86))
                if r == 0:  # 색 판정은 인물 쌍(#2b 숯빛 / #3 진홍) 기준 — 한 번만 적는다
                    cline, verdict = _colour_line(style, is_axis)
                    dr.text((x + 2, cap_y + 30), f"{cline} → {verdict}",
                             font=f_small, fill=(80, 80, 86))
        y += row_h

    # ── 구획 4 — 재현 시험 근거 (§27.33). `#2b` 하나, 같은 프롬프트를 시드만 흔든다 ──
    dr.text((PAD, y + 6),
             "4. 재현 시험 근거 — #2b, 같은 프롬프트를 시드만 바꿔 세 번 (§27.33)",
             font=f_head, fill=(30, 30, 34))
    y += SECTION_HEAD
    for r, style in enumerate(rr_styles):
        for c, (tag, tag_label) in enumerate(RR_TAGS):
            x = PAD + c * (CELL_W + PAD)
            cy = y + r * (CELL_H + CAPTION_H + PAD)
            path = _reroll_path("2b", style, tag)
            dirt = -1.0
            if os.path.exists(path):
                sheet.paste(_tile(path), (x, cy))
                dirt, _ = measure.background_dirt(path)
            else:
                dr.rectangle([x, cy, x + CELL_W, cy + CELL_H], outline=(120, 120, 120))
                dr.text((x + 6, cy + CELL_H // 2), "판 없음", font=f_lab, fill=(120, 120, 120))
            # **테두리 색은 재굴림 순서가 아니라 실측값으로 정한다** — 재굴림 2 는
            # 완전히 안 지지는 않았다(5.4%). 「재굴림이니 무조건 초록」은 §27.32 가
            # 경계하는 「자를 안 믿고 서사를 믿는」 실수다.
            border = OK_BORDER if 0 <= dirt < 1.0 else (
                CAUTION_BORDER if dirt < 10.0 else BAD_BORDER)
            dr.rectangle([x, cy, x + CELL_W, cy + CELL_H], outline=border, width=4)
            cap_y = cy + CELL_H + 2
            dr.text((x + 2, cap_y), f"{style}  {tag_label}", font=f_lab, fill=(20, 20, 24))
            bg_dirt = f"{dirt:.1f}%" if dirt >= 0 else "?"
            dr.text((x + 2, cap_y + 16), f"배경얼룩 {bg_dirt}", font=f_small, fill=(80, 80, 86))
    y += rr_row_h

    os.makedirs(os.path.dirname(dest), exist_ok=True)
    sheet.save(dest)
    return dest


#: 후보 -> (축 설명, 이 자리에 속한 구획, 탈락/합격 사유). 숫자는 아래서 **재실측한다**
#: (§27.32 — 지어내지 않는다). 축 설명은 `illust.STYLE_CANDIDATES` 와 같은 말이다.
CANDIDATES = [
    ("p_oil", False, "매체: 유화", "합격"),
    ("p_gouache", False, "매체: 과슈", "합격"),
    ("p_digital", False, "매체: 디지털", "합격"),
    ("m_charcoal", False, "매체: 목탄", "합격"),
    ("m_lino", False, "매체: 판화",
     "합격(재굴림 권장) — 원 시드 78.2%는 불운이었다. 3시드 중 2개 성함(0.00%·5.77%, §27.33)"),
    ("p_water", False, "매체: 수채",
     "합격(재굴림 권장) — 원 시드 48.4%는 불운이었다. 3시드 중 2개 성함(0.00%·0.00%, §27.33)"),
    ("hairline", True, "선: 가장 가늘다 (닫힌배경 시절 후보)",
     "탈락 — 화풍 색 목록이 ③ 옷 색을 이김(§27.25.6·§27.27.2)"),
    ("cel", True, "음영: 각진 셀 (닫힌배경 시절 후보)",
     "탈락 — 위와 같음. 진홍이 옅게 죽는다"),
]


def print_report() -> None:
    """한 줄 요약 — 어느 축 / 배경 얼룩 % / 색 지배 / 탈락 사유. **실측을 다시 잰다.**"""
    print("=== 후보별 한 줄 (재실측) ===")
    for style, is_axis, axis, reason in CANDIDATES:
        people = PEOPLE_AXIS if is_axis else PEOPLE
        bg_parts = []
        for p in people:
            path = _axis_style_path(p, style) if is_axis else _cut_path(p, style)
            if not os.path.exists(path):
                bg_parts.append(f"#{p} ?")
                continue
            dirt, _ = measure.background_dirt(path)
            bg_parts.append(f"#{p} {dirt:.1f}%")
        cline, verdict = _colour_line(style, is_axis)
        bg = " / ".join(bg_parts)
        print(f"  {style:<12} {axis:<32} 배경 {bg:<20} {cline:<22} 색:{verdict:<4} {reason}")


def main() -> int:
    dest = os.path.join(CAST6, "portrait_style_sheet.png")
    print_report()
    out = build(dest)
    print(f"\n표: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
