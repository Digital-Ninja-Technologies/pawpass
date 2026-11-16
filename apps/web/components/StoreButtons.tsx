import { APP_STORE_URL, PLAY_STORE_URL } from "@/lib/stores";
import { PhoneIcon, PlayIcon } from "./icons";

/**
 * App store buttons. A store with a link is a real link; one without is shown as "coming soon" and is not a
 * link, so nothing leads to a dead end.
 */
export function StoreButtons({ light = false }: { light?: boolean }) {
  const cls = `store${light ? " light" : ""}`;
  const items = [
    { url: APP_STORE_URL, icon: <PhoneIcon />, small: "Download for", name: "iPhone" },
    { url: PLAY_STORE_URL, icon: <PlayIcon />, small: "Get it for", name: "Android" },
  ];
  return (
    <>
      {items.map((s) => {
        const inner = (
          <>
            {s.icon}
            <span className="t">
              <small>{s.url ? s.small : "Coming soon"}</small>
              <b>{s.name}</b>
            </span>
          </>
        );
        return s.url ? (
          <a key={s.name} href={s.url} className={cls} target="_blank" rel="noopener noreferrer">
            {inner}
            <span className="sr-only"> (opens in a new tab)</span>
          </a>
        ) : (
          <span
            key={s.name}
            className={`${cls} off`}
            role="img"
            aria-label={`${s.name}: coming soon`}
          >
            {inner}
          </span>
        );
      })}
    </>
  );
}
