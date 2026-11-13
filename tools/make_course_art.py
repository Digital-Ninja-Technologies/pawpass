#!/usr/bin/env python3
"""Draws the course illustrations: flat, friendly dog scenes on a transparent background.

They sit on a course's colour (the accent), so they only use a small set of fixed colours that work on every accent.
Output: apps/mobile/assets/course_art/<key>.svg (the app) and apps/admin/public/course-art/<key>.svg (the console).
The two folders must stay identical (apps/admin/lib/courses.test.ts checks it).

    python3 tools/make_course_art.py
"""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUTS = [ROOT / "apps/mobile/assets/course_art", ROOT / "apps/admin/public/course-art"]

INK = "#2B1B14"
FUR = "#E8A35B"
FUR_DARK = "#B5702E"
FACE = "#F6C98A"
MUZZLE = "#FFF1DC"
TONGUE = "#F0657A"
WHITE = "#FFFFFF"
RED = "#E5484D"
BLUE = "#3E7BFA"
GREEN = "#3DAE5F"
YELLOW = "#FFC83D"
PURPLE = "#8B5CF6"
BONE = "#FFF8EC"


def head(tongue=False, happy=True, fur=FUR, ear=FUR_DARK, face=FACE, blink=False):
    eyes = (
        f'<path d="M-26 -6q6 -6 12 0M14 -6q6 -6 12 0" fill="none" stroke="{INK}" stroke-width="4" stroke-linecap="round"/>'
        if blink
        else f'<circle cx="-20" cy="-6" r="6.5" fill="{INK}"/><circle cx="20" cy="-6" r="6.5" fill="{INK}"/>'
        f'<circle cx="-18" cy="-8.5" r="2.2" fill="{WHITE}"/><circle cx="22" cy="-8.5" r="2.2" fill="{WHITE}"/>'
    )
    smile = f'<path d="M-13 20q13 12 13 0q0 12 13 0" fill="none" stroke="{INK}" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>'
    tng = f'<path d="M-6 27q6 15 12 0z" fill="{TONGUE}"/>' if tongue else ""
    return (
        f'<ellipse cx="-47" cy="-14" rx="19" ry="34" transform="rotate(18 -47 -14)" fill="{ear}"/>'
        f'<ellipse cx="47" cy="-14" rx="19" ry="34" transform="rotate(-18 47 -14)" fill="{ear}"/>'
        f'<ellipse cx="0" cy="0" rx="55" ry="49" fill="{fur}"/>'
        f'<ellipse cx="0" cy="-20" rx="20" ry="16" fill="{face}"/>'
        f'<ellipse cx="0" cy="18" rx="31" ry="23" fill="{MUZZLE}"/>'
        f"{eyes}"
        f'<ellipse cx="0" cy="6" rx="9.5" ry="6.5" fill="{INK}"/><ellipse cx="-2.5" cy="4" rx="2.6" ry="1.6" fill="{WHITE}" opacity=".6"/>'
        f"{smile}{tng}"
    )


def body(fur=FUR, paw=MUZZLE, sit=True):
    return (
        f'<ellipse cx="0" cy="96" rx="47" ry="46" fill="{fur}"/>'
        f'<ellipse cx="0" cy="104" rx="28" ry="34" fill="{FACE}"/>'
        f'<ellipse cx="-22" cy="138" rx="15" ry="10" fill="{paw}"/><ellipse cx="22" cy="138" rx="15" ry="10" fill="{paw}"/>'
    )


def dog(x, y, s=1.0, rot=0, tongue=False, fur=FUR, ear=FUR_DARK, face=FACE, with_body=True, blink=False):
    inner = (body(fur=fur) if with_body else "") + head(tongue=tongue, fur=fur, ear=ear, face=face, blink=blink)
    return f'<g transform="translate({x} {y}) rotate({rot}) scale({s})">{inner}</g>'


def blob(cx=160, cy=118, r=104):
    return (
        f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{WHITE}" opacity=".42"/>'
        f'<circle cx="34" cy="48" r="9" fill="{WHITE}" opacity=".55"/><circle cx="292" cy="40" r="6" fill="{WHITE}" opacity=".55"/>'
        f'<circle cx="286" cy="196" r="11" fill="{WHITE}" opacity=".5"/><circle cx="28" cy="188" r="6" fill="{WHITE}" opacity=".5"/>'
    )


