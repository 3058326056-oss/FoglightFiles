/**
 * InMemoryStateRepository.ets
 * M4 纯内存测试替身：零系统依赖、零装饰器。
 * 用一个字符串字段模拟 Preferences 的 JSON 存储，供 Local Unit Test 验证
 * 首次启动、正常恢复、破损回落、备份留档与日志上限。
 */

import {
  GameState, cloneGameState, createNewCase
} from '../model/Models';
import { IStateRepository, sanitizeState } from './IStateRepository';

export class InMemoryStateRepository implements IStateRepository {
  private stored: string = '';
  private backup: string = '';
  private clock: () => number;

  constructor(clock?: () => number) {
    this.clock = clock === undefined ? (): number => 1000 : clock;
  }

  /** 注入任意原始串（合法或破损），用于模拟启动时的持久化内容。 */
  seedCorrupt(raw: string): void {
    this.stored = raw;
    this.backup = '';
  }

  /** 直接注入一个合法状态，用于构造冷启动恢复测试的前置条件。 */
  seedState(state: GameState): void {
    this.stored = JSON.stringify(cloneGameState(state));
    this.backup = '';
  }

  async load(): Promise<GameState> {
    if (this.stored.length === 0) {
      const initial: GameState = createNewCase(this.clock());
      this.stored = JSON.stringify(cloneGameState(initial));
      this.backup = '';
      return cloneGameState(initial);
    }
    const restored: GameState | null = sanitizeState(this.stored);
    if (restored === null) {
      this.backup = this.stored;
      const fallback: GameState = createNewCase(this.clock());
      this.stored = JSON.stringify(cloneGameState(fallback));
      return cloneGameState(fallback);
    }
    this.backup = '';
    this.stored = JSON.stringify(cloneGameState(restored));
    return cloneGameState(restored);
  }

  async save(state: GameState): Promise<void> {
    this.stored = JSON.stringify(cloneGameState(state));
  }

  async clearAll(): Promise<void> {
    const fresh: GameState = createNewCase(this.clock());
    this.stored = JSON.stringify(cloneGameState(fresh));
    this.backup = '';
  }

  async readBackup(): Promise<string> {
    return this.backup;
  }
}
