import React, { createContext, useContext } from 'react';
import { Liquid } from 'liquid-gooey';
import { mobile } from '../bridge.js';

export const SurfaceTheme = createContext('dark');
const LiquidSurface = createContext(false);

// Mobile defaults to compositor transforms. A small surface can opt into the
// desktop renderer when merging silhouettes are part of its interaction.
export function MotionSurface({ children, className='', fill='var(--liquid)', style, blur, contrast, shadow, filterPadding, liquidOnMobile=false, ...props }) {
  if (!mobile || liquidOnMobile) return <LiquidSurface.Provider value={true}><Liquid {...{ className, fill, style, blur, contrast, shadow, filterPadding, ...props }}>{children}</Liquid></LiquidSurface.Provider>;
  return <div {...props} className={`mobile-surface ${className}`} style={{ '--surface-fill':fill, ...style }}>{children}</div>;
}
function SurfaceItem({ children, x=0, y=0, delay=0, className='', style, transition, morph, effect, move, observe, ...props }) {
  const liquid = useContext(LiquidSurface);
  if (!mobile || liquid) return <Liquid.Item {...{ x,y,delay,className,style,transition,morph,effect,move,observe,...props }}>{children}</Liquid.Item>;
  return <div {...props} className={`mobile-surface-item ${className}`} style={{ ...(x || y ? { transform:`translate3d(${x}px,${y}px,0)` } : {}), transitionDelay:`${delay}ms`, ...style }}>{children}</div>;
}
MotionSurface.Item = SurfaceItem;

// Only the silhouette is filtered; text and controls stay sharp and accessible.
export default function Surface({ children, ...props }) {
  const theme = useContext(SurfaceTheme);
  return (
    <MotionSurface blur={7} contrast={18} fill="var(--liquid)"
      shadow={theme === 'light' ? '0 8px 22px rgba(18,52,44,.13)' : '0 10px 26px rgba(0,0,0,.45)'}
      {...props}>{children}</MotionSurface>
  );
}
Surface.Item = SurfaceItem;
