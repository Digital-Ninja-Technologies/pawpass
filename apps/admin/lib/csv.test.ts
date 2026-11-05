import { describe, expect, it } from "vitest";
import { toCsv } from "./csv";

describe("toCsv", () => {
  it("quotes commas, quotes and newlines", () => {
    expect(
      toCsv(
        ["a", "b"],
        [
          ["x,y", 'say "hi"'],
          ["line\nbreak", 5],
        ],
      ),
    ).toBe('a,b\r\n"x,y","say ""hi"""\r\n"line\nbreak",5\r\n');
  });
  it("renders empty values as blanks", () => {
    expect(toCsv(["a"], [[null], [undefined]])).toBe("a\r\n\r\n\r\n");
  });
  it("neutralises spreadsheet formulas", () => {
    expect(toCsv(["a"], [['=HYPERLINK("x")'], ["+1"], ["@cmd"], ["-2"]])).toBe(
      'a\r\n"\'=HYPERLINK(""x"")"\r\n\'+1\r\n\'@cmd\r\n\'-2\r\n',
    );
  });
});
