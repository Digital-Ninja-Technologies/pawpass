import { APP_STORE_URL, PLAY_STORE_URL, STORES_LIVE } from "@/lib/stores";
import { PhoneIcon, PlayIcon } from "./icons";

/**
 * App store buttons. Until the real store links are set they are shown as "coming soon" and are
 * not links, so nothing leads to a dead end.
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
              <small>{STORES_LIVE ? s.small : "Coming soon"}</small>
              <b>{s.name}</b>
            </span>
          </>
        );
        return STORES_LIVE ? (
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
