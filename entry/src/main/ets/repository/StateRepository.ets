/**
 * StateRepository.ets
 * M4 生产实现：基于 Preferences 的持久化仓储。
 * 本文件是全工程唯一引用 Preferences（ArkData Kit）的位置。
 *
 * 实例名 foglight_state / 主键 game_state / 备用键 game_state_backup / schemaVersion 1。
 * load()：空串 → 新案落盘；破损或版本不符 → 原串写备份键 → 回落新案，不抛异常。
 * save()：先克隆 + 裁剪日志（≤120），再 put + await flush() 后 resolve。
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  GameState, STORAGE_BACKUP_KEY, STORAGE_KEY, STORAGE_NAME,
  cloneGameState, createNewCase
} from '../model/Models';
import { IStateRepository, sanitizeState } from './IStateRepository';

const DOMAIN: number = 0x0000;
const TAG: string = 'FoglightRepository';

export class StateRepository implements IStateRepository {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  private async openStore(): Promise<preferences.Preferences> {
    const options: preferences.Options = { name: STORAGE_NAME };
    try {
      return await preferences.getPreferences(this.context, options);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'openStore failed: %{public}s', JSON.stringify(err));
      throw err as Error;
    }
  }

  private async readRaw(store: preferences.Preferences): Promise<string> {
    try {
      const value: preferences.ValueType = await store.get(STORAGE_KEY, '');
      return typeof value === 'string' ? value : '';
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'readRaw failed: %{public}s', JSON.stringify(err));
      return '';
    }
  }

  private async writeState(store: preferences.Preferences, state: GameState): Promise<void> {
    const copy: GameState = cloneGameState(state);
    const json: string = JSON.stringify(copy);
    try {
      await store.put(STORAGE_KEY, json);
      await store.flush();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'writeState failed: %{public}s', JSON.stringify(err));
      throw err as Error;
    }
  }

  async load(): Promise<GameState> {
    try {
      const store: preferences.Preferences = await this.openStore();
      const raw: string = await this.readRaw(store);

      if (raw.length === 0) {
        const initial: GameState = createNewCase(Date.now());
        await this.writeState(store, initial);
        await store.put(STORAGE_BACKUP_KEY, '');
        await store.flush();
        return cloneGameState(initial);
      }

      const parsed: GameState | null = sanitizeState(raw);
      if (parsed === null) {
        await store.put(STORAGE_BACKUP_KEY, raw);
        await store.flush();
        const fallback: GameState = createNewCase(Date.now());
        await this.writeState(store, fallback);
        hilog.warn(DOMAIN, TAG, '%{public}s', 'game_state corrupted, fallback to new case');
        return cloneGameState(fallback);
      }

      // 合法恢复：清掉历史备份标记，避免每次启动误报「数据异常」。
      await store.put(STORAGE_BACKUP_KEY, '');
      await store.flush();
      return cloneGameState(parsed);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'load failed: %{public}s', JSON.stringify(err));
      return createNewCase(Date.now());
    }
  }

  async save(state: GameState): Promise<void> {
    try {
      const store: preferences.Preferences = await this.openStore();
      await this.writeState(store, state);
    } catch (err) {
      // 写盘失败不阻断内存态与 UI；onBackground 的 flush() 会再试一次。
      hilog.error(DOMAIN, TAG, 'save failed: %{public}s', JSON.stringify(err));
    }
  }

  async clearAll(): Promise<void> {
    const fresh: GameState = createNewCase(Date.now());
    await this.save(fresh);
  }

  async readBackup(): Promise<string> {
    try {
      const store: preferences.Preferences = await this.openStore();
      const value: preferences.ValueType = await store.get(STORAGE_BACKUP_KEY, '');
      return typeof value === 'string' ? value : '';
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'readBackup failed: %{public}s', JSON.stringify(err));
      return '';
    }
  }
}
