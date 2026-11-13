"use client";

import { ActionForm, SubmitButton } from "@/components/ActionForm";
import { deleteCourse, setCourseStatus } from "@/lib/actions/courses";

export function StatusButton({
  courseId,
  published,
  lessons,
}: {
  courseId: string;
  published: boolean;
  lessons: number;
}) {
  return (
    <ActionForm action={setCourseStatus} className="row">
      <input type="hidden" name="course" value={courseId} />
      <input type="hidden" name="status" value={published ? "draft" : "published"} />
      <SubmitButton
        small
        variant="secondary"
        confirm={
          published
            ? "Take this course out of the app? People who started it keep their progress, and you can publish it again."
            : lessons === 0
              ? undefined
              : "Publish this course? It goes live in the app straight away."
        }
      >
        {published ? "Unpublish" : "Publish"}
      </SubmitButton>
    </ActionForm>
  );
}

export function DeleteButton({
  courseId,
  title,
  learners,
  from,
}: {
  courseId: string;
  title: string;
  learners: number;
  from?: "detail";
}) {
  return (
    <ActionForm action={deleteCourse} className="row">
      <input type="hidden" name="course" value={courseId} />
      {from ? <input type="hidden" name="from" value={from} /> : null}
      <SubmitButton
        small
        variant="danger"
        confirm={`Delete "${title}" for good? Its lessons${
          learners > 0 ? ` and the progress of ${learners} ${learners === 1 ? "person" : "people"}` : ""
        } are deleted too. This cannot be undone. To hide it instead, use Unpublish.`}
      >
        Delete
      </SubmitButton>
    </ActionForm>
  );
}
