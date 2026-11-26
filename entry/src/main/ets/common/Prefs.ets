import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { HistoryEntry } from '../model/HashModels';

/** 可选算法（与 hash.hash 支持的算法一致） */
export const ALGO_CODES: string[] = ['md5', 'sha1', 'sha256'];

const TAG = 'Prefs';
const PREF_NAME = 'hashbox_prefs';
const KEY_DEFAULT_ALGO = 'default_algo';
const KEY_SIZE_UNIT = 'size_unit';
const KEY_HISTORY = 'history';
const HISTORY_MAX = 200;

/**
 * 设置与历史记录，基于 Preferences 持久化。
 * 设置项同时写入 AppStorage（defaultAlgo / sizeUnit / historyVersion），
 * 页面通过 @StorageLink 双向读取，修改即时生效。
 */
export class Prefs {
  private static store: preferences.Preferences | undefined = undefined;

  static async init(context: common.Context): Promise<void> {
    try {
      Prefs.store = await preferences.getPreferences(context, PREF_NAME);
      const algo = Prefs.store.getSync(KEY_DEFAULT_ALGO, 'sha256') as string;
      const unit = Prefs.store.getSync(KEY_SIZE_UNIT, 'auto') as string;
      AppStorage.setOrCreate<string>('defaultAlgo', ALGO_CODES.indexOf(algo) >= 0 ? algo : 'sha256');
      AppStorage.setOrCreate<string>('sizeUnit', unit);
      AppStorage.setOrCreate<string>('historyVersion', Date.now().toString());
    } catch (e) {
      console.error(TAG, 'init failed');
    }
  }

  static async setDefaultAlgo(value: string): Promise<void> {
    AppStorage.setOrCreate<string>('defaultAlgo', value);
    try {
      if (Prefs.store !== undefined) {
        await Prefs.store.putSync(KEY_DEFAULT_ALGO, value);
        await Prefs.store.flush();
      }
    } catch (e) {
      console.error(TAG, 'save default algo failed');
    }
  }

  static async setSizeUnit(value: string): Promise<void> {
    AppStorage.setOrCreate<string>('sizeUnit', value);
    try {
      if (Prefs.store !== undefined) {
        await Prefs.store.putSync(KEY_SIZE_UNIT, value);
        await Prefs.store.flush();
      }
    } catch (e) {
      console.error(TAG, 'save size unit failed');
    }
  }

  /** 读取历史记录（JSON 字符串 → 逐字段 typeof 判型，拒绝脏数据） */
  static async getHistory(): Promise<HistoryEntry[]> {
    if (Prefs.store === undefined) {
      return [];
    }
    try {
      const raw = Prefs.store.getSync(KEY_HISTORY, '[]') as string;
      return Prefs.parseHistory(raw);
    } catch (e) {
      console.error(TAG, 'get history failed');
      return [];
    }
  }

  static parseHistory(raw: string): HistoryEntry[] {
    const out: HistoryEntry[] = [];
    if (raw.length === 0) {
      return out;
    }
    let parsed: Object = new Object();
    try {
      parsed = JSON.parse(raw) as Object;
    } catch (e) {
      return out;
    }
    if (!(parsed instanceof Array)) {
      return out;
    }
    const arr = parsed as Array<Object>;
    for (const item of arr) {
      if (item === null || item === undefined) {
        continue;
      }
      const rec = item as Record<string, Object>;
      const f = rec['fileName'];
      const a = rec['algo'];
      const h = rec['hashValue'];
      const s = rec['size'];
      const t = rec['time'];
      if (typeof f !== 'string' || typeof a !== 'string' || typeof h !== 'string') {
        continue;
      }
      if (typeof s !== 'number' || typeof t !== 'number') {
        continue;
      }
      const entry = new HistoryEntry();
      entry.fileName = f;
      entry.algo = a;
      entry.hashValue = h;
      entry.size = s;
      entry.time = t;
      out.push(entry);
    }
    return out;
  }

  static async addHistory(entry: HistoryEntry): Promise<void> {
    try {
      if (Prefs.store === undefined) {
        return;
      }
      const list = await Prefs.getHistory();
      list.unshift(entry);
      const trimmed = list.slice(0, HISTORY_MAX);
      await Prefs.store.putSync(KEY_HISTORY, JSON.stringify(trimmed));
      await Prefs.store.flush();
      AppStorage.setOrCreate<string>('historyVersion', Date.now().toString());
    } catch (e) {
      console.error(TAG, 'add history failed');
    }
  }

  static async removeHistory(index: number): Promise<void> {
    try {
      if (Prefs.store === undefined) {
        return;
      }
      const list = await Prefs.getHistory();
      if (index < 0 || index >= list.length) {
        return;
      }
      list.splice(index, 1);
      await Prefs.store.putSync(KEY_HISTORY, JSON.stringify(list));
      await Prefs.store.flush();
      AppStorage.setOrCreate<string>('historyVersion', Date.now().toString());
    } catch (e) {
      console.error(TAG, 'remove history failed');
    }
  }

  static async clearHistory(): Promise<void> {
    try {
      if (Prefs.store !== undefined) {
        await Prefs.store.putSync(KEY_HISTORY, '[]');
        await Prefs.store.flush();
      }
      AppStorage.setOrCreate<string>('historyVersion', Date.now().toString());
    } catch (e) {
      console.error(TAG, 'clear history failed');
    }
  }
}
