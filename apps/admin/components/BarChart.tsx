export interface Bar {
  label: string;
  value: number;
}

/** Simple accessible bar chart. Each bar has a title (hover) and the data is also in a table for screen readers. */
export function BarChart({ bars, caption }: { bars: Bar[]; caption: string }) {
  const max = Math.max(1, ...bars.map((b) => b.value));
  const top = niceCeil(max);
  const W = 640;
  const H = 220;
  const left = 36;
  const bottom = 26;
  const plotH = H - bottom - 8;
  const slot = (W - left) / Math.max(1, bars.length);
  const ticks = [0, 0.25, 0.5, 0.75, 1].map((t) => Math.round(top * t));

  return (
    <figure style={{ margin: 0 }}>
      <svg viewBox={`0 0 ${W} ${H}`} className="chart" role="img" aria-label={caption}>
        {ticks.map((t) => {
          const y = 8 + plotH - (t / top) * plotH;
          return (
            <g key={t}>
              <line x1={left} x2={W} y1={y} y2={y} stroke="#ede3d9" />
              <text x={left - 6} y={y + 4} textAnchor="end" fontSize="11" fill="#6b625b">
                {t}
              </text>
            </g>
          );
        })}
        {bars.map((b, i) => {
          const h = (b.value / top) * plotH;
          const x = left + i * slot + slot * 0.18;
          const w = slot * 0.64;
          return (
            <g key={b.label + i}>
              <rect x={x} y={8 + plotH - h} width={w} height={Math.max(h, 0)} rx={4} fill="#0e6b63">
                <title>{`${b.label}: ${b.value}`}</title>
              </rect>
              {i % 3 === 0 ? (
                <text x={x + w / 2} y={H - 8} textAnchor="middle" fontSize="11" fill="#6b625b">
                  {b.label}
                </text>
              ) : null}
            </g>
          );
        })}
      </svg>
      <figcaption className="sr-only">{caption}</figcaption>
      <table className="sr-only">
        <caption>{caption}</caption>
        <thead>
          <tr>
            <th>Week starting</th>
            <th>Completed bookings</th>
          </tr>
        </thead>
        <tbody>
          {bars.map((b) => (
            <tr key={b.label}>
              <td>{b.label}</td>
              <td>{b.value}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </figure>
  );
}

/** Rounds up to a tidy axis maximum (4 -> 4, 130 -> 200, 780 -> 800). */
export function niceCeil(n: number): number {
  if (n <= 4) return 4;
  const pow = 10 ** Math.floor(Math.log10(n));
  for (const m of [1, 2, 4, 5, 8, 10]) if (m * pow >= n) return m * pow;
  return 10 * pow;
}
