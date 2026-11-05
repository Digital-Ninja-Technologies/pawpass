export function PawOutline({ size = 22, color = "#fff" }: { size?: number; color?: string }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke={color}
      strokeWidth="1.8"
      aria-hidden="true"
    >
      <circle cx="7" cy="10" r="2" />
      <circle cx="17" cy="10" r="2" />
      <circle cx="10" cy="6" r="2" />
      <circle cx="14" cy="6" r="2" />
      <path d="M12 12c-3 0-5 3.5-5 5.5S9 20 12 20s5-.5 5-2.5S15 12 12 12z" />
    </svg>
  );
}

export function PawFilled({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <circle cx="6" cy="10" r="2.2" />
      <circle cx="18" cy="10" r="2.2" />
      <circle cx="9.5" cy="5.5" r="2.2" />
      <circle cx="14.5" cy="5.5" r="2.2" />
      <path d="M12 11.5c-3.2 0-5.5 3.6-5.5 5.8S9 20.5 12 20.5s5.5-1 5.5-3.2-2.3-5.8-5.5-5.8z" />
    </svg>
  );
}

export function PhoneIcon() {
  return (
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <rect x="6" y="2" width="12" height="20" rx="3" />
      <path d="M11 18h2" />
    </svg>
  );
}

export function PlayIcon() {
  return (
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M5 3l14 9-14 9z" />
    </svg>
  );
}
