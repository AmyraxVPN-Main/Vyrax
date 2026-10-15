// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import test from 'node:test';
import assert from 'node:assert/strict';
import { dashboardMetrics,connectionSymbol } from '../src/lib/dashboard-layout.mjs';
test('grid breakpoints follow available card space even with an expanded sidebar',()=>{
  assert.equal(dashboardMetrics(479).columns,2);assert.equal(dashboardMetrics(480).columns,3);
  assert.equal(dashboardMetrics(840).columns,3);assert.equal(dashboardMetrics(841).columns,4);
  assert.equal(dashboardMetrics(1040-48-34).columns,4);assert.equal(dashboardMetrics(1040-200-34).columns,3);
  assert.equal(dashboardMetrics(609-48-34).unit,80);
});
test('card size scales continuously at both ends and remains bounded',()=>{
  assert.equal(dashboardMetrics(600).unit,80);assert.equal(dashboardMetrics(1120).unit,120);
  assert.equal(dashboardMetrics(1121).unit,120);assert.equal(dashboardMetrics(-1).unit,80);
  for(let w=0;w<=1500;w++) {const m=dashboardMetrics(w);assert.ok(m.unit>=80&&m.unit<=120);assert.ok(m.inset>=16&&m.inset<=22);assert.ok(m.radius>=20&&m.radius<=30);}
  assert.ok(Math.abs(dashboardMetrics(601).unit-dashboardMetrics(600).unit)<.1);
});
test('play folds into two vertical pause bars without invalid or out-of-bounds vertices during spring overshoot',()=>{
  for(let p=-.1;p<=1.1;p+=.01) {
    const pieces=connectionSymbol(p);assert.equal(pieces.length,2);
    for(const piece of pieces)for(const point of piece.split(' ')) {const [x,y]=point.split(',').map(Number);assert.ok(Number.isFinite(x)&&Number.isFinite(y));assert.ok(x>=0&&x<=24&&y>=0&&y<=24);}
  }
  const pause=connectionSymbol(1).map(piece=>piece.split(' ').map(point=>point.split(',').map(Number)));
  for(const vertices of pause){const xs=vertices.map(p=>p[0]),ys=vertices.map(p=>p[1]);assert.ok(Math.max(...xs)-Math.min(...xs)<3);assert.equal(Math.max(...ys)-Math.min(...ys),12);}
  assert.notDeepEqual(connectionSymbol(.5),connectionSymbol(0));
});
