"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireAction, type Staff } from "../auth";
import { checkCover, isCoverPath, parseCourse, parseLessons } from "../courses";
import { flash, friendly, runRpc, text, type ActionState } from "./helpers";

const BUCKET = "course-covers";

function paths(id?: string): string[] {
  return ["/courses", ...(id ? [`/courses/${id}`] : []), "/"];
}

/** Deletes a cover file, best effort: a leftover file is harmless, a failed save is not. */
async function removeCover(staff: Staff, path: string | null | undefined): Promise<void> {
  if (!isCoverPath(path)) return;
  try {
    await staff.supabase.storage.from(BUCKET).remove([path]);
  } catch {
    /* the file stays; nothing depends on it */
  }
}

/** Creates or updates a course (and its lessons, and its cover picture). A new course goes back to the list. */
export async function saveCourse(_prev: ActionState, form: FormData): Promise<ActionState> {
  const ctx = await requireAction("manage_courses");
  if ("error" in ctx) return { ok: false, message: ctx.error };
  const staff = ctx as Staff;

  const id = text(form, "id") || null;
  if (id && !/^[0-9a-f-]{36}$/i.test(id)) return { ok: false, message: "That course could not be found." };

  const course = parseCourse({
    title: text(form, "title"),
    summary: text(form, "summary"),
    audience: text(form, "audience"),
    level: text(form, "level"),
    accent: text(form, "accent"),
    art: text(form, "art"),
    status: text(form, "status"),
    sort_order: text(form, "sort_order"),
    price: text(form, "price"),
  });
  if (!course.ok) return { ok: false, message: course.error };
  const lessons = parseLessons(String(form.get("lessons") ?? "[]"));
  if (!lessons.ok) return { ok: false, message: lessons.error };
  if (course.value.status === "published" && lessons.value.length === 0)
    return { ok: false, message: "Add at least one lesson before publishing." };

  // The picture: a new file replaces the old one; "remove" clears it; otherwise it is left alone.
  const file = form.get("cover");
  const oldCover = text(form, "old_cover") || null;
  let uploaded: string | null = null;
  let cover: string | undefined; // undefined = keep, "" = clear, a path = replace
  if (file instanceof File && file.size > 0) {
    const checked = checkCover(file);
    if (!checked.ok) return { ok: false, message: checked.error };
    uploaded = `${randomUUID()}/${Date.now()}.${checked.value}`;
    const { error } = await staff.supabase.storage
      .from(BUCKET)
      .upload(uploaded, file, { contentType: file.type, upsert: false });
    if (error) return { ok: false, message: "The cover picture could not be uploaded. Please try again." };
    cover = uploaded;
  } else if (form.get("remove_cover") === "on") {
    cover = "";
  }

  const { data, error } = await staff.supabase.rpc("admin_save_course", {
    p_id: id,
    p_course: {
      ...course.value,
      sort_order: String(course.value.sort_order),
      price_kobo: String(course.value.price_kobo),
      ...(cover === undefined ? {} : { cover_path: cover }),
    },
    p_lessons: lessons.value,
  });
  if (error) {
    await removeCover(staff, uploaded); // do not leave a picture behind for a course that was not saved
    return { ok: false, message: friendly(error.message) };
  }
  if (cover !== undefined && isCoverPath(oldCover)) await removeCover(staff, oldCover);

  const savedId = typeof data === "string" ? data : (id ?? undefined);
  for (const p of paths(savedId)) revalidatePath(p);
  if (!id) {
    await flash(
      course.value.status === "published"
        ? "Course created and live in the app."
        : "Course saved as a draft. Publish it when it is ready.",
    );
    redirect("/courses");
  }
  const message = course.value.status === "published" ? "Course saved. It is live in the app." : "Course saved as a draft.";
  await flash(message);
  return { ok: true, message };
}

/** Puts a course in the app, or takes it out again. Nothing is deleted when it is taken out. */
export async function setCourseStatus(_prev: ActionState, form: FormData): Promise<ActionState> {
  const status = text(form, "status");
  return runRpc(
    "manage_courses",
    "admin_set_course_status",
    { p_id: text(form, "course"), p_status: status },
    {
      paths: paths(text(form, "course")),
      success: status === "published" ? "Course published. It is live in the app." : "Course taken out of the app.",
    },
  );
}

/** Deletes a course, its lessons and everyone's progress in it, then its cover picture. */
export async function deleteCourse(_prev: ActionState, form: FormData): Promise<ActionState> {
  const ctx = await requireAction("manage_courses");
  if ("error" in ctx) return { ok: false, message: ctx.error };
  const staff = ctx as Staff;
  const id = text(form, "course");
  const { data, error } = await staff.supabase.rpc("admin_delete_course", { p_id: id });
  if (error) return { ok: false, message: friendly(error.message) };
  await removeCover(staff, typeof data === "string" ? data : null);
  for (const p of paths(id)) revalidatePath(p);
  await flash("Course deleted.");
  if (text(form, "from") === "detail") redirect("/courses");
  return { ok: true, message: "Course deleted." };
}

/** Refunds a course purchase in full. The buyer loses the course now; the money goes back on Paystack within minutes. */
export async function refundPurchase(_prev: ActionState, form: FormData): Promise<ActionState> {
  const reason = text(form, "reason");
  if (reason.length < 3) return { ok: false, message: "Give a reason of at least 3 characters." };
  if (reason.length > 300) return { ok: false, message: "Keep the reason under 300 characters." };
  return runRpc(
    "refund_course",
    "admin_refund_course_purchase",
    { p_purchase: text(form, "purchase"), p_reason: reason },
    {
      paths: ["/courses", `/courses/${text(form, "course")}`],
      success: "Refund started. The buyer loses the course now and the money goes back on Paystack within minutes.",
    },
  );
}

/** Sends a refund again that Paystack kept refusing, once the cause is fixed (for example the balance was topped up). */
export async function retryRefund(_prev: ActionState, form: FormData): Promise<ActionState> {
  return runRpc(
    "refund_course",
    "admin_retry_course_refund",
    { p_purchase: text(form, "purchase") },
    { paths: ["/courses", `/courses/${text(form, "course")}`], success: "Trying the refund again." },
  );
}