def heart(x, y, s=1.0, c=RED, rot=0):
    return (
        f'<g transform="translate({x} {y}) rotate({rot}) scale({s})">'
        f'<path d="M0 12C-20 -2 -16 -20 -6 -20 0 -20 0 -14 0 -12 0 -14 0 -20 6 -20 16 -20 20 -2 0 12z" fill="{c}"/></g>'
    )


def star(x, y, s=1.0, c=YELLOW):
    return (
        f'<g transform="translate({x} {y}) scale({s})"><path d="M0 -14l4.2 9 9.8 1.2 -7.2 6.7 1.9 9.7 -8.7 -4.8 -8.7 4.8 1.9 -9.7 -7.2 -6.7 9.8 -1.2z" fill="{c}"/></g>'
    )


def bone(x, y, s=1.0, rot=0):
    return (
        f'<g transform="translate({x} {y}) rotate({rot}) scale({s})" fill="{BONE}" stroke="{INK}" stroke-width="3" stroke-linejoin="round">'
        f'<path d="M-22 -5a8 8 0 1 1 6 -9h32a8 8 0 1 1 6 9 8 8 0 1 1 -6 9h-32a8 8 0 1 1 -6 -9z"/></g>'
    )


def ball(x, y, r=16, c=YELLOW):
    return (
        f'<circle cx="{x}" cy="{y}" r="{r}" fill="{c}" stroke="{INK}" stroke-width="3"/>'
        f'<path d="M{x - r * .8:.1f} {y - r * .4:.1f}q{r * .8:.1f} {r * .6:.1f} {r * 1.6:.1f} 0M{x - r * .8:.1f} {y + r * .4:.1f}q{r * .8:.1f} -{r * .6:.1f} {r * 1.6:.1f} 0" '
        f'fill="none" stroke="{WHITE}" stroke-width="2.4" stroke-linecap="round"/>'
    )


def paw(x, y, s=1.0, c=FUR_DARK, op=1.0):
    return (
        f'<g transform="translate({x} {y}) scale({s})" fill="{c}" opacity="{op}">'
        f'<ellipse cx="0" cy="8" rx="11" ry="9"/><ellipse cx="-12" cy="-6" rx="4.5" ry="6"/><ellipse cx="-4" cy="-13" rx="4.5" ry="6"/>'
        f'<ellipse cx="6" cy="-13" rx="4.5" ry="6"/><ellipse cx="14" cy="-5" rx="4.5" ry="6"/></g>'
    )


def spark(x, y, s=1.0, c=WHITE):
    return f'<g transform="translate({x} {y}) scale({s})"><path d="M0 -10Q1.5 -1.5 10 0 1.5 1.5 0 10 -1.5 1.5 -10 0 -1.5 -1.5 0 -10z" fill="{c}"/></g>'


def svg(inner):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 240" width="320" height="240">{inner}</svg>\n'


def welcome():
    house = (
        f'<path d="M64 104 160 28l96 76v112H64z" fill="{WHITE}" opacity=".85"/>'
        f'<path d="M52 108 160 22l108 86" fill="none" stroke="{INK}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>'
        f'<rect x="124" y="120" width="72" height="96" rx="36" fill="{FUR_DARK}" opacity=".35"/>'
    )
    bunting = (
        f'<path d="M70 62Q160 96 250 62" fill="none" stroke="{INK}" stroke-width="3"/>'
        + "".join(
            f'<path d="M{x} {y}l12 0 -6 16z" fill="{c}"/>'
            for x, y, c in [(90, 70, RED), (118, 80, YELLOW), (146, 85, BLUE), (176, 85, GREEN), (204, 80, PURPLE), (230, 70, RED)]
        )
    )
    mat = f'<rect x="96" y="214" width="128" height="12" rx="6" fill="{RED}"/><rect x="104" y="217" width="112" height="3" rx="1.5" fill="{WHITE}" opacity=".7"/>'
    return svg(blob() + house + bunting + dog(160, 108, .78, tongue=True) + mat + heart(262, 70, 1.1) + heart(48, 98, .8, c=PURPLE, rot=-12))


