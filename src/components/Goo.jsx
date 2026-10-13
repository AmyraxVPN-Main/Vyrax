import React from 'react';

/* فیلتر «چسبناک» استاندارد SVG: بلور + تقویت آلفا، و بعد برش با شکل اصلی.
   دو شکلِ نزدیک به هم آب می‌شوند و یک تودهٔ یکدست می‌سازند. */
export function GooFilter({ id, w, h, pad, blur, alpha, offset }) {
  return (
    <defs>
      <filter
        id={id}
        filterUnits="userSpaceOnUse"
        x={-pad}
        y={-pad}
        width={w + pad * 2}
        height={h + pad * 2}
        colorInterpolationFilters="sRGB"
      >
        <feGaussianBlur in="SourceGraphic" stdDeviation={blur} result="blur" />
        <feColorMatrix
          in="blur"
          type="matrix"
          values={`1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 ${alpha} ${offset}`}
          result="goo"
        />
        <feComposite in="SourceGraphic" in2="goo" operator="atop" result="shape" />
      </filter>
    </defs>
  );
}

/* یک لایهٔ چسبناک با یک مستطیل گرد. */
export default function Goo({
  id,
  w,
  h,
  rx,
  x = 0,
  y = 0,
  fill = 'var(--liquid)',
  pad = 45,
  blur = 7,
  alpha = 18,
  offset = -7,
  style
}) {
  return (
    <svg className="goo" aria-hidden="true" focusable="false">
      <GooFilter id={id} w={w} h={h} pad={pad} blur={blur} alpha={alpha} offset={offset} />
      <g filter={`url(#${id})`} style={{ fill }}>
        <rect x={x} y={y} width={w} height={h} rx={rx} style={style} />
      </g>
    </svg>
  );
}
