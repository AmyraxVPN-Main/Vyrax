import React, { createContext, useContext } from 'react';
import { Liquid } from 'liquid-gooey';

export const SurfaceTheme = createContext('dark');

// Only the silhouette is filtered; text and controls stay sharp and accessible.
export default function Surface({ children, ...props }) {
  const theme = useContext(SurfaceTheme);
  return (
    <Liquid blur={7} contrast={18} fill="var(--liquid)"
      shadow={theme === 'light' ? '0 8px 22px rgba(18,52,44,.13)' : '0 10px 26px rgba(0,0,0,.45)'}
      {...props}>{children}</Liquid>
  );
}
Surface.Item = Liquid.Item;
