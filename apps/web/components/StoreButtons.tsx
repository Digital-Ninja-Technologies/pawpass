import { APP_STORE_URL, PLAY_STORE_URL, STORES_LIVE } from "@/lib/stores";
import { PhoneIcon, PlayIcon } from "./icons";

/** App store buttons. Until the real store links are set they lead to the email form, never to a dead end. */
export function StoreButtons({ light = false }: { light?: boolean }) {
  const cls = `store${light ? " light" : ""}`;
  const external = STORES_LIVE ? { target: "_blank", rel: "noopener noreferrer" } : {};
  return (
    <>
      <a href={STORES_LIVE ? APP_STORE_URL : "#get-link"} className={cls} {...external}>
        <PhoneIcon />
        <span className="t">
          <small>Download for</small>
          <b>iPhone</b>
        </span>
      </a>
      <a href={STORES_LIVE ? PLAY_STORE_URL : "#get-link"} className={cls} {...external}>
        <PlayIcon />
        <span className="t">
          <small>Get it for</small>
          <b>Android</b>
        </span>
      </a>
    </>
  );
}
