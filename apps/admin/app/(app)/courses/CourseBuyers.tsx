import { Badge, Empty } from "@/components/ui";
import { formatDateTime, formatKobo } from "@/lib/format";
import type { CoursePurchaseRow } from "@/lib/types";
import { RefundButton, RetryRefundButton } from "./RefundButtons";

/** Who bought a course, what they paid, and where any refund stands. Money staff can refund from here. */
export function CourseBuyers({
  courseId,
  rows,
  canRefund,
}: {
  courseId: string;
  rows: CoursePurchaseRow[];
  canRefund: boolean;
}) {
  const kept = rows.filter((r) => r.status === "paid");
  const total = kept.reduce((n, r) => n + Number(r.amount_kobo), 0);
  return (
    <section className="card stack" aria-labelledby="buyers">
      <div className="card-head">
        <h2 id="buyers">Buyers</h2>
        <span className="muted">
          {kept.length} {kept.length === 1 ? "buyer" : "buyers"} · {formatKobo(total)} kept
        </span>
      </div>
      {rows.length === 0 ? (
        <Empty>Nobody has bought this course yet.</Empty>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Buyer</th>
                <th className="num">Paid</th>
                <th>When</th>
                <th>Status</th>
                <th>
                  <span className="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => {
                const stuck = r.status === "refund_queued" && r.refund_attempts >= 5;
                return (
                  <tr key={r.id}>
                    <td>
                      <b>{r.buyer_name}</b>
                      {r.refund_reason ? (
                        <span className="muted" style={{ display: "block", maxWidth: 320 }}>
                          Refund reason: {r.refund_reason}
                        </span>
                      ) : null}
                      {r.refund_error ? (
                        <span style={{ display: "block", color: "var(--danger)", maxWidth: 320 }}>
                          Paystack said: {r.refund_error}
                        </span>
                      ) : null}
                    </td>
                    <td className="num">{formatKobo(r.amount_kobo)}</td>
                    <td className="muted">
                      {r.refunded_at ? `Refunded ${formatDateTime(r.refunded_at)}` : formatDateTime(r.paid_at ?? r.created_at)}
                    </td>
                    <td>
                      {r.status === "paid" ? (
                        <Badge tone="good">Paid</Badge>
                      ) : r.status === "refunded" ? (
                        <Badge>Refunded</Badge>
                      ) : stuck ? (
                        <Badge tone="bad">Refund needs attention</Badge>
                      ) : (
                        <Badge tone="warn">Refund sending</Badge>
                      )}
                    </td>
                    <td>
                      {canRefund && r.status === "paid" ? (
                        <RefundButton
                          purchaseId={r.id}
                          courseId={courseId}
                          buyer={r.buyer_name}
                          amount={formatKobo(r.amount_kobo)}
                        />
                      ) : null}
                      {canRefund && stuck ? <RetryRefundButton purchaseId={r.id} courseId={courseId} /> : null}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
      <p className="notice info">
        A refund is always the full amount. The buyer loses the course straight away and the money goes back on Paystack
        within a few minutes. If Paystack cannot send it (for example the balance is too low), it is tried again, and shows
        here as needing attention after five tries. The buyer can buy the course again later.
      </p>
    </section>
  );
}
