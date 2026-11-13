import { courseColorKeys, courseColors, type CourseColorKey } from "@pawpass/shared";

/** The rules for a course, shared by the form and the server action. The database checks the same things again
 * (supabase/migrations/20261118100000_courses.sql): this file only gives good messages before anything is sent. */

export const AUDIENCES = [
  { value: "puppy", label: "Puppies" },
  { value: "dog", label: "Dogs" },
  { value: "both", label: "Puppies and dogs" },
] as const;
export type Audience = (typeof AUDIENCES)[number]["value"];

export const LEVELS = [
  { value: "beginner", label: "Beginner" },
  { value: "intermediate", label: "Intermediate" },
  { value: "advanced", label: "Advanced" },
] as const;
export type Level = (typeof LEVELS)[number]["value"];

/** The illustrations that ship with the app (apps/mobile/assets/course_art, copied to public/course-art). */
export const ART = [
  { key: "welcome", label: "Welcome home" },
  { key: "potty", label: "Potty training" },
  { key: "sit", label: "Sit and treats" },
  { key: "leash", label: "Walk on the lead" },
  { key: "chew", label: "Chewing" },
  { key: "social", label: "Making friends" },
  { key: "crate", label: "Crate and rest" },
  { key: "recall", label: "Coming when called" },
  { key: "tricks", label: "Party tricks" },
  { key: "health", label: "Health" },
  { key: "ball", label: "Play" },
  { key: "paw", label: "Big paw" },
] as const;
export type ArtKey = (typeof ART)[number]["key"];
export const ART_KEYS: string[] = ART.map((a) => a.key);

export const COLOURS = courseColorKeys.map((key) => ({ key, ...courseColors[key] }));
export function colourOf(key: string): (typeof courseColors)[CourseColorKey] {
  return (courseColors as Record<string, (typeof courseColors)[CourseColorKey]>)[key] ?? courseColors.sunny;
}

export const LIMITS = {
  title: [3, 80],
  summary: [3, 200],
  lessons: 30,
  lessonTitle: [2, 80],
  lessonBody: 4000,
  minutes: [1, 60],
  order: [0, 9999],
  coverBytes: 5 * 1024 * 1024,
} as const;

export const COVER_TYPES: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
};

export interface LessonInput {
  id?: string;
  title: string;
  body: string;
  minutes: number;
}

export type Parsed<T> = { ok: true; value: T } | { ok: false; error: string };

/** Reads the lessons the form sends as JSON, checking each one. Empty lessons at the end (a half filled box)
 * are an error, not silently dropped, so nothing the person typed is lost. */
export function parseLessons(raw: string): Parsed<LessonInput[]> {
  let data: unknown;
  try {
    data = JSON.parse(raw || "[]");
  } catch {
    return { ok: false, error: "The lessons could not be read. Reload the page and try again." };
  }
  if (!Array.isArray(data)) return { ok: false, error: "The lessons could not be read." };
  if (data.length > LIMITS.lessons)
    return { ok: false, error: `A course can have up to ${LIMITS.lessons} lessons.` };

  const out: LessonInput[] = [];
  for (let i = 0; i < data.length; i++) {
    const n = i + 1;
    const l = data[i] as Record<string, unknown> | null;
    if (typeof l !== "object" || l === null) return { ok: false, error: "The lessons could not be read." };
    const title = String(l.title ?? "").trim();
    const body = String(l.body ?? "").trim();
    const minutes = Number(l.minutes ?? 2);
    if (title.length < LIMITS.lessonTitle[0] || title.length > LIMITS.lessonTitle[1])
      return {
        ok: false,
        error: `Lesson ${n} needs a title of ${LIMITS.lessonTitle[0]} to ${LIMITS.lessonTitle[1]} characters.`,
      };
    if (body.length === 0) return { ok: false, error: `Lesson ${n} needs some text.` };
    if (body.length > LIMITS.lessonBody)
      return { ok: false, error: `Lesson ${n} is too long (up to ${LIMITS.lessonBody} characters).` };
    if (!Number.isInteger(minutes) || minutes < LIMITS.minutes[0] || minutes > LIMITS.minutes[1])
      return {
        ok: false,
        error: `Lesson ${n} must take a whole number of minutes, ${LIMITS.minutes[0]} to ${LIMITS.minutes[1]}.`,
      };
    const id = typeof l.id === "string" && /^[0-9a-f-]{36}$/i.test(l.id) ? l.id : undefined;
    out.push({ ...(id ? { id } : {}), title, body, minutes });
  }
  return { ok: true, value: out };
}

