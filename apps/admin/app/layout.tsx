import type { ReactNode } from "react";

export const metadata = { title: "PawPass Admin" };

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en-NG">
      <body>{children}</body>
    </html>
  );
}
