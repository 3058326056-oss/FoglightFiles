/**
 * CaseEngine.ets
 * M1 案件推理引擎：纯逻辑、零 @ohos.* 依赖、零装饰器、零副作用。
 *
 * 所有方法都是纯函数：不修改入参、不取系统时间/随机数、不读写持久化、不通知 UI。
 * now / entryId 由调用方注入，保证相同输入必得相同结果，可被 Local Unit Test 直接断言。
 *
 * 负责：事件可用性、变体正文、选择效果、推理条件验证、结局判定、阶段与进度推导。
 */

import {
  Availability, Choice, ChoiceResult, Clue, Effect, EffectKind, Ending, EventNode,
  GameState, Hypothesis, JournalEntry, Progress, Stage, Verdict,
  DECISIVE_CLUE_IDS, contains, capJournal, clampTrust, cloneGameState, cloneStringArray,
  createNewCase, isValidClueId, isValidEventId
} from '../model/Models';
import {
  CLUES, EVENTS, ENDINGS, clueTitle, eventsOfScene, findChoice, findEnding, findEvent
} from '../model/CaseCatalog';

/** 阶段中文名：用显式分支而非对象字面量，满足 ArkTS 静态类型约束。 */
function stageLabelOf(stage: Stage): string {
  if (stage === 'BRIEFING') {
    return '接受调查';
  }
  if (stage === 'SEARCH') {
    return '搜集线索';
  }
  if (stage === 'CROSSCHECK') {
    return '交叉验证';
  }
  if (stage === 'VERDICT') {
    return '最终判断';
  }
  if (stage === 'ENDING') {
    return '案件结案';
  }
  return stage;
}

export class CaseEngine {

  /** 依据线索、flag、锁定表与分支禁令判断一个事件当前是否可达，并给出可读原因。 */
  checkAvailability(state: GameState, event: EventNode): Availability {
    const missingClues: string[] = [];
    const missingFlags: string[] = [];
    let blockedBy: string = '';
    let reason: string = '';

    if (contains(state.completedEvents, event.id)) {
      blockedBy = 'COMPLETED';
      reason = '该事件已查阅';
    } else if (contains(state.lockedEvents, event.id)) {
      blockedBy = 'LOCKED';
      reason = '因之前的选择，这条取证路径已经关闭';
    } else {
      for (let i = 0; i < event.requiresClues.length; i++) {
        const clueId: string = event.requiresClues[i];
        if (!contains(state.clues, clueId)) {
          missingClues.push(clueId);
        }
      }
      for (let i = 0; i < event.requiresFlags.length; i++) {
        const flagKey: string = event.requiresFlags[i];
        if (state.flags[flagKey] !== true) {
          missingFlags.push(flagKey);
        }
      }
      for (let i = 0; i < event.forbiddenFlags.length; i++) {
        if (state.flags[event.forbiddenFlags[i]] === true) {
          blockedBy = 'BRANCH';
          reason = '当前剧情分支下，这件事不会发生';
          break;
        }
      }
      if (blockedBy.length === 0 && (missingClues.length > 0 || missingFlags.length > 0)) {
        blockedBy = 'GATED';
        const parts: string[] = [];
        if (missingClues.length > 0) {
          const names: string[] = [];
          for (let i = 0; i < missingClues.length; i++) {
            names.push(clueTitle(missingClues[i]));
          }
          parts.push('尚缺线索：' + names.join('、'));
        }
        if (missingFlags.length > 0) {
          parts.push('需先完成：' + missingFlags.join('、'));
        }
        reason = parts.join('；');
      }
    }

    const available: boolean = blockedBy.length === 0;
    return {
      available: available,
      missingClues: missingClues,
      missingFlags: missingFlags,
      blockedBy: blockedBy,
      reason: available ? '可查阅' : reason
    };
  }

  /** 当前可查阅的全部事件（已完成 / 已锁定 / 门槛不足的都不返回）。 */
  availableEvents(state: GameState): EventNode[] {
    const out: EventNode[] = [];
    for (let i = 0; i < EVENTS.length; i++) {
      if (this.checkAvailability(state, EVENTS[i]).available) {
        out.push(EVENTS[i]);
      }
    }
    return out;
  }

  /** 场景内全部事件（含锁定与已完成，供 UI 显示原因）。 */
  sceneEvents(state: GameState, sceneId: string): EventNode[] {
    return eventsOfScene(sceneId);
  }

  /** 分支变体：altFlag 命中时显示完全不同的正文，这是「选择改变后续事件」的可见证据。 */
  resolveBody(state: GameState, event: EventNode): string {
    if (event.altFlag.length > 0 && state.flags[event.altFlag] === true) {
      return event.altBody;
    }
    return event.body;
  }

