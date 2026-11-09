import { describe, expect, it, vi } from "vitest";
import {
  buildEmail,
  escapeHtml,
  groupByEmail,
  runReminders,
  type Mailer,
  type ReminderCtx,
  type ReminderDb,
  type ReminderRow,
} from "./reminders.ts";

const row = (id: string, email: string, title = "Rabies booster is due tomorrow", body = "Book a vet for Bingo before 12 Nov.", firstName = "Tolu"): ReminderRow => ({
  notificationId: id,
  email,
  firstName,
  title,
  body,
});

function fakes(rows: ReminderRow[], send: Mailer["send"] = async () => ({ ok: true })) {
  const finished: [string, boolean][] = [];
  const db: ReminderDb = {
    announce: vi.fn(async () => 3),
    claim: vi.fn(async () => rows),
    finish: vi.fn(async (id: string, ok: boolean) => {
      finished.push([id, ok]);
    }),
  };
  const mailer: Mailer = { send: vi.fn(send) };
  const ctx: ReminderCtx = { db, mailer, from: "PawPass <reminders@ourpawpass.com>" };
  return { ctx, db, mailer, finished };
}

describe("escapeHtml", () => {
  it("escapes what could break out of the page", () => {
    expect(escapeHtml(`<img src=x onerror="a('b')">&`)).toBe("&lt;img src=x onerror=&quot;a(&#39;b&#39;)&quot;&gt;&amp;");
  });
});

describe("groupByEmail", () => {
  it("puts one person's reminders together, ignoring letter case", () => {
    const groups = groupByEmail([row("1", "Tolu@Example.com"), row("2", "tolu@example.com"), row("3", "kemi@example.com")]);
    expect(groups.size).toBe(2);
    expect(groups.get("tolu@example.com")?.map((r) => r.notificationId)).toEqual(["1", "2"]);
  });
});

describe("buildEmail", () => {
  it("uses the reminder as the subject when there is one", () => {
    const m = buildEmail("Tolu", [{ title: "Rabies booster is due tomorrow", body: "Book a vet for Bingo." }]);
    expect(m.subject).toBe("Rabies booster is due tomorrow");
    expect(m.text).toContain("Hi Tolu,");
    expect(m.html).toContain("here is a reminder");
  });
  it("counts them when there are several", () => {
    const m = buildEmail("Tolu", [
      { title: "A", body: "a" },
      { title: "B", body: "b" },
    ]);
    expect(m.subject).toBe("2 pet reminders from PawPass");
    expect(m.html).toContain("here are your reminders");
  });
  it("says hello without a name", () => {
    expect(buildEmail("  ", [{ title: "A", body: "a" }]).text).toContain("Hi there,");
  });
  it("escapes names and notes typed by people", () => {
    const m = buildEmail("<b>Tolu</b>", [{ title: "Rabies", body: `Book a vet for <script>alert(1)</script>.` }]);
    expect(m.html).not.toContain("<script>");
    expect(m.html).not.toContain("<b>Tolu</b>");
    expect(m.html).toContain("&lt;script&gt;");
  });
  it("tells people how to stop the emails and never uses an em dash", () => {
    const m = buildEmail("Tolu", [{ title: "A", body: "a" }]);
    expect(m.text).toContain("turn email off");
    expect(m.html).toContain("turn email off");
    expect(m.text + m.html).not.toMatch(/[–—]/);
  });
});

describe("runReminders", () => {
  it("announces, then sends one email per person and records each as sent", async () => {
    const { ctx, mailer, finished } = fakes([row("1", "tolu@example.com"), row("2", "tolu@example.com"), row("3", "kemi@example.com")]);
    const res = await runReminders(ctx);
    expect(res).toEqual({ announced: 3, people: 2, sent: 2, failed: 0 });
    expect(mailer.send).toHaveBeenCalledTimes(2);
    expect(finished).toEqual([["1", true], ["2", true], ["3", true]]);
    const first = (mailer.send as ReturnType<typeof vi.fn>).mock.calls[0][0];
    expect(first.to).toBe("tolu@example.com");
    expect(first.from).toBe("PawPass <reminders@ourpawpass.com>");
    expect(first.subject).toBe("2 pet reminders from PawPass");
  });

  it("records a refused send as failed so it is tried again, and still sends the others", async () => {
    const { ctx, finished } = fakes(
      [row("1", "bad@example.com"), row("2", "kemi@example.com")],
      async (m) => (m.to === "bad@example.com" ? { ok: false, error: "invalid" } : { ok: true }),
    );
    const res = await runReminders(ctx);
    expect(res).toMatchObject({ sent: 1, failed: 1 });
    expect(finished).toEqual([["1", false], ["2", true]]);
  });

  it("treats a thrown error (no network) as a failed send", async () => {
    const { ctx, finished } = fakes([row("1", "tolu@example.com")], async () => {
      throw new Error("network");
    });
    const res = await runReminders(ctx);
    expect(res.failed).toBe(1);
    expect(finished).toEqual([["1", false]]);
  });

  it("does nothing more when nobody is due an email", async () => {
    const { ctx, mailer } = fakes([]);
    expect(await runReminders(ctx)).toEqual({ announced: 3, people: 0, sent: 0, failed: 0 });
    expect(mailer.send).not.toHaveBeenCalled();
  });
});
