import type { Metadata } from "next";
import Link from "next/link";
import { requireSection } from "@/lib/auth";
import { canDo } from "@/lib/roles";
import { AUDIENCE_LABEL, LEVEL_LABEL, priceText } from "@/lib/courses";
import { formatDate, formatKobo } from "@/lib/format";
import { Badge, Empty, PageHeader, Stat } from "@/components/ui";
import { CourseArt } from "@/components/CourseArt";
import type { CourseRow } from "@/lib/types";
import { DeleteButton, StatusButton } from "./CourseButtons";

export const metadata: Metadata = { title: "Courses" };

export default async function CoursesPage() {
  const { supabase, staff } = await requireSection("courses");
  const canManage = canDo(staff.role, "manage_courses");
  const { data, error } = await supabase
    .from("admin_course_v")
    .select("*")
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: true });
  const rows = (data ?? []) as CourseRow[];
  const live = rows.filter((r) => r.status === "published");
  const drafts = rows.length - live.length;
  const liveLessons = live.reduce((n, r) => n + r.lessons, 0);
  const starts = rows.reduce((n, r) => n + r.learners, 0);
  const paid = rows.filter((r) => r.price_kobo > 0);
  const sales = rows.reduce((n, r) => n + Number(r.revenue_kobo ?? 0), 0);
  const buyers = rows.reduce((n, r) => n + Number(r.buyers ?? 0), 0);

  return (
    <>
      <PageHeader
        title="Courses"
        subtitle="The puppy and dog courses people see in the app. Published courses appear in the app straight away."
        actions={
          canManage ? (
            <Link className="btn primary" href="/courses/new">
              + New course
            </Link>
          ) : null
        }
      />
      <section className="grid stats" aria-label="Summary">
        <Stat label="Live in the app" value={live.length} note={`${liveLessons} lessons`} />
        <Stat label="Drafts" value={drafts} note="Hidden from the app" />
        <Stat
          label="Course sales"
          value={formatKobo(sales)}
          note={`${buyers} ${buyers === 1 ? "purchase" : "purchases"} across ${paid.length} paid ${paid.length === 1 ? "course" : "courses"}`}
        />
        <Stat
          label="Learner starts"
          value={starts.toLocaleString("en-NG")}
          note="People who have done at least one lesson, counted per course"
        />
      </section>

      <section className="card" aria-label="All courses">
        <div className="card-head">
          <h2>All courses</h2>
          <span className="muted">Shown in the app in this order (lowest number first)</span>
        </div>
        {error ? (
          <div className="notice err" role="alert">
            The courses could not be loaded. Reload the page, and if it keeps happening, tell the tech team.
          </div>
        ) : rows.length === 0 ? (
          <Empty>
            No courses yet. {canManage ? "Add the first one with + New course." : "A full admin can add one."}
          </Empty>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th className="num">Order</th>
                  <th>Course</th>
                  <th>For</th>
                  <th>Level</th>
                  <th>Price</th>
                  <th className="num">Lessons</th>
                  <th className="num">Learners</th>
                  <th className="num">Buyers</th>
                  <th>Status</th>
                  <th>Updated</th>
                  <th>
                    <span className="sr-only">Actions</span>
                  </th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id}>
                    <td className="num muted">{r.sort_order}</td>
                    <td>
                      <span className="row" style={{ flexWrap: "nowrap" }}>
                        <CourseArt accent={r.accent} art={r.art} cover={r.cover_path} size={48} wide />
                        <span>
                          <Link href={`/courses/${r.id}`}>
                            <b>{r.title}</b>
                          </Link>
                          <span className="muted" style={{ display: "block", maxWidth: 360 }}>
                            {r.summary}
                          </span>
                        </span>
                      </span>
                    </td>
                    <td className="muted">{AUDIENCE_LABEL[r.audience] ?? r.audience}</td>
                    <td className="muted">{LEVEL_LABEL[r.level] ?? r.level}</td>
                    <td>
                      {r.price_kobo > 0 ? <b>{priceText(r.price_kobo)}</b> : <span className="muted">Free</span>}
                    </td>
                    <td className="num">
                      {r.lessons}
                      <span className="muted"> · {r.minutes} min</span>
                    </td>
                    <td className="num">{r.learners}</td>
                    <td className="num">
                      {r.price_kobo > 0 || r.buyers > 0 ? (
                        <>
                          {r.buyers}
                          <span className="muted"> · {formatKobo(r.revenue_kobo)}</span>
                        </>
                      ) : (
                        <span className="muted">-</span>
                      )}
                    </td>
                    <td>
                      {r.status === "published" ? (
                        <Badge tone="good">Live</Badge>
                      ) : (
                        <Badge tone="warn">Draft</Badge>
                      )}
                    </td>
                    <td className="muted">{formatDate(r.updated_at)}</td>
                    <td>
                      <span className="row" style={{ flexWrap: "nowrap" }}>
                        <Link className="btn secondary small" href={`/courses/${r.id}`}>
                          {canManage ? "Edit" : "View"}
                        </Link>
                        {canManage ? (
                          <>
                            <StatusButton
                              courseId={r.id}
                              published={r.status === "published"}
                              lessons={r.lessons}
                            />
                            <DeleteButton courseId={r.id} title={r.title} learners={r.learners} buyers={r.buyers} />
                          </>
                        ) : null}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </>
  );
}
