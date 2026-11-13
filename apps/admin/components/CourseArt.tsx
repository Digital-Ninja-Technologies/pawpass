import { colourOf, coverUrl } from "@/lib/courses";

/** A course's picture as the app shows it: the cover if there is one, else the illustration on the course colour.
 * Decorative (the title next to it says it all). */
export function CourseArt({
  accent,
  art,
  cover,
  size = 56,
  wide,
  previewUrl,
}: {
  accent: string;
  art: string;
  /** Storage path of an uploaded cover. */
  cover?: string | null;
  size?: number;
  /** Draw it in the app's 4:3 card shape instead of a square. */
  wide?: boolean;
  /** A picture the person just chose but has not saved (form preview). */
  previewUrl?: string | null;
}) {
  const c = colourOf(accent);
  const base = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
  const picture = previewUrl ?? (cover && base ? coverUrl(base, cover) : null);
  const width = wide ? Math.round((size * 4) / 3) : size;
  return (
    <span
      aria-hidden="true"
      style={{
        display: "inline-block",
        width,
        height: size,
        borderRadius: wide ? 18 : 14,
        background: c.soft,
        overflow: "hidden",
        flex: "none",
      }}
    >
      <img
        src={picture ?? `/course-art/${art}.svg`}
        alt=""
        width={width}
        height={size}
        style={{ width: "100%", height: "100%", objectFit: picture ? "cover" : "contain" }}
      />
    </span>
  );
}
