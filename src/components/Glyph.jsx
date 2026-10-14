// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
// Original SVG drawings for Vyrax's compact geometric icon family.
import React from 'react';
const drawings = {
  dashboard:<><rect x="3" y="3" width="7.5" height="9" rx="2.2"/><rect x="13.5" y="3" width="7.5" height="6.5" rx="2.2"/><rect x="3" y="15" width="7.5" height="6" rx="2.2"/><rect x="13.5" y="12.5" width="7.5" height="8.5" rx="2.2"/></>,
  globe:<><circle cx="12" cy="12" r="9"/><ellipse cx="12" cy="12" rx="4" ry="9"/><path d="M3 12h18"/></>,
  profiles:<><path d="M7 3h7l5 5v11a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z"/><path d="M13 3v5h6M9 12h6M9 16h5"/></>,
  connections:<><circle cx="12" cy="5" r="2.5"/><circle cx="5" cy="19" r="2.5"/><circle cx="19" cy="19" r="2.5"/><path d="m11 7-5 9m7-9 5 9M8 19h8"/></>,
  tools:<><rect x="3" y="7" width="18" height="14" rx="3"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 13h18M10 12v3h4v-3"/></>,
  panel:<><rect x="3" y="4" width="18" height="16" rx="3"/><path d="M8 4v16M5.5 8v8"/></>,
  speed:<><path d="M4.5 18a9 9 0 1 1 15 0Z"/><path d="m12 13 4-5"/><circle cx="12" cy="13" r="1"/></>,
  shuffle:<><path d="M3 6h3c4 0 8 12 12 12h3m-4-4 4 4-4 3M3 18h3c1.5 0 3-2 4-4M14 8c1.5-1.5 2.5-2 4-2h3m-4-4 4 4-4 3"/></>,
  shield:<><path d="M12 3c-2.5 1.7-5 2-8 2.5v5.8c0 4.4 3.4 7.2 8 9.7 4.6-2.5 8-5.3 8-9.7V5.5C17 5 14.5 4.7 12 3Z"/><path d="M12 8v8"/></>,
  route:<><path d="M4 4h5l3 5 3-5h5M12 9v12M5 4v5M19 4v5"/></>,
  manual:<><rect x="3" y="4" width="18" height="16" rx="3"/><path d="M8 4v16M11 8h6M11 12h6M11 16h4"/></>,
  zap:<path d="m14 2-9 12h6l-1 8 9-12h-6Z"/>,
  wifi:<><path d="M3 7a15 15 0 0 1 18 0M6 11a10 10 0 0 1 12 0M9 15a5 5 0 0 1 6 0"/><circle cx="12" cy="19" r=".8"/></>,
  devices:<><rect x="3" y="3" width="13" height="13" rx="2.5"/><rect x="14" y="10" width="7" height="11" rx="1.8"/><path d="M6 20h6M9 16v4"/></>,
  pie:<><path d="M10 3a9 9 0 1 0 11 11H10Z"/><path d="M14 3v7h7a8 8 0 0 0-7-7Z"/></>,
  edit:<><path d="m5 16 11-12a2 2 0 0 1 3 3L8 19l-5 2Z"/><path d="m14 6 4 4M5 16l3 3"/></>,
  check:<path d="m5 12 4.5 4.5L20 6"/>,
  info:<><circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7h.01"/></>,
  folder:<path d="M3 7a2 2 0 0 1 2-2h5l2 2h7a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/>,
  refresh:<><path d="M20 9a8 8 0 1 0 0 7M20 3v6h-6"/></>,
  search:<><circle cx="10.5" cy="10.5" r="7.5"/><path d="m16 16 5 5"/></>,
  star:<path d="m12 3 2.8 5.8 6.4.9-4.6 4.5 1.1 6.3-5.7-3-5.7 3 1.1-6.3L2.8 9.7l6.4-.9Z"/>,
  user:<><circle cx="12" cy="8" r="4"/><path d="M4 21v-2a6 6 0 0 1 6-6h4a6 6 0 0 1 6 6v2"/></>,
  gift:<><rect x="3" y="8" width="18" height="5" rx="1.5"/><path d="M5 13v8h14v-8M12 8v13M12 8C5 9 4 3 7 3c3 0 5 5 5 5Zm0 0c7 1 8-5 5-5-3 0-5 5-5 5Z"/></>,
  trash:<><path d="M3 6h18M9 6V3h6v3M6 6l1 15h10l1-15M10 10v7M14 10v7"/></>,
  plus:<path d="M12 4v16M4 12h16"/>,
  copy:<><rect x="8" y="8" width="13" height="13" rx="2.5"/><path d="M5 16H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h11a1 1 0 0 1 1 1v1"/></>,
  qr:<><rect x="3" y="3" width="6" height="6" rx="1"/><rect x="15" y="3" width="6" height="6" rx="1"/><rect x="3" y="15" width="6" height="6" rx="1"/><path d="M15 15h3v3h3v3h-6v-3M12 3v6M3 12h6M12 12h5M12 16v5M21 12v3"/></>,
  clipboard:<><path d="M8 5H5a2 2 0 0 0-2 2v13h18V7a2 2 0 0 0-2-2h-3"/><rect x="8" y="3" width="8" height="5" rx="2"/><path d="M8 12h8M8 16h5"/></>,
  upload:<><path d="M5 14v7h14v-7M12 16V3M7 8l5-5 5 5"/></>,
  language:<><path d="M3 5h12M9 3v2M5 5c1 6 5 9 10 11M13 5c-1 6-5 9-10 11M14 21l4-11 4 11M16 17h4"/></>,
  close:<path d="m6 6 12 12M6 18 18 6"/>,
  chevron:<path d="m9 5 7 7-7 7"/>,
  up:<path d="M12 20V4M6 10l6-6 6 6"/>,
  down:<path d="M12 4v16M6 14l6 6 6-6"/>,
};
export default function Glyph({ name, size=24, filled=false, className='', strokeWidth=1.7, ...props }) {
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={strokeWidth}
    strokeLinecap="round" strokeLinejoin="round" className={`vyrax-glyph ${filled ? 'filled' : ''} ${className}`} aria-hidden="true" {...props}>{drawings[name] || drawings.tools}</svg>;
}
const icon = name => function Icon(props) { return <Glyph name={name} {...props}/>; };
export const Search=icon('search'),RotateCw=icon('refresh'),RefreshCw=RotateCw,Plus=icon('plus'),Check=icon('check'),ChevronRight=icon('chevron'),Star=icon('star'),Trash2=icon('trash'),Zap=icon('zap'),Shuffle=icon('shuffle'),Folder=icon('folder'),Gift=icon('gift'),Globe=icon('globe'),X=icon('close'),ArrowUp=icon('up'),ArrowDown=icon('down');
export const Copy=icon('copy'),QrCode=icon('qr'),ClipboardPaste=icon('clipboard'),FileUp=icon('upload'),Languages=icon('language'),Info=icon('info');
