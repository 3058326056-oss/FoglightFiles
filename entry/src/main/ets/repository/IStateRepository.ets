/**
 * IStateRepository.ets
 * M4 持久化抽象：纯接口，零系统依赖、零装饰器。
 * 生产实现 StateRepository.ets 与测试替身 InMemoryStateRepository.ets 均实现此接口。
 */

import { GameState, sanitizeGameState as fromModels } from '../model/Models';

/** 白名单反序列化入口（唯一实现位于 Models.ets，此处仅转发）。 */
export function sanitizeState(raw: string): GameState | null {
  return fromModels(raw);
}

export interface IStateRepository {
  /** 读取状态；空串返回新案，破损串写备份键后回落新案，不抛异常。 */
  load(): Promise<GameState>;
  /** 写入状态；实现方须先克隆并按 MAX_JOURNAL 裁剪日志。 */
  save(state: GameState): Promise<void>;
  /** 清空存档并写入一枚全新案件（用于「重新开局」）。 */
  clearAll(): Promise<void>;
  /** 读取最近一次解析失败的原始串；正常恢复时为空串。 */
  readBackup(): Promise<string>;
}
