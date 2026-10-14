// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import { useLayoutEffect,useRef,useState } from 'react';
import { dashboardMetrics } from './dashboard-layout.mjs';
export default function useDashboardMetrics() {
  const ref=useRef(null),[metrics,setMetrics]=useState(()=>dashboardMetrics(0));
  useLayoutEffect(()=>{
    const element=ref.current;if(!element)return;
    const measure=()=>setMetrics(dashboardMetrics(element.getBoundingClientRect().width));measure();
    const observer=new ResizeObserver(measure);observer.observe(element);return()=>observer.disconnect();
  },[]);
  return [ref,metrics];
}
