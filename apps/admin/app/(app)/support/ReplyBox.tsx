"use client";

import { useRef } from "react";
import { ActionForm, SubmitButton } from "@/components/ActionForm";
import { reply, setTicketStatus } from "@/lib/actions/support";

const TEMPLATES = [
  [
    "Refund sent",
    "Hi, your refund has been sent. It reaches your card or bank in 3 to 5 working days. Thank you for your patience.",
  ],
  [
    "Dispute timeline",
    "Hi, your money is safe and on hold while we look into this. The partner has up to 72 hours to reply, then we decide. We will update you here as soon as we do.",
  ],
] as const;

export function ReplyBox({ ticketId, closed }: { ticketId: string; closed: boolean }) {
  const area = useRef<HTMLTextAreaElement>(null);
  return (
    <div className="stack">
      <ActionForm action={reply}>
        <input type="hidden" name="ticket" value={ticketId} />
        <div className="row">
          {TEMPLATES.map(([label, body]) => (
            <button
              key={label}
              type="button"
              className="btn secondary small"
              onClick={() => {
                if (area.current) {
                  area.current.value = body;
                  area.current.focus();
                }
              }}
            >
              Template: {label}
            </button>
          ))}
        </div>
        <label className="field">
          Reply
          <textarea ref={area} className="textarea" name="body" required />
        </label>
        <div className="row">
          <SubmitButton name="mode" value="note" variant="secondary">
            Add internal note
          </SubmitButton>
          <SubmitButton name="mode" value="reply">
            Send reply
          </SubmitButton>
        </div>
      </ActionForm>
      <ActionForm action={setTicketStatus} className="row">
        <input type="hidden" name="ticket" value={ticketId} />
        <input type="hidden" name="status" value={closed ? "open" : "closed"} />
        <SubmitButton small variant="secondary">
          {closed ? "Reopen ticket" : "Close ticket"}
        </SubmitButton>
      </ActionForm>
    </div>
  );
}
