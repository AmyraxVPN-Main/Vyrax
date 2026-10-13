import project from '../../project.json';
import { call, native } from '../bridge.js';
import { projectLinks } from './releases.mjs';

export { project };
export const links = projectLinks(project);
export function openProjectLink(target) {
  if (!Object.hasOwn(links, target)) return Promise.reject(new Error('err.action'));
  if (native) return call('openProjectLink', { target });
  window.open(links[target], '_blank', 'noopener,noreferrer');
  return Promise.resolve(true);
}
