/**
 * Where the apps are. The Android app is live on Google Play. The iPhone app is not yet: set
 * NEXT_PUBLIC_APP_STORE_URL when it is, and its button becomes a link by itself. Each store is handled on its
 * own, so one being live never waits for the other.
 */
export const PLAY_STORE_URL =
  process.env.NEXT_PUBLIC_PLAY_STORE_URL || "https://play.google.com/store/apps/details?id=com.ourpawpass.app";
export const APP_STORE_URL = process.env.NEXT_PUBLIC_APP_STORE_URL || "";

/** True when every store link is set. */
export const STORES_LIVE = Boolean(APP_STORE_URL && PLAY_STORE_URL);

/** What to say under the buttons, or null when there is nothing to add. */
export function storesNote(appStoreUrl = APP_STORE_URL, playStoreUrl = PLAY_STORE_URL): string | null {
  if (appStoreUrl && playStoreUrl) return null;
  if (playStoreUrl) return "The Android app is on Google Play. The iPhone app is coming soon.";
  if (appStoreUrl) return "The iPhone app is on the App Store. The Android app is coming soon.";
  return "OurPawPass is not in the app stores yet. The download buttons will go live here at launch.";
}

/** The short line under the hero buttons. */
export function heroStoresLine(appStoreUrl = APP_STORE_URL, playStoreUrl = PLAY_STORE_URL): string {
  if (appStoreUrl && playStoreUrl) return "Free · iOS and Android";
  if (playStoreUrl) return "Free · Android now · iPhone coming soon";
  if (appStoreUrl) return "Free · iPhone now · Android coming soon";
  return "Free · iOS and Android · coming soon";
}