def potty():
    grass = (
        f'<ellipse cx="160" cy="218" rx="118" ry="20" fill="{GREEN}"/>'
        + "".join(f'<path d="M{x} 214q2 -22 8 -26 1 12 -2 26zM{x + 10} 214q6 -18 14 -20 -2 12 -8 20z" fill="#2E8F4B"/>' for x in (46, 92, 232, 266))
    )
    drops = "".join(f'<path d="M{x} {y}q-7 11 0 14t7 -14q-3 -7 -7 0z" fill="{BLUE}"/>' for x, y in [(236, 112), (256, 138), (270, 104)])
    tree = (
        f'<rect x="262" y="150" width="9" height="56" rx="3" fill="{FUR_DARK}"/><circle cx="266" cy="140" r="26" fill="{GREEN}"/><circle cx="250" cy="156" r="16" fill="#2E8F4B"/>'
    )
    return svg(blob() + grass + tree + dog(130, 98, .72, tongue=True) + drops + star(64, 64, 1.2) + star(228, 52, .8, c=WHITE) + paw(72, 196, .7))


def sit():
    arrow = f'<path d="M262 74v54M262 128l-12 -14M262 128l12 -14" fill="none" stroke="{INK}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>'
    return svg(blob() + dog(150, 92, .84, tongue=True) + bone(238, 52, 1.0, -22) + arrow + star(58, 60, 1.1) + spark(68, 150, 1.3) + spark(262, 168, 1.0))


def leash():
    collar = f'<path d="M-40 52q40 26 80 0" fill="none" stroke="{RED}" stroke-width="10" stroke-linecap="round" transform="translate(150 90) scale(.84)"/>'
    tag = f'<circle cx="150" cy="140" r="8" fill="{YELLOW}" stroke="{INK}" stroke-width="3"/>'
    lead = (
        f'<path d="M150 134Q196 170 232 150T286 76" fill="none" stroke="{RED}" stroke-width="6" stroke-linecap="round"/>'
        f'<path d="M286 76q16 -24 -2 -36" fill="none" stroke="{RED}" stroke-width="6" stroke-linecap="round"/>'
        f'<circle cx="286" cy="76" r="8" fill="{RED}"/>'
    )
    trail = paw(46, 196, .8, op=.55) + paw(88, 214, .8, op=.55) + paw(132, 220, .8, op=.55)
    return svg(blob() + dog(150, 92, .84, tongue=True) + collar + lead + tag + trail + star(60, 62, 1.0) + spark(262, 190, 1.2))


def chew():
    return svg(
        blob()
        + dog(150, 88, .84, with_body=True)
        + bone(150, 118, 1.3, 0)
        + f'<path d="M222 192q6 -10 18 -10l26 2q8 2 6 10l-4 14q-2 6 -10 6h-30q-8 0 -8 -8z" fill="{BLUE}" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
        + f'<path d="M232 190v10M244 190v10M256 190v10" stroke="{WHITE}" stroke-width="3" stroke-linecap="round"/>'
        + star(54, 64, 1.0, c=PURPLE)
        + spark(262, 66, 1.3)
        + paw(60, 196, .8, op=.5)
    )


def social():
    return svg(
        blob()
        + dog(104, 108, .66, tongue=True)
        + dog(222, 118, .56, fur="#C98A5A", ear="#7A4A26", face="#E9B987", blink=False)
        + heart(164, 56, 1.4)
        + heart(150, 36, .7, c=PURPLE, rot=-14)
        + heart(182, 38, .6, c=YELLOW, rot=12)
        + f'<circle cx="276" cy="64" r="5" fill="{INK}" opacity=".5"/><circle cx="262" cy="52" r="3.5" fill="{INK}" opacity=".35"/>'
        + paw(52, 200, .8, op=.5)
    )


def crate():
    bars = "".join(f'<rect x="{x}" y="64" width="6" height="140" rx="3" fill="{INK}"/>' for x in range(78, 250, 28))
    return svg(
        blob()
        + f'<rect x="64" y="58" width="192" height="152" rx="14" fill="{WHITE}" opacity=".6"/>'
        + f'<rect x="72" y="176" width="176" height="28" rx="14" fill="{PURPLE}" opacity=".75"/>'
        + dog(160, 112, .62, blink=True, with_body=False)
        + f'<rect x="64" y="58" width="192" height="152" rx="14" fill="none" stroke="{INK}" stroke-width="6"/>'
        + bars
        + f'<path d="M278 56a22 22 0 1 0 14 38 28 28 0 0 1 -14 -38z" fill="{YELLOW}"/>'
        + star(40, 64, .9, c=WHITE)
        + star(34, 130, .6, c=YELLOW)
        + spark(286, 150, 1.0)
    )


