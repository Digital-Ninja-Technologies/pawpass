/** Design tokens from CLAUDE.md. The Flutter app mirrors these in apps/mobile/lib/theme. */
export const colors = {
  ground: "#FFF8F1",
  surface: "#FFFFFF",
  ink: "#1F1A17",
  ink2: "#4A433E",
  muted: "#6B625B",
  border: "#EDE3D9",
  subtle: "#F3EBE2",
  primary: "#0E6B63",
  primarySoft: "#E3F1EE",
  primaryText: "#0B5650",
  warm: "#B4501C",
  warmSoft: "#FFEBD9",
  warmText: "#9A3F0F",
  danger: "#A3261B",
  dangerSoft: "#FDEAE7",
  dot: "#E0662A",
  /** Secondary button outline and dashed photo picker. */
  outline: "#CFC3B7",
  /** Disabled button fill. Text on it is ink2. */
  disabled: "#DCD2C8",
} as const;

export const petTints = ["#F3D9C4", "#DCE7F7", "#F1E8FB", "#CFE6E1"] as const;

/** Course colours: one fun pair per course. `soft` is the card background, `strong` is decoration only (stripes,
 * progress, confetti) and `text` is the dark ink for words on `soft` (passes WCAG AA).
 * The Flutter app mirrors these in apps/mobile/lib/theme/tokens.dart (PawCourseColors). */
export const courseColors = {
  sunny: { label: "Sunny yellow", soft: "#FFE08A", strong: "#F5B300", text: "#5C3D00" },
  coral: { label: "Coral", soft: "#FFD0C4", strong: "#F26B4F", text: "#8A2A14" },
  tangerine: { label: "Tangerine", soft: "#FFD9B0", strong: "#F28C28", text: "#7A3E05" },
  mint: { label: "Mint", soft: "#CFEFE0", strong: "#2FB48A", text: "#0B5040" },
  sky: { label: "Sky blue", soft: "#CFE4FF", strong: "#3E86F5", text: "#123F86" },
  grape: { label: "Grape", soft: "#E4D8FF", strong: "#8B5CF6", text: "#45228F" },
  lime: { label: "Lime", soft: "#E1F2B0", strong: "#8DB81F", text: "#3A5208" },
  rose: { label: "Bubblegum", soft: "#FFD1E3", strong: "#E8508C", text: "#8A1646" },
} as const;

export type CourseColorKey = keyof typeof courseColors;
export const courseColorKeys = Object.keys(courseColors) as CourseColorKey[];
