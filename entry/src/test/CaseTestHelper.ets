/**
 * CaseTestHelper.ets
 * 测试共享夹具：用内存 Mock 输入构造一条完整的「真相路径」状态。
 * 不依赖设备 / 模拟器 / 系统 API，全部经 CaseEngine.applyChoice 真实演算。
 */

import { CaseEngine } from '../main/ets/engine/CaseEngine';
import {
  ChoiceResult, GameState, Hypothesis, createNewCase
} from '../main/ets/model/Models';

/** 正确的最终判断：指认社长、动机为改名单、断电时间线 21:40。 */
export function truthHypothesis(): Hypothesis {
  return { suspect: 'president', motive: 'grade', timeline: '2140' };
}

/** 单步：把事件与选项交给纯引擎，返回演算后的新状态。 */
export function step(engine: CaseEngine, state: GameState, eventId: string,
                     choiceId: string, seq: number): GameState {
  const result: ChoiceResult = engine.applyChoice(state, eventId, choiceId, 1000 + seq, 'j-' + seq.toString());
  return result.state;
}

/**
 * 真相路径 14 步（对应需求说明书第 6 章第 2–7 步）：
 * 全部线索 C1–C9、定案 flag 与信任度都由合法选择产生，不是手工拼状态。
 */
export function playTruthPath(engine: CaseEngine): GameState {
  const path: string[][] = [
    ['E01', 'E01-A'], ['E02', 'E02-A'], ['E03', 'E03-A'], ['E04', 'E04-A'],
    ['E05', 'E05-B'], ['E06', 'E06-A'], ['E07', 'E07-A'], ['E08', 'E08-A'],
    ['E09', 'E09-A'], ['E10', 'E10-A'], ['E11', 'E11-A'], ['E12', 'E12-A'],
    ['E13', 'E13-A'], ['E14', 'E14-A']
  ];
  let state: GameState = createNewCase(1000);
  for (let i = 0; i < path.length; i++) {
    state = step(engine, state, path[i][0], path[i][1], i + 1);
  }
  return state;
}

/** 公开便签的错误分支：证人改口、E09 被锁。 */
export function playExposedNotePath(engine: CaseEngine): GameState {
  let state: GameState = createNewCase(1000);
  state = step(engine, state, 'E01', 'E01-A', 1);
  state = step(engine, state, 'E03', 'E03-A', 2);
  state = step(engine, state, 'E04', 'E04-B', 3);
  state = step(engine, state, 'E05', 'E05-C', 4);
  return state;
}
