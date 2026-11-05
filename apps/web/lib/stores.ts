/** Set these when the app is live in the stores. Until then the store buttons lead to the email form. */
export const APP_STORE_URL = process.env.NEXT_PUBLIC_APP_STORE_URL || "";
export const PLAY_STORE_URL = process.env.NEXT_PUBLIC_PLAY_STORE_URL || "";
export const STORES_LIVE = Boolean(APP_STORE_URL && PLAY_STORE_URL);