  /** 当前分支下真正可点的选项。 */
  availableChoices(state: GameState, event: EventNode): Choice[] {
    const out: Choice[] = [];
    for (let i = 0; i < event.choices.length; i++) {
      const choice: Choice = event.choices[i];
      let ok: boolean = true;
      for (let j = 0; j < choice.requiresClues.length; j++) {
        if (!contains(state.clues, choice.requiresClues[j])) {
          ok = false;
          break;
        }
      }
      if (!ok) {
        continue;
      }
      for (let j = 0; j < choice.requiresFlags.length; j++) {
        if (state.flags[choice.requiresFlags[j]] !== true) {
          ok = false;
          break;
        }
      }
      if (!ok) {
        continue;
      }
      for (let j = 0; j < choice.forbiddenFlags.length; j++) {
        if (state.flags[choice.forbiddenFlags[j]] === true) {
          ok = false;
          break;
        }
      }
      if (ok) {
        out.push(choice);
      }
    }
    return out;
  }

  private reject(state: GameState, message: string): ChoiceResult {
    return {
      accepted: false,
      state: cloneGameState(state),
      journalEntry: null,
      gainedClues: [],
      unlockedEvents: [],
      message: message
    };
  }

  /**
   * 应用一次选择：校验 → 深拷贝 → 应用 effects → 记日志 → 返回新状态。
   * 任何非法输入都返回 accepted=false，且绝不修改入参。
   */
  applyChoice(state: GameState, eventId: string, choiceId: string,
              now: number, entryId: string): ChoiceResult {
    if (!isValidEventId(eventId)) {
      return this.reject(state, '不存在的事件，操作已忽略');
    }
    const event: EventNode | null = findEvent(eventId);
    if (event === null) {
      return this.reject(state, '不存在的事件，操作已忽略');
    }
    if (entryId.length === 0) {
      return this.reject(state, '缺少日志标识，操作已忽略');
    }
    const availability: Availability = this.checkAvailability(state, event);
    if (!availability.available) {
      return this.reject(state, availability.reason);
    }
    const choice: Choice | null = findChoice(event, choiceId);
    if (choice === null) {
      return this.reject(state, '不存在的选项，操作已忽略');
    }
    const choices: Choice[] = this.availableChoices(state, event);
    let choiceAllowed: boolean = false;
    for (let i = 0; i < choices.length; i++) {
      if (choices[i].id === choiceId) {
        choiceAllowed = true;
        break;
      }
    }
    if (!choiceAllowed) {
      return this.reject(state, '当前分支下该选项不可用');
    }

    const next: GameState = cloneGameState(state);
    const gainedClues: string[] = [];
    const unlockedEvents: string[] = [];

    for (let i = 0; i < choice.effects.length; i++) {
      const effect: Effect = choice.effects[i];
      const kind: EffectKind = effect.kind;
      if (kind === 'ADD_CLUE') {
        if (isValidClueId(effect.key) && !contains(next.clues, effect.key)) {
          next.clues.push(effect.key);
          gainedClues.push(effect.key);
        }
      } else if (kind === 'SET_FLAG') {
        next.flags[effect.key] = effect.boolValue;
      } else if (kind === 'ADJUST_TRUST') {
        next.trust = clampTrust(next.trust + effect.numValue);
      } else if (kind === 'LOCK_EVENT') {
        if (isValidEventId(effect.key) && !contains(next.lockedEvents, effect.key)) {
          next.lockedEvents.push(effect.key);
        }
      } else if (kind === 'UNLOCK_EVENT') {
        const kept: string[] = [];
        for (let j = 0; j < next.lockedEvents.length; j++) {
          if (next.lockedEvents[j] !== effect.key) {
            kept.push(next.lockedEvents[j]);
          } else {
            unlockedEvents.push(effect.key);
          }
        }
        next.lockedEvents = kept;
      }
    }

    if (!contains(next.completedEvents, event.id)) {
      next.completedEvents.push(event.id);
    }

    let seq: number = 1;
    if (next.journal.length > 0) {
      seq = next.journal[next.journal.length - 1].seq + 1;
    }
    const entry: JournalEntry = {
      seq: seq,
      timestamp: now,
      eventId: event.id,
      choiceId: choice.id,
      text: choice.resultText,
      gainedClues: cloneStringArray(gainedClues)
    };
    next.journal.push(entry);
    next.journal = capJournal(next.journal);
    next.updatedAt = now;

    return {
      accepted: true,
      state: next,
      journalEntry: entry,
      gainedClues: gainedClues,
      unlockedEvents: unlockedEvents,
      message: choice.resultText
    };
  }

  /** 推理条件验证：三项选择 + 3 条定案线索 + 时间线固定。 */
  validateHypothesis(state: GameState, hypothesis: Hypothesis): Verdict {
    const errors: string[] = [];
    const missingClues: string[] = [];
    const matchedClues: string[] = [];

    if (hypothesis.suspect.length === 0) {
      errors.push('尚未选择指认对象');
    }
    if (hypothesis.motive.length === 0) {
      errors.push('尚未选择动机');
    }
    if (hypothesis.timeline.length === 0) {
      errors.push('尚未选择断电时间线');
    }
    for (let i = 0; i < DECISIVE_CLUE_IDS.length; i++) {
      const id: string = DECISIVE_CLUE_IDS[i];
      if (contains(state.clues, id)) {
        matchedClues.push(id);
      } else {
        missingClues.push(id);
      }
    }
    if (state.flags['timeline_fixed'] !== true) {
      errors.push('时间线尚未固定，需导出 21:30–22:00 监控片段');
    }

    const ready: boolean = errors.length === 0 && missingClues.length === 0;
    let hint: string = '';
    if (ready) {
      hint = '证据链已闭合，可以提交最终判断';
    } else if (missingClues.length > 0) {
      const names: string[] = [];
      for (let i = 0; i < missingClues.length; i++) {
        names.push(clueTitle(missingClues[i]));
      }
      hint = '仍缺定案线索：' + names.join('、');
    } else {
      hint = '请补全推理台的判断项';
    }
    return {
      ready: ready,
      errors: errors,
      missingClues: missingClues,
      matchedClues: matchedClues,
      hint: hint
    };
  }

