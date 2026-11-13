"use client";

import { useMemo, useRef, useState } from "react";
import { ActionForm, SubmitButton } from "@/components/ActionForm";
import { CourseArt } from "@/components/CourseArt";
import { saveCourse } from "@/lib/actions/courses";
import {
  ART,
  AUDIENCE_LABEL,
  AUDIENCES,
  checkCover,
  COLOURS,
  colourOf,
  LEVEL_LABEL,
  LEVELS,
  LIMITS,
  suggestMinutes,
} from "@/lib/courses";
import type { CourseRow, LessonRow } from "@/lib/types";

interface LessonDraft {
  key: string;
  id?: string;
  title: string;
  body: string;
  minutes: string;
}

let counter = 0;
const nextKey = () => `l${++counter}`;

export function CourseForm({
  course,
  lessons,
  canEdit,
}: {
  course?: CourseRow;
  lessons?: LessonRow[];
  canEdit: boolean;
}) {
  const [title, setTitle] = useState(course?.title ?? "");
  const [summary, setSummary] = useState(course?.summary ?? "");
  const [audience, setAudience] = useState<string>(course?.audience ?? "both");
  const [level, setLevel] = useState<string>(course?.level ?? "beginner");
  const [accent, setAccent] = useState(course?.accent ?? "sunny");
  const [art, setArt] = useState(course?.art ?? "paw");
  const [status, setStatus] = useState<string>(course?.status ?? "draft");
  const [order, setOrder] = useState(String(course?.sort_order ?? 100));
  const [items, setItems] = useState<LessonDraft[]>(
    (lessons ?? []).map((l) => ({
      key: nextKey(),
      id: l.id,
      title: l.title,
      body: l.body,
      minutes: String(l.minutes),
    })),
  );
  const [removeCover, setRemoveCover] = useState(false);
  const [picked, setPicked] = useState<string | null>(null);
  const [coverError, setCoverError] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const colours = colourOf(accent);
  const totalMinutes = items.reduce((n, l) => n + (Number(l.minutes) || 0), 0);
  const lessonsJson = useMemo(
    () =>
      JSON.stringify(
        items.map((l) => ({ ...(l.id ? { id: l.id } : {}), title: l.title, body: l.body, minutes: l.minutes })),
      ),
    [items],
  );
  const existingCover = removeCover ? null : (course?.cover_path ?? null);

  const update = (key: string, change: Partial<LessonDraft>) =>
    setItems((all) => all.map((l) => (l.key === key ? { ...l, ...change } : l)));
  const move = (index: number, by: -1 | 1) =>
    setItems((all) => {
      const to = index + by;
      if (to < 0 || to >= all.length) return all;
      const copy = [...all];
      [copy[index], copy[to]] = [copy[to], copy[index]];
      return copy;
    });
  const remove = (l: LessonDraft) => {
    const filled = l.title.trim() !== "" || l.body.trim() !== "";
    if (filled && !window.confirm(`Remove the lesson "${l.title.trim() || "Untitled"}"? ${l.id ? "People's ticks on it are removed too." : ""}`)) return;
    setItems((all) => all.filter((x) => x.key !== l.key));
  };

  function onPick(file: File | undefined) {
    setCoverError(null);
    if (picked) URL.revokeObjectURL(picked);
    if (!file) {
      setPicked(null);
      return;
    }
    const check = checkCover(file);
    if (!check.ok) {
      setCoverError(check.error);
      setPicked(null);
      if (fileRef.current) fileRef.current.value = "";
      return;
    }
    setPicked(URL.createObjectURL(file));
    setRemoveCover(false);
  }

  return (
    <ActionForm action={saveCourse} hideSuccess={false}>
      <input type="hidden" name="id" value={course?.id ?? ""} />
      <input type="hidden" name="old_cover" value={course?.cover_path ?? ""} />
      <input type="hidden" name="lessons" value={lessonsJson} />

      <div className="course-layout">
        <fieldset disabled={!canEdit} className="stack course-fields">
          <section className="card stack" aria-labelledby="about">
            <h2 id="about">About the course</h2>
            <label className="field">
              Title
              <input
                className="input"
                name="title"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                maxLength={LIMITS.title[1]}
                required
                placeholder="For example: Potty training made simple"
              />
            </label>
            <label className="field">
              Short description
              <textarea
                className="textarea"
                name="summary"
                value={summary}
                onChange={(e) => setSummary(e.target.value)}
                maxLength={LIMITS.summary[1]}
                rows={2}
                required
                placeholder="One friendly line that says what people will learn."
              />
              <span className="hint">
                {summary.trim().length} of {LIMITS.summary[1]} characters. Shown on the course card.
              </span>
            </label>
            <div className="grid two">
              <label className="field">
                Who is it for
                <select
                  className="select"
                  name="audience"
                  value={audience}
                  onChange={(e) => setAudience(e.target.value)}
                >
                  {AUDIENCES.map((a) => (
                    <option key={a.value} value={a.value}>
                      {a.label}
                    </option>
                  ))}
                </select>
              </label>
              <label className="field">
                Level
                <select className="select" name="level" value={level} onChange={(e) => setLevel(e.target.value)}>
                  {LEVELS.map((l) => (
                    <option key={l.value} value={l.value}>
                      {l.label}
                    </option>
                  ))}
                </select>
              </label>
              <label className="field">
                Status
                <select className="select" name="status" value={status} onChange={(e) => setStatus(e.target.value)}>
                  <option value="draft">Draft (hidden from the app)</option>
                  <option value="published">Published (live in the app)</option>
                </select>
              </label>
              <label className="field">
                Order in the app
                <input
                  className="input"
                  name="sort_order"
                  value={order}
                  onChange={(e) => setOrder(e.target.value)}
                  inputMode="numeric"
                />
                <span className="hint">Lowest number first. Leave gaps (10, 20, 30) so it is easy to slot one in.</span>
              </label>
            </div>
          </section>

          <section className="card stack" aria-labelledby="look">
            <h2 id="look">How it looks</h2>
            <fieldset className="plain">
              <legend className="field-label">Colour</legend>
              <div className="swatches">
                {COLOURS.map((c) => (
                  <label key={c.key} className="swatch" title={c.label}>
                    <input
                      type="radio"
                      name="accent"
                      value={c.key}
                      checked={accent === c.key}
                      onChange={() => setAccent(c.key)}
                    />
                    <span style={{ background: c.soft, borderColor: c.strong }}>
                      <i style={{ background: c.strong }} aria-hidden="true" />
                      <b>{c.label}</b>
                    </span>
                  </label>
                ))}
              </div>
            </fieldset>
            <fieldset className="plain">
              <legend className="field-label">Illustration</legend>
              <div className="art-grid">
                {ART.map((a) => (
                  <label key={a.key} className="art-choice">
                    <input
                      type="radio"
                      name="art"
                      value={a.key}
                      checked={art === a.key}
                      onChange={() => setArt(a.key)}
                    />
                    <span style={{ background: colours.soft }}>
                      <img src={`/course-art/${a.key}.svg`} alt="" width={96} height={72} />
                      <b>{a.label}</b>
                    </span>
                  </label>
                ))}
              </div>
              <span className="hint">Shown when the course has no cover picture of its own.</span>
            </fieldset>
            <div className="field">
              <label htmlFor="cover">Cover picture (optional)</label>
              <input
                id="cover"
                ref={fileRef}
                className="input file"
                type="file"
                name="cover"
                accept="image/jpeg,image/png,image/webp"
                onChange={(e) => onPick(e.target.files?.[0])}
              />
              <span className="hint">
                JPG, PNG or WebP, up to 5 MB. It replaces the illustration. Wide pictures (4:3) look best.
              </span>
              {coverError ? (
                <span className="notice err" role="alert">
                  {coverError}
                </span>
              ) : null}
              {course?.cover_path && !picked ? (
                <label className="check">
                  <input
                    type="checkbox"
                    name="remove_cover"
                    checked={removeCover}
                    onChange={(e) => setRemoveCover(e.target.checked)}
                  />
                  <span>Remove the current cover picture and show the illustration</span>
                </label>
              ) : null}
            </div>
          </section>

          <section className="card stack" aria-labelledby="lessons">
            <div className="card-head">
              <h2 id="lessons">Lessons</h2>
              <span className="muted">
                {items.length} {items.length === 1 ? "lesson" : "lessons"} · {totalMinutes} min
              </span>
            </div>
            <p className="notice info">
              Write short, friendly lessons. Leave a blank line between paragraphs. Start a line with &quot;- &quot; for
              a bullet point. Start a paragraph with &quot;Tip: &quot; to show it as a tip card.
            </p>
            {items.length === 0 ? (
              <div className="empty">No lessons yet. A course needs at least one before it can be published.</div>
            ) : null}
            <ol className="lessons">
              {items.map((l, i) => (
                <li key={l.key} className="lesson">
                  <div className="card-head">
                    <h3>Lesson {i + 1}</h3>
                    <span className="row">
                      <button
                        type="button"
                        className="btn secondary small"
                        onClick={() => move(i, -1)}
                        disabled={i === 0}
                        aria-label={`Move lesson ${i + 1} up`}
                      >
                        Up
                      </button>
                      <button
                        type="button"
                        className="btn secondary small"
                        onClick={() => move(i, 1)}
                        disabled={i === items.length - 1}
                        aria-label={`Move lesson ${i + 1} down`}
                      >
                        Down
                      </button>
                      <button
                        type="button"
                        className="btn danger small"
                        onClick={() => remove(l)}
                        aria-label={`Remove lesson ${i + 1}`}
                      >
                        Remove
                      </button>
                    </span>
                  </div>
                  <label className="field">
                    Lesson title
                    <input
                      className="input"
                      value={l.title}
                      onChange={(e) => update(l.key, { title: e.target.value })}
                      maxLength={LIMITS.lessonTitle[1]}
                    />
                  </label>
                  <label className="field">
                    Lesson text
                    <textarea
                      className="textarea"
                      value={l.body}
                      onChange={(e) => update(l.key, { body: e.target.value })}
                      rows={7}
                      maxLength={LIMITS.lessonBody}
                    />
                    <span className="hint">
                      {l.body.length} of {LIMITS.lessonBody} characters
                    </span>
                  </label>
                  <label className="field" style={{ maxWidth: 220 }}>
                    Minutes to read
                    <input
                      className="input"
                      value={l.minutes}
                      onChange={(e) => update(l.key, { minutes: e.target.value })}
                      inputMode="numeric"
                    />
                    <button
                      type="button"
                      className="link-btn"
                      onClick={() => update(l.key, { minutes: String(suggestMinutes(l.body)) })}
                    >
                      Suggest from the length
                    </button>
                  </label>
                </li>
              ))}
            </ol>
            <div>
              <button
                type="button"
                className="btn secondary"
                disabled={items.length >= LIMITS.lessons}
                onClick={() => setItems((all) => [...all, { key: nextKey(), title: "", body: "", minutes: "2" }])}
              >
                + Add a lesson
              </button>
            </div>
          </section>
        </fieldset>

        <aside className="course-side" aria-label="Preview">
          <div className="card stack course-preview">
            <span className="overline">How it looks in the app</span>
            <div className="app-card">
              <div className="app-art" style={{ background: colours.soft }}>
                <CourseArt
                  accent={accent}
                  art={art}
                  cover={existingCover}
                  previewUrl={picked}
                  size={150}
                  wide
                />
              </div>
              <div className="app-body">
                <span className="row" style={{ gap: 6 }}>
                  <span className="pill" style={{ background: colours.soft, color: colours.text }}>
                    {AUDIENCE_LABEL[audience]}
                  </span>
                  <span className="pill">{LEVEL_LABEL[level]}</span>
                </span>
                <b className="app-title">{title.trim() || "Your course title"}</b>
                <span className="app-summary">{summary.trim() || "A friendly line about the course."}</span>
                <span className="muted">
                  {items.length} {items.length === 1 ? "lesson" : "lessons"} · {Math.max(totalMinutes, 1)} mins
                </span>
              </div>
            </div>
            {canEdit ? (
              <>
                <SubmitButton>{course ? "Save changes" : status === "published" ? "Create and publish" : "Save draft"}</SubmitButton>
                <span className="hint">
                  {status === "published"
                    ? "This course is live in the app as soon as you save."
                    : "Drafts are hidden from the app."}
                </span>
              </>
            ) : (
              <p className="notice info">Your role can look at courses but not change them.</p>
            )}
          </div>
        </aside>
      </div>
    </ActionForm>
  );
}
