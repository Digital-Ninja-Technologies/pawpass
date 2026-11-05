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
