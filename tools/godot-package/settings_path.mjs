import {homedir} from 'node:os';
import {posix, win32} from 'node:path';

// Runtime/cache directories remain disposable. Only this local UI preference
// file is shared by the menu and every route process; it carries no game state.
export function settingsPath(env = process.env, {platform = process.platform, home = homedir(), developmentRoot} = {}) {
  const path = platform === 'win32' ? win32 : posix;
  const selected = env.COCS_SETTINGS_PATH;
  if (selected) {
    if (!path.isAbsolute(selected)) throw Error('COCS_SETTINGS_PATH must be absolute');
    return path.normalize(selected);
  }
  if (developmentRoot) {
    if (!path.isAbsolute(developmentRoot)) throw Error('Development settings root must be absolute');
    return path.join(developmentRoot, '.port-runtime', 'local_settings.json');
  }
  const absoluteOr = (value, fallback) => value && path.isAbsolute(value) ? value : fallback;
  const config = platform === 'win32'
    ? absoluteOr(env.APPDATA, path.join(home, 'AppData', 'Roaming'))
    : platform === 'darwin'
      ? path.join(home, 'Library', 'Application Support')
      : absoluteOr(env.XDG_CONFIG_HOME, path.join(home, '.config'));
  return path.join(config, 'cocs-native', 'local_settings.json');
}