def recall():
    lines = "".join(f'<path d="M{x} {y}h{w}" stroke="{INK}" stroke-width="5" stroke-linecap="round" opacity=".55"/>' for x, y, w in [(20, 84, 40), (10, 112, 56), (24, 140, 34)])
    whistle = f'<g transform="translate(252 64)"><rect x="-22" y="-10" width="36" height="22" rx="11" fill="{YELLOW}" stroke="{INK}" stroke-width="3"/><circle cx="14" cy="2" r="9" fill="{YELLOW}" stroke="{INK}" stroke-width="3"/></g>'
    return svg(
        blob()
        + lines
        + dog(176, 98, .84, rot=-8, tongue=True)
        + whistle
        + f'<path d="M232 88q22 4 28 24M238 66q38 6 48 44" fill="none" stroke="{INK}" stroke-width="4" stroke-linecap="round" opacity=".6"/>'
        + paw(72, 210, .8, op=.5)
        + paw(112, 222, .7, op=.5)
        + star(266, 176, .9)
    )


def tricks():
    hat = f'<path d="M-24 -42 0 -96 24 -42z" transform="translate(150 96) scale(.84)" fill="{PURPLE}"/><circle cx="150" cy="16" r="7" fill="{YELLOW}"/>'
    raised_paw = (
        f'<g transform="rotate(-32 108 158)"><ellipse cx="108" cy="150" rx="14" ry="26" fill="{FUR}"/>'
        f'<ellipse cx="108" cy="128" rx="11" ry="9" fill="{MUZZLE}"/></g>'
    )
    return svg(
        blob()
        + dog(158, 96, .84, tongue=True)
        + raised_paw
        + hat
        + ball(252, 190, 16, c=RED)
        + star(54, 64, 1.2)
        + star(262, 62, 1.0, c=WHITE)
        + spark(46, 196, 1.2)
        + f'<path d="M220 30l8 14M236 22l2 16M204 34l12 10" stroke="{YELLOW}" stroke-width="4" stroke-linecap="round"/>'
    )


def health():
    shield = (
        f'<path d="M262 56 214 74v44c0 28 20 48 48 58 28 -10 48 -30 48 -58V74z" transform="translate(-6 -6) scale(.86)" fill="{WHITE}" stroke="{GREEN}" stroke-width="6" stroke-linejoin="round"/>'
        f'<path d="M244 100h12v-12h12v12h12v12h-12v12h-12v-12h-12z" fill="{GREEN}"/>'
    )
    patch = f'<g transform="translate(150 88) scale(.84) rotate(-18)"><rect x="12" y="-52" width="38" height="16" rx="6" fill="{WHITE}" stroke="{INK}" stroke-width="2.5"/><path d="M31 -50v12M25 -44h12" stroke="{RED}" stroke-width="3" stroke-linecap="round"/></g>'
    return svg(blob() + dog(142, 92, .84, tongue=True) + patch + shield + heart(52, 66, 1.0) + spark(60, 168, 1.2) + f'<circle cx="278" cy="184" r="12" fill="{YELLOW}"/><path d="M278 162v-6M278 212v6M256 184h-6M306 184h6" stroke="{YELLOW}" stroke-width="4" stroke-linecap="round"/>')


def ball_art():
    return svg(blob() + dog(150, 92, .84, tongue=True) + ball(244, 176, 22) + ball(70, 70, 12, c=BLUE) + star(262, 66, 1.0) + spark(48, 176, 1.2))


def paw_art():
    return svg(
        blob()
        + paw(160, 118, 4.0, c=FUR, op=1)
        + bone(76, 188, 1.1, -18)
        + heart(256, 62, 1.3)
        + star(60, 60, 1.1)
        + spark(262, 188, 1.3)
    )


ART = {
    "welcome": welcome,
    "potty": potty,
    "sit": sit,
    "leash": leash,
    "chew": chew,
    "social": social,
    "crate": crate,
    "recall": recall,
    "tricks": tricks,
    "health": health,
    "ball": ball_art,
    "paw": paw_art,
}

if __name__ == "__main__":
    for out in OUTS:
        out.mkdir(parents=True, exist_ok=True)
        for key, fn in ART.items():
            (out / f"{key}.svg").write_text(fn(), encoding="utf-8")
    print(f"wrote {len(ART)} illustrations to {', '.join(str(o.relative_to(ROOT)) for o in OUTS)}")
