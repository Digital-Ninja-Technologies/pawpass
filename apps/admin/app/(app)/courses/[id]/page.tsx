import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { requireSection } from "@/lib/auth";
import { canDo } from "@/lib/roles";
import { Badge, PageHeader } from "@/components/ui";
import type { CourseRow, LessonRow } from "@/lib/types";
import { CourseForm } from "../CourseForm";
import { DeleteButton, StatusButton } from "../CourseButtons";

export const metadata: Metadata = { title: "Edit course" };

export default async function EditCoursePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!/^[0-9a-f-]{36}$/i.test(id)) notFound();
  const { supabase, staff } = await requireSection("courses");
  const canManage = canDo(staff.role, "manage_courses");

  const [course, lessons] = await Promise.all([
    supabase.from("admin_course_v").select("*").eq("id", id).maybeSingle<CourseRow>(),
    supabase
      .from("course_lessons")
      .select("id, course_id, position, title, body, minutes")
      .eq("course_id", id)
      .order("position", { ascending: true }),
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
              <DeleteButton courseId={c.id} title={c.title} learners={c.learners} from="detail" />
            </span>
          ) : null
        }
      />
      <CourseForm course={c} lessons={(lessons.data ?? []) as LessonRow[]} canEdit={canManage} />
    </>
  );
}
