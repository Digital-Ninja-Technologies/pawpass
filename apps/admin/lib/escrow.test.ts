import { describe, expect, it } from "vitest";
import { statusTone } from "./escrow";

describe("statusTone", () => {
  it("maps escrow states to badge tones", () => {
    expect(statusTone("ready")).toBe("good");
    expect(statusTone("paused")).toBe("warn");
    expect(statusTone("refunded")).toBe("bad");
    expect(statusTone("partially_refunded")).toBe("bad");
    expect(statusTone("held")).toBe("neutral");
  });
});