  /**
   * 结局判定：按需求说明书 7.4 的固定优先级，命中即返回，结果唯一可复现。
   * 1 指认对象错误 → 误判；2 证人改口 → 断裂；3 完整证据链 → 真相；4 其余 → 残缺。
   */
  resolveEnding(state: GameState, hypothesis: Hypothesis): Ending {
    let id: string = 'END_PARTIAL';
    if (hypothesis.suspect !== 'president') {
      id = 'END_MISJUDGE';
    } else if (state.flags['exposed_note'] === true || state.flags['witness_recanted'] === true) {
      id = 'END_COVER';
    } else {
      const verdict: Verdict = this.validateHypothesis(state, hypothesis);
      const caseReady: boolean = state.flags['case_ready'] === true;
      if (verdict.ready && caseReady && hypothesis.motive === 'grade' && hypothesis.timeline === '2140') {
        id = 'END_TRUTH';
      }
    }
    const ending: Ending | null = findEnding(id);
    if (ending === null) {
      const fallback: Ending | null = findEnding('END_PARTIAL');
      return fallback === null ? ENDINGS[0] : fallback;
    }
    return ending;
  }

  /** 阶段由状态推导，不持久化，避免存档与推导不一致。 */
  deriveStage(state: GameState): Stage {
    if (state.endingId.length > 0) {
      return 'ENDING';
    }
    if (state.flags['accepted'] !== true) {
      return 'BRIEFING';
    }
    if (state.clues.length < 6) {
      return 'SEARCH';
    }
    if (state.flags['timeline_fixed'] !== true) {
      return 'CROSSCHECK';
    }
    return 'VERDICT';
  }

  /** 阶段进度与关键状态提示。 */
  getProgress(state: GameState): Progress {
    const stage: Stage = this.deriveStage(state);
    const clueCount: number = state.clues.length;
    const eventCount: number = state.completedEvents.length;
    const totalClues: number = CLUES.length;
    const totalEvents: number = EVENTS.length;
    const ratio: number = (clueCount / totalClues) * 0.6 + (eventCount / totalEvents) * 0.4;
    let percent: number = Math.round(ratio * 100);
    if (percent > 100) {
      percent = 100;
    }

    const hints: string[] = [];
    if (state.endingId.length > 0) {
      hints.push('案件已结案，可查看结局回顾或重新开局');
    } else if (state.flags['accepted'] !== true) {
      hints.push('先在旧馆接受调查委托');
      hints.push('三个场景可随时切换，锁定事件会写明原因');
    } else {
      if (!contains(state.clues, 'C5')) {
        hints.push('还缺 ★奖杯送修回执：先取得目击者信任，别公开便签');
      }
      if (!contains(state.clues, 'C7')) {
        hints.push('还缺 ★监控日志断点：先到连廊配电间确认跳闸痕迹');
      }
      if (!contains(state.clues, 'C8')) {
        hints.push('还缺 ★备份推荐名单：在连廊消防门后');
      }
      if (state.flags['timeline_fixed'] !== true) {
        hints.push('导出 21:30–22:00 监控片段才能固定时间线');
      }
      if (state.flags['case_ready'] !== true && contains(state.clues, 'C5') &&
          contains(state.clues, 'C8') && state.flags['timeline_fixed'] === true) {
        hints.push('证据链已齐，去「第七盏灯」还原完整时间线');
      }
      if (hints.length === 0) {
        hints.push('条件齐备，可前往推理台验证并提交最终判断');
      }
    }

    const label: string = stageLabelOf(stage);
    return {
      stage: stage,
      stageLabel: label,
      clueCount: clueCount,
      totalClues: totalClues,
      eventCount: eventCount,
      totalEvents: totalEvents,
      percent: percent,
      hints: hints
    };
  }

  /** 重新开局：返回一个全新的、与当前状态无关的案件状态。 */
  createFreshCase(now: number): GameState {
    return createNewCase(now);
  }

  /** 结局目录（供结局页与 ViewModel 查询）。 */
  listEndings(): Ending[] {
    return ENDINGS;
  }

  /** 线索板用：按 id 取线索详情。 */
  clueDetail(id: string): Clue | null {
    for (let i = 0; i < CLUES.length; i++) {
      if (CLUES[i].id === id) {
        return CLUES[i];
      }
    }
    return null;
  }
}
