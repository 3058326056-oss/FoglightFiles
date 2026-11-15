/**
 * CaseViewModel.ets
 * M5 状态编排层：无装饰器纯 ArkTS 类，持有唯一权威状态 GameState（SSOT）。
 * 零系统依赖，通过构造函数注入 repo / engine / clock / idGen，
 * 因此 Local Unit Test 可在无 ArkUI、无 Kit 运行时完整驱动。
 *
 * 所有写状态路径「同步改内存 + await 串行落盘」，保证杀进程不丢最后一次操作。
 */

import {
  Availability, Choice, ChoiceResult, Ending, EventNode, GameState, Hypothesis,
  Progress, Verdict, SCENE_IDS, contains, cloneGameState, cloneHypothesis, createNewCase
} from '../model/Models';
import { CaseEngine } from '../engine/CaseEngine';
import { IStateRepository } from '../repository/IStateRepository';

export class CaseViewModel {
  private state: GameState = createNewCase(0);
  private repo: IStateRepository;
  private engine: CaseEngine;
  private clock: () => number;
  private idGen: () => string;
  private pendingSave: Promise<void> = Promise.resolve();
  private restoreFallback: boolean = false;

  constructor(repo: IStateRepository, engine: CaseEngine, clock: () => number, idGen: () => string) {
    this.repo = repo;
    this.engine = engine;
    this.clock = clock;
    this.idGen = idGen;
  }

  /** 冷启动恢复：await 读档 → 判定是否回落 → await 落盘。必须在渲染业务页前完成。 */
  async restore(): Promise<void> {
    const loaded: GameState = await this.repo.load();
    const backup: string = await this.repo.readBackup();
    this.restoreFallback = backup.length > 0;
    this.state = cloneGameState(loaded);
    await this.persistNow();
  }

  didRestoreFallback(): boolean {
    return this.restoreFallback;
  }

  /** 返回状态副本，UI 用新对象引用整体赋值给 @State，触发 ArkUI V1 重绘。 */
  getState(): GameState {
    return cloneGameState(this.state);
  }

  getProgress(): Progress {
    return this.engine.getProgress(this.state);
  }

  getAvailability(event: EventNode): Availability {
    return this.engine.checkAvailability(this.state, event);
  }

  getBody(event: EventNode): string {
    return this.engine.resolveBody(this.state, event);
  }

  getChoices(event: EventNode): Choice[] {
    return this.engine.availableChoices(this.state, event);
  }

  getSceneEvents(sceneId: string): EventNode[] {
    return this.engine.sceneEvents(this.state, sceneId);
  }

  getVerdict(hypothesis: Hypothesis): Verdict {
    return this.engine.validateHypothesis(this.state, hypothesis);
  }

  getEnding(): Ending | null {
    if (this.state.endingId.length === 0) {
      return null;
    }
    return this.findEndingById(this.state.endingId);
  }

  private findEndingById(id: string): Ending | null {
    const all: Ending[] = this.engine.listEndings();
    for (let i = 0; i < all.length; i++) {
      if (all[i].id === id) {
        return all[i];
      }
    }
    return null;
  }

  /** 一次选择：纯引擎计算 → 更新 SSOT → await 落盘 → 把结果交给 UI 做动画与 Toast。 */
  async choose(eventId: string, choiceId: string): Promise<ChoiceResult> {
    const result: ChoiceResult = this.engine.applyChoice(
      this.state, eventId, choiceId, this.clock(), this.idGen());
    if (!result.accepted) {
      return result;
    }
    this.state = result.state;
    await this.persistNow();
    return result;
  }

  async selectScene(sceneId: string): Promise<void> {
    if (!contains(SCENE_IDS, sceneId)) {
      return;
    }
    const next: GameState = cloneGameState(this.state);
    next.currentSceneId = sceneId;
    next.updatedAt = this.clock();
    this.state = next;
    await this.persistNow();
  }

  /** 推理台每次调整断言即保存，杀进程恢复后选择仍在。 */
  async setHypothesis(hypothesis: Hypothesis): Promise<void> {
    const next: GameState = cloneGameState(this.state);
    next.hypothesis = cloneHypothesis(hypothesis);
    next.updatedAt = this.clock();
    this.state = next;
    await this.persistNow();
  }

  /** 提交最终判断：按固定优先级得到唯一结局并落盘。 */
  async submitVerdict(hypothesis: Hypothesis): Promise<Ending> {
    const ending: Ending = this.engine.resolveEnding(this.state, hypothesis);
    const next: GameState = cloneGameState(this.state);
    next.hypothesis = cloneHypothesis(hypothesis);
    next.endingId = ending.id;
    next.updatedAt = this.clock();
    this.state = next;
    await this.persistNow();
    return ending;
  }

  /** 重新开局：清空全部线索、flag、日志与结局，并立即写盘。 */
  async restartCase(): Promise<void> {
    this.state = this.engine.createFreshCase(this.clock());
    await this.persistNow();
  }

  /** onBackground 兜底：等待串行写盘链收尾。 */
  async flush(): Promise<void> {
    await this.pendingSave;
  }

  private enqueuePersist(): void {
    const snapshot: GameState = cloneGameState(this.state);
    this.pendingSave = this.pendingSave
      .then((): Promise<void> => this.repo.save(snapshot))
      .catch((): void => {
      });
  }

  private async persistNow(): Promise<void> {
    this.enqueuePersist();
    await this.pendingSave;
  }
}
