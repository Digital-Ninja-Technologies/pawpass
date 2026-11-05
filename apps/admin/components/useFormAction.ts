"use client";

import { startTransition, useActionState, type FormEvent } from "react";

/** Runs a server action from a form WITHOUT React's automatic form reset.
 *
 * With `<form action={fn}>` React 19 resets the form after every action, even when it
 * returned an error. That wipes what the person typed and can put radio buttons back to
 * their defaults while the screen still shows the other state (we hit this on the dispute
 * decision form: a retried split submitted as a full refund). Submitting through onSubmit
 * keeps the fields exactly as they were. */
export function useFormAction<S>(
  action: (prev: S | null, formData: FormData) => Promise<S | null>,
) {
  const [state, formAction, pending] = useActionState<S | null, FormData>(action, null);
  const onSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const submitter = (e.nativeEvent as SubmitEvent).submitter as HTMLElement | null;
    const data = new FormData(e.currentTarget, submitter);
    startTransition(() => formAction(data));
  };
  return { state, onSubmit, pending };
}
