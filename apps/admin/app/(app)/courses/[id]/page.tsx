import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { requireSection } from "@/lib/auth";
import { canDo } from "@/lib/roles";
import { Badge, PageHeader } from "@/components/ui";
import type { CoursePurchaseRow, CourseRow, LessonRow } from "@/lib/types";
import { CourseBuyers } from "../CourseBuyers";
import { CourseForm } from "../CourseForm";
import { DeleteButton, StatusButton } from "../CourseButtons";

export const metadata: Metadata = { title: "Edit course" };

/** The lesson text lives in its own table: one row per lesson, joined here. */
function toLessons(rows: unknown): LessonRow[] {
  return ((rows ?? []) as Record<string, unknown>[]).map((r) => {
    const t = r.course_lesson_text;
    const first = Array.isArray(t) ? t[0] : t;
    return {
      id: r.id as string,
      course_id: r.course_id as string,
      position: r.position as number,
      title: r.title as string,
      minutes: r.minutes as number,
      preview: r.preview === true,
      body: ((first as { body?: string } | null | undefined)?.body ?? "") as string,
    };
  });
}

export default async function EditCoursePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!/^[0-9a-f-]{36}$/i.test(id)) notFound();
  const { supabase, staff } = await requireSection("courses");
  const canManage = canDo(staff.role, "manage_courses");

  const [course, lessons, purchases] = await Promise.all([
    supabase.from("admin_course_v").select("*").eq("id", id).maybeSingle<CourseRow>(),
    supabase
      .from("course_lessons")
      .select("id, course_id, position, title, minutes, preview, course_lesson_text(body)")
      .eq("course_id", id)
      .order("position", { ascending: true }),
    supabase.rpc("admin_course_purchases", { p_course: id }),
  ]);
  if (!course.data) notFound();
  const c = course.data;

  return (
    <>
      <PageHeader
        crumbs={
          <>
            <Link href="/courses">Courses</Link> › {c.title}
          </>
        }
        title={c.title}
        subtitle={
          <span className="row" style={{ gap: 8 }}>
            {c.status === "published" ? <Badge tone="good">Live in the app</Badge> : <Badge tone="warn">Draft</Badge>}
            <span className="muted">
              {c.learners} {c.learners === 1 ? "learner" : "learners"}
            </span>
          </span>
        }
        actions={
          canManage ? (
            <span className="row">
              <StatusButton courseId={c.id} published={c.status === "published"} lessons={c.lessons} />
              <DeleteButton courseId={c.id} title={c.title} learners={c.learners} buyers={c.buyers} from="detail" />
            </span>
          ) : null
        }
      />
      {c.price_kobo > 0 || (purchases.data ?? []).length > 0 ? (
        <CourseBuyers
          courseId={c.id}
          rows={(purchases.data ?? []) as CoursePurchaseRow[]}
          canRefund={canDo(staff.role, "refund_course")}
        />
      ) : null}
      <CourseForm course={c} lessons={toLessons(lessons.data)} canEdit={canManage} />
    </>
  );
}
