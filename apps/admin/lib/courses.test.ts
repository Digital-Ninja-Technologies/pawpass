import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { courseColors } from "@pawpass/shared";
import {
  ART,
  ART_KEYS,
  AUDIENCES,
  checkCover,
  colourOf,
  coverUrl,
  isCoverPath,
  LIMITS,
  parseCourse,
  parseLessons,
  parsePrice,
  priceText,
  suggestMinutes,
} from "./courses";

const good = {
  title: "Rainy day games",
  summary: "Fun things to do indoors",
  audience: "both",
  level: "beginner",
  accent: "sky",
  art: "ball",
  status: "draft",
  sort_order: "5",
};

describe("parseCourse", () => {
  it("accepts a good course and trims it", () => {
    const r = parseCourse({ ...good, title: "  Rainy day games  " });
    expect(r).toEqual({
      ok: true,
      value: { ...good, title: "Rainy day games", sort_order: 5, price_kobo: 0 },
    });
  });

  it("an empty order falls back to 100", () => {
    const r = parseCourse({ ...good, sort_order: "" });
    expect(r.ok && r.value.sort_order).toBe(100);
  });

  it.each([
    [{ title: "Hi" }, /title/],
    [{ title: "x".repeat(81) }, /title/],
    [{ summary: "" }, /short description/],
    [{ summary: "x".repeat(201) }, /short description/],
    [{ audience: "cats" }, /who the course is for/],
    [{ level: "expert" }, /level/],
    [{ accent: "green" }, /colour/],
    [{ art: "unicorn" }, /illustration/],
    [{ status: "archived" }, /draft or published/],
    [{ sort_order: "abc" }, /order/],
    [{ sort_order: "1.5" }, /order/],
    [{ sort_order: "-1" }, /order/],
    [{ sort_order: "10000" }, /order/],
  ])("rejects %j", (change, message) => {
    const r = parseCourse({ ...good, ...change });
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error).toMatch(message);
  });
});

describe("parseLessons", () => {
  const lesson = { title: "Hide and seek", body: "Hide a treat.", minutes: 3 };

  it("accepts lessons, keeps real ids and drops anything else", () => {
    const id = "123e4567-e89b-12d3-a456-426614174000";
    const r = parseLessons(JSON.stringify([{ ...lesson, id }, { ...lesson, id: "not-a-uuid" }]));
    expect(r.ok && r.value).toEqual([
      { ...lesson, id, preview: false },
      { ...lesson, preview: false },
    ]);
  });

  it("no lessons is fine (a draft)", () => {
    expect(parseLessons("")).toEqual({ ok: true, value: [] });
    expect(parseLessons("[]")).toEqual({ ok: true, value: [] });
  });

  it("minutes may arrive as text from the form", () => {
    const r = parseLessons(JSON.stringify([{ ...lesson, minutes: "4" }]));
    expect(r.ok && r.value[0].minutes).toBe(4);
  });

  it.each([
    ["not json", /could not be read/],
    ['{"a":1}', /could not be read/],
    ["[1]", /could not be read/],
    [JSON.stringify([{ ...lesson, title: "A" }]), /Lesson 1 needs a title/],
    [JSON.stringify([lesson, { ...lesson, body: "   " }]), /Lesson 2 needs some text/],
    [JSON.stringify([{ ...lesson, body: "x".repeat(LIMITS.lessonBody + 1) }]), /Lesson 1 is too long/],
    [JSON.stringify([{ ...lesson, minutes: 0 }]), /Lesson 1 must take/],
    [JSON.stringify([{ ...lesson, minutes: 61 }]), /Lesson 1 must take/],
    [JSON.stringify([{ ...lesson, minutes: 2.5 }]), /Lesson 1 must take/],
    [JSON.stringify([{ ...lesson, minutes: "soon" }]), /Lesson 1 must take/],
    [JSON.stringify(Array.from({ length: 31 }, () => lesson)), /up to 30 lessons/],
  ])("rejects %s", (raw, message) => {
    const r = parseLessons(raw);
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error).toMatch(message);
  });
});

describe("covers", () => {
  it("accepts JPG, PNG and WebP up to 5 MB", () => {
    expect(checkCover({ type: "image/jpeg", size: 1000 })).toEqual({ ok: true, value: "jpg" });
    expect(checkCover({ type: "image/png", size: 1000 })).toEqual({ ok: true, value: "png" });
    expect(checkCover({ type: "image/webp", size: LIMITS.coverBytes })).toEqual({ ok: true, value: "webp" });
  });

  it("rejects other types, empty files and big files", () => {
    expect(checkCover({ type: "image/gif", size: 1000 }).ok).toBe(false);
    expect(checkCover({ type: "application/pdf", size: 1000 }).ok).toBe(false);
    expect(checkCover({ type: "image/png", size: 0 }).ok).toBe(false);
    expect(checkCover({ type: "image/png", size: LIMITS.coverBytes + 1 }).ok).toBe(false);
  });

  it("only paths made by this console count as covers", () => {
    expect(isCoverPath("123e4567-e89b-12d3-a456-426614174000/1731500000000.webp")).toBe(true);
    expect(isCoverPath("../secret.png")).toBe(false);
    expect(isCoverPath("avatars/x.png")).toBe(false);
    expect(isCoverPath("123e4567-e89b-12d3-a456-426614174000/../x.png")).toBe(false);
    expect(isCoverPath(null)).toBe(false);
    expect(isCoverPath("")).toBe(false);
  });

  it("builds the public address", () => {
    expect(coverUrl("https://x.supabase.co/", "abc/def 1.png")).toBe(
      "https://x.supabase.co/storage/v1/object/public/course-covers/abc/def%201.png",
    );
  });
});

