import { importPackage } from '../../preview-engine/src/package/index.js';

export const maximumPreviewPayloadCharacters = 60000;
export const previewFragmentPrefix = '#sw-preview=';

/** URL fragments stay in the browser; consume before asynchronous startup. */
export function consumePreviewFragment(location: Pick<Location, 'hash' | 'pathname' | 'search'>, history: Pick<History, 'replaceState' | 'state'>): string | null {
  if (!location.hash.startsWith(previewFragmentPrefix)) return null;
  const fragment = location.hash;
  history.replaceState(history.state, '', location.pathname + location.search);
  return fragment;
}

export async function importPreviewFragment(fragment: string) {
  const value = fragment.slice(previewFragmentPrefix.length);
  if (!fragment.startsWith(previewFragmentPrefix) || !value.startsWith('v1.')) throw new Error('Unsupported preview link version. Update the ScriptWidget CLI.');
  const payload = value.slice(3);
  if (!payload.length || payload.length > maximumPreviewPayloadCharacters || !/^[A-Za-z0-9_-]+$/.test(payload)) throw new Error('Invalid or oversized preview link. No project was imported.');
  if (payload.length % 4 === 1) throw new Error('Invalid preview link encoding.');
  let bytes: Uint8Array;
  try {
    const binary = atob(payload.replace(/-/g, '+').replace(/_/g, '/'));
    if (btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '') !== payload) throw new Error('Noncanonical encoding');
    bytes = Uint8Array.from(binary, character => character.charCodeAt(0));
  } catch { throw new Error('Invalid preview link encoding.'); }
  const result = await importPackage(bytes);
  if (result.error !== undefined) throw new Error(result.error);
  return result;
}