export interface CourseInput {
  title: string;
  summary: string;
  audience: Audience;
  level: Level;
  accent: string;
  art: string;
  status: "draft" | "published";
  sort_order: number;
}

export function parseCourse(f: {
  title: string;
  summary: string;
  audience: string;
  level: string;
  accent: string;
  art: string;
  status: string;
  sort_order: string;
}): Parsed<CourseInput> {
  const title = f.title.trim();
  const summary = f.summary.trim();
  if (title.length < LIMITS.title[0] || title.length > LIMITS.title[1])
    return { ok: false, error: `The title needs ${LIMITS.title[0]} to ${LIMITS.title[1]} characters.` };
  if (summary.length < LIMITS.summary[0] || summary.length > LIMITS.summary[1])
    return {
      ok: false,
      error: `The short description needs ${LIMITS.summary[0]} to ${LIMITS.summary[1]} characters.`,
    };
  if (!AUDIENCES.some((a) => a.value === f.audience)) return { ok: false, error: "Choose who the course is for." };
  if (!LEVELS.some((l) => l.value === f.level)) return { ok: false, error: "Choose a level." };
  if (!(courseColorKeys as string[]).includes(f.accent)) return { ok: false, error: "Choose a colour." };
  if (!ART_KEYS.includes(f.art)) return { ok: false, error: "Choose an illustration." };
  if (f.status !== "draft" && f.status !== "published")
    return { ok: false, error: "Status must be draft or published." };
  const order = f.sort_order.trim() === "" ? 100 : Number(f.sort_order);
  if (!Number.isInteger(order) || order < LIMITS.order[0] || order > LIMITS.order[1])
    return { ok: false, error: `The order must be a whole number from ${LIMITS.order[0]} to ${LIMITS.order[1]}.` };
  return {
    ok: true,
    value: {
      title,
      summary,
      audience: f.audience as Audience,
      level: f.level as Level,
      accent: f.accent,
      art: f.art,
      status: f.status,
      sort_order: order,
    },
  };
}

/** Checks a picture before it is uploaded. Returns an error message, or the file extension to use. */
export function checkCover(file: { type: string; size: number }): Parsed<string> {
  const ext = COVER_TYPES[file.type];
  if (!ext) return { ok: false, error: "The cover picture must be a JPG, PNG or WebP image." };
  if (file.size <= 0) return { ok: false, error: "The cover picture is empty." };
  if (file.size > LIMITS.coverBytes) return { ok: false, error: "The cover picture must be 5 MB or smaller." };
  return { ok: true, value: ext };
}

/** Only files this console put in the covers bucket may be removed by it: `<uuid>/<name>.<ext>`. */
export function isCoverPath(path: string | null | undefined): path is string {
  return typeof path === "string" && /^[0-9a-f-]{36}\/[A-Za-z0-9._-]{1,80}$/i.test(path);
}

/** A rough reading time, to suggest a number of minutes for a lesson (about 110 words a minute for this kind of
 * short, practical text). */
export function suggestMinutes(body: string): number {
  const words = body.trim().split(/\s+/).filter(Boolean).length;
  return Math.min(60, Math.max(1, Math.round(words / 110)));
}

/** The public address of a cover picture in the course-covers bucket. */
export function coverUrl(supabaseUrl: string, path: string): string {
  return `${supabaseUrl.replace(/\/$/, "")}/storage/v1/object/public/course-covers/${path
    .split("/")
    .map(encodeURIComponent)
    .join("/")}`;
}

export const AUDIENCE_LABEL: Record<string, string> = Object.fromEntries(AUDIENCES.map((a) => [a.value, a.label]));
export const LEVEL_LABEL: Record<string, string> = Object.fromEntries(LEVELS.map((l) => [l.value, l.label]));
