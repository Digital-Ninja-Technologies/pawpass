// The reminder job, written against small interfaces so it can be tested without a database or Resend.
// The database decides who is told and when (see migration 20261115100000_reminder_job_email.sql); this only
// writes the emails, sends them, and records how each one went.

export interface ReminderRow {
  notificationId: string;
  email: string;
  firstName: string;
  title: string;
  body: string;
}

export interface ReminderDb {
  /** Announces due reminders for everyone, in the app. Returns how many are new. */
  announce(): Promise<number>;
  /** Announcements to email now (the database respects quiet hours, channels and retries). */
  claim(limit: number): Promise<ReminderRow[]>;
  finish(notificationId: string, ok: boolean): Promise<void>;
}

export interface Message {
  from: string;
  to: string;
  subject: string;
  html: string;
  text: string;
}

export interface Mailer {
  send(message: Message): Promise<{ ok: boolean; error?: string }>;
}

export interface ReminderCtx {
  db: ReminderDb;
  mailer: Mailer;
  /** For example "PawPass <reminders@ourpawpass.com>". */
  from: string;
}

export function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/** One person gets one email, however many reminders are due. */
export function groupByEmail(rows: ReminderRow[]): Map<string, ReminderRow[]> {
  const out = new Map<string, ReminderRow[]>();
  for (const row of rows) {
    const key = row.email.trim().toLowerCase();
    const list = out.get(key);
    if (list) list.push(row);
    else out.set(key, [row]);
  }
  return out;
}

const COLOURS = {
  ground: "#FFF8F1",
  surface: "#FFFFFF",
  ink: "#1F1A17",
  ink2: "#4A433E",
  muted: "#6B625B",
  border: "#EDE3D9",
  primary: "#0E6B63",
  primarySoft: "#E3F1EE",
  primaryText: "#0B5650",
};

const OFF_HINT = "To stop these emails, open Me, then Notifications & reminders in the app, and turn email off.";

/** The subject, the HTML and the plain text of one person's email. Names and notes are typed by people, so they are escaped. */
export function buildEmail(
  firstName: string,
  items: { title: string; body: string }[],
): { subject: string; html: string; text: string } {
  const name = firstName.trim();
  const hello = name ? `Hi ${name},` : "Hi there,";
  const subject = items.length === 1 ? items[0].title : `${items.length} pet reminders from PawPass`;

  const text = [
    hello,
    "",
    ...items.flatMap((i) => [`${i.title}`, `${i.body}`, ""]),
    "Open PawPass to book a vet or mark a reminder as done.",
    "",
    OFF_HINT,
    "",
    "PawPass",
  ].join("\n");

  const rows = items
    .map(
      (i) => `<tr><td style="padding:12px 0;border-top:1px solid ${COLOURS.border};font-family:Arial,Helvetica,sans-serif;">
<div style="font-size:16px;font-weight:700;color:${COLOURS.ink};">${escapeHtml(i.title)}</div>
<div style="font-size:14px;line-height:1.5;color:${COLOURS.ink2};margin-top:4px;">${escapeHtml(i.body)}</div>
</td></tr>`,
    )
    .join("\n");

  const html = `<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1" /><title>${escapeHtml(subject)}</title></head>
<body style="margin:0;padding:0;background:${COLOURS.ground};">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${COLOURS.ground};"><tr><td align="center" style="padding:32px 16px;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:${COLOURS.surface};border:1px solid ${COLOURS.border};border-radius:24px;">
<tr><td style="padding:28px 28px 4px 28px;font-family:Arial,Helvetica,sans-serif;font-size:22px;font-weight:700;color:${COLOURS.primary};">OurPawPass</td></tr>
<tr><td style="padding:8px 28px 0 28px;font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:1.6;color:${COLOURS.ink2};">${escapeHtml(hello)} here ${items.length === 1 ? "is a reminder" : "are your reminders"} for your pets.</td></tr>
<tr><td style="padding:12px 28px 0 28px;"><table role="presentation" width="100%" cellpadding="0" cellspacing="0">
${rows}
</table></td></tr>
<tr><td style="padding:16px 28px 0 28px;font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:1.6;color:${COLOURS.primaryText};">Open PawPass to book a vet or mark a reminder as done.</td></tr>
<tr><td style="padding:16px 28px 28px 28px;font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:1.6;color:${COLOURS.muted};">${escapeHtml(OFF_HINT)}</td></tr>
</table></td></tr></table></body></html>`;

  return { subject, html, text };
}

export interface RunResult {
  announced: number;
  people: number;
  sent: number;
  failed: number;
}

/**
 * The scheduled job: announce what is due in the app, then email the people who chose email.
 * Never throws for one person's failure: it is recorded so the next run can try again.
 */
export async function runReminders(ctx: ReminderCtx, limit = 50): Promise<RunResult> {
  const announced = await ctx.db.announce();
  const rows = await ctx.db.claim(limit);
  const groups = groupByEmail(rows);
  let sent = 0;
  let failed = 0;
  for (const [email, items] of groups) {
    let ok = false;
    try {
      const mail = buildEmail(items[0].firstName, items);
      const res = await ctx.mailer.send({ from: ctx.from, to: email, ...mail });
      ok = res.ok;
      if (!ok) console.error("reminder email refused", res.error ?? "unknown");
    } catch (e) {
      console.error("reminder email failed", e);
    }
    for (const item of items) {
      try {
        await ctx.db.finish(item.notificationId, ok);
      } catch (e) {
        console.error("reminder result not recorded", item.notificationId, e);
      }
    }
    if (ok) sent++;
    else failed++;
  }
  return { announced, people: groups.size, sent, failed };
}
