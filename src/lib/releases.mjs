// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
export function releaseVersion(value) {
  const match = /^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:\+[0-9A-Za-z.-]+)?$/.exec(String(value || ''));
  if (!match) return null;
  const parts = match.slice(1, 4).map(Number);
  return parts.every(Number.isSafeInteger) ? parts : null;
}

export function compareVersions(a, b) {
  const left = releaseVersion(a), right = releaseVersion(b);
  if (!left || !right) return null;
  for (let i = 0; i < 3; i++) if (left[i] !== right[i]) return left[i] > right[i] ? 1 : -1;
  return 0;
}

export function projectLinks(project) {
  if (!/^[A-Za-z0-9-]+\/[A-Za-z0-9_.-]+$/.test(project.repository)) throw new Error('Invalid project repository');
  const source = `https://github.com/${project.repository}`;
  return { source, release:`${source}/releases/latest`, telegram:project.telegram };
}

export function publishedRelease(release, repository, now = Date.now()) {
  if (!release || release.draft !== false || release.prerelease !== false) return null;
  const published = Date.parse(release.published_at);
  if (!Number.isFinite(published) || published > now || !releaseVersion(release.tag_name)) return null;
  let url;
  try { url = new URL(release.html_url); } catch { return null; }
  const prefix = `/${repository}/releases/tag/`;
  let tag;
  try { tag = decodeURIComponent(url.pathname.slice(prefix.length)); } catch { return null; }
  if (url.origin !== 'https://github.com' || url.username || url.password || url.search || url.hash ||
      !url.pathname.startsWith(prefix) || tag !== release.tag_name) return null;
  return { version:releaseVersion(release.tag_name).join('.'), tag:release.tag_name };
}

export function availableRelease(release, installed, repository, now = Date.now()) {
  const valid = publishedRelease(release, repository, now);
  return valid && compareVersions(valid.version, installed) === 1 ? valid : null;
}

export function shouldNotify(release, dismissedVersion) {
  return !!release && (!releaseVersion(dismissedVersion) || compareVersions(release.version, dismissedVersion) === 1);
}
