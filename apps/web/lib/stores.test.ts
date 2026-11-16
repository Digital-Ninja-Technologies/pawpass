import { describe, expect, it } from "vitest";
import { heroStoresLine, storesNote } from "./stores";

const APP = "https://apps.apple.com/app/id1";
const PLAY = "https://play.google.com/store/apps/details?id=com.ourpawpass.app";

describe("store links", () => {
  it("says nothing extra when both apps are live", () => {
    expect(storesNote(APP, PLAY)).toBeNull();
    expect(heroStoresLine(APP, PLAY)).toBe("Free · iOS and Android");
  });

  it("names the store that is live and the one that is coming", () => {
    expect(storesNote("", PLAY)).toMatch(/Android app is on Google Play.*iPhone app is coming soon/);
    expect(heroStoresLine("", PLAY)).toBe("Free · Android now · iPhone coming soon");
    expect(storesNote(APP, "")).toMatch(/iPhone app is on the App Store.*Android app is coming soon/);
    expect(heroStoresLine(APP, "")).toBe("Free · iPhone now · Android coming soon");
  });

  it("says the apps are not out yet when neither is", () => {
    expect(storesNote("", "")).toMatch(/not in the app stores yet/);
    expect(heroStoresLine("", "")).toBe("Free · iOS and Android · coming soon");
  });

  it("uses no em dashes in what visitors read", () => {
    for (const s of [storesNote("", PLAY), storesNote(APP, ""), storesNote("", ""), heroStoresLine("", PLAY)]) {
      expect(s).not.toContain("—");
    }
  });
});