describe("helpers", () => {
  it("suggests minutes from the length, never below 1 or above 60", () => {
    expect(suggestMinutes("")).toBe(1);
    expect(suggestMinutes("word ".repeat(110))).toBe(1);
    expect(suggestMinutes("word ".repeat(330))).toBe(3);
    expect(suggestMinutes("word ".repeat(100000))).toBe(60);
  });

  it("falls back to sunny for an unknown colour", () => {
    expect(colourOf("grape")).toBe(courseColors.grape);
    expect(colourOf("nope")).toBe(courseColors.sunny);
  });

  it("the audiences are the three the app knows", () => {
    expect(AUDIENCES.map((a) => a.value)).toEqual(["puppy", "dog", "both"]);
  });
});

describe("prices", () => {
  it("blank, 0 and typed zeros are free", () => {
    for (const t of ["", "  ", "0", "0.00", "₦0", "00"]) expect(parsePrice(t)).toEqual({ ok: true, value: 0 });
  });

  it("reads naira into kobo, with commas and the naira sign", () => {
    expect(parsePrice("2500")).toEqual({ ok: true, value: 250_000 });
    expect(parsePrice("₦2,500")).toEqual({ ok: true, value: 250_000 });
    expect(parsePrice("1500.50")).toEqual({ ok: true, value: 150_050 });
    expect(parsePrice("100")).toEqual({ ok: true, value: 10_000 });
    expect(parsePrice("1000000")).toEqual({ ok: true, value: 100_000_000 });
  });

  it("rejects amounts that are not numbers, too small, or too big", () => {
    for (const t of ["abc", "-5", "12.345", "1e5"]) {
      const r = parsePrice(t);
      expect(r.ok).toBe(false);
    }
    expect(parsePrice("99")).toMatchObject({ ok: false });
    expect(parsePrice("1000001")).toMatchObject({ ok: false });
  });

  it("parseCourse carries the price in kobo", () => {
    const r = parseCourse({ ...good, price: "2500" });
    expect(r.ok && r.value.price_kobo).toBe(250_000);
    const free = parseCourse({ ...good });
    expect(free.ok && free.value.price_kobo).toBe(0);
    const bad = parseCourse({ ...good, price: "50" });
    expect(bad.ok).toBe(false);
    if (!bad.ok) expect(bad.error).toMatch(/₦100/);
  });

  it("shows Free or the naira amount", () => {
    expect(priceText(0)).toBe("Free");
    expect(priceText(null)).toBe("Free");
    expect(priceText(250_000)).toBe("₦2,500");
    expect(priceText(150_050)).toBe("₦1,500.5");
  });

  it("the limits match the database", () => {
    const sql = readFileSync(join(__dirname, "../../../supabase/migrations/20261118100000_courses.sql"), "utf8");
    const m = /price_kobo = 0 or price_kobo between (\d+) and (\d+)/.exec(sql);
    expect(m).not.toBeNull();
    expect([Number(m![1]), Number(m![2])]).toEqual([LIMITS.priceKobo[0], LIMITS.priceKobo[1]]);
  });
});

describe("lesson previews", () => {
  it("keeps the free preview flag", () => {
    const r = parseLessons(JSON.stringify([{ title: "Free taste", body: "Open", minutes: 2, preview: true }, { title: "Locked", body: "Closed", minutes: 2 }]));
    expect(r.ok && r.value.map((l) => l.preview)).toEqual([true, false]);
  });

  it("anything but true is not a preview", () => {
    const r = parseLessons(JSON.stringify([{ title: "Lesson", body: "Text", minutes: 2, preview: "yes" }]));
    expect(r.ok && r.value[0].preview).toBe(false);
  });
});

describe("illustrations", () => {
  const mobile = join(__dirname, "../../mobile/assets/course_art");
  const admin = join(__dirname, "../public/course-art");

  it("every illustration the form offers exists in the console and in the app", () => {
    const here = readdirSync(admin).sort();
    const there = readdirSync(mobile).sort();
    expect(here).toEqual(ART.map((a) => `${a.key}.svg`).sort());
    expect(there).toEqual(here);
  });

  it("the console and app copies are identical (run tools/make_course_art.py to refresh both)", () => {
    for (const key of ART_KEYS) {
      expect(readFileSync(join(admin, `${key}.svg`), "utf8")).toBe(readFileSync(join(mobile, `${key}.svg`), "utf8"));
    }
  });

  it("the database accepts exactly these illustrations and colours", () => {
    const sql = readFileSync(join(__dirname, "../../../supabase/migrations/20261118100000_courses.sql"), "utf8");
    const art = /art text not null default 'paw' check \(art in \(([^)]*)\)\)/.exec(sql)?.[1] ?? "";
    const accent = /accent text not null default 'sunny' check \(accent in \(([^)]*)\)\)/.exec(sql)?.[1] ?? "";
    const list = (s: string) => s.split(",").map((x) => x.trim().replace(/'/g, "")).sort();
    expect(list(art)).toEqual([...ART_KEYS].sort());
    expect(list(accent)).toEqual(Object.keys(courseColors).sort());
  });
});
