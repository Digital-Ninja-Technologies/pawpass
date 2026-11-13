import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { requireSection } from "@/lib/auth";
import { canDo } from "@/lib/roles";
import { PageHeader } from "@/components/ui";
import { CourseForm } from "../CourseForm";

export const metadata: Metadata = { title: "New course" };

export default async function NewCoursePage() {
  const { staff } = await requireSection("courses");
  if (!canDo(staff.role, "manage_courses")) redirect("/courses");
  return (
    <>
      <PageHeader
        crumbs={
          <>
            <Link href="/courses">Courses</Link> › New course
          </>
        }
        title="New course"
        subtitle="Save it as a draft while you work, then publish it when it is ready."
      />
      <CourseForm canEdit />
    </>
  );
}
