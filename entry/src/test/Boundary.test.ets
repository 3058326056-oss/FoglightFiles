/**
 * Boundary.test.ets —— 边界与异常套件（3 条）
 * T08 边界：信任度钳制 / T09 边界：重复事件与重复线索 / T10 异常：非法输入被拒绝且不改状态
 */

import { describe, it, expect } from '@ohos/hypium';
import { CaseEngine } from '../main/ets/engine/CaseEngine';
import {
  ChoiceResult, GameState, clampTrust, createNewCase
} from '../main/ets/model/Models';
import { playExposedNotePath, step } from './CaseTestHelper';

export default function boundaryTest() {
  describe('caseBoundary', () => {
    // T08 边界：信任度始终被钳制在 0–100，NaN 归零
    it('T08_trustClampBoundary', 0, () => {
      expect(clampTrust(200)).assertEqual(100);
      expect(clampTrust(-200)).assertEqual(0);
      expect(clampTrust(Number.NaN)).assertEqual(0);
      expect(clampTrust(55)).assertEqual(55);

      const engine: CaseEngine = new CaseEngine();
      const high: GameState = createNewCase(1000);
      high.trust = 98;
      const r1: ChoiceResult = engine.applyChoice(high, 'E01', 'E01-A', 1001, 'j-1');
      expect(r1.state.trust).assertEqual(100);

      const low: GameState = createNewCase(1000);
      low.trust = 2;
      low.flags['accepted'] = true;
      const r2: ChoiceResult = engine.applyChoice(low, 'E06', 'E06-B', 1002, 'j-2');
      expect(r2.state.trust).assertEqual(0);
    });

    // T09 边界：同一事件不可重复完成，同一线索不可重复计数，日志不重复增长
    it('T09_duplicateEventAndClue', 0, () => {
      const engine: CaseEngine = new CaseEngine();
      const fresh: GameState = createNewCase(1000);
      const first: ChoiceResult = engine.applyChoice(fresh, 'E01', 'E01-A', 1001, 'j-1');
      expect(first.accepted).assertEqual(true);

      const again: ChoiceResult = engine.applyChoice(first.state, 'E01', 'E01-A', 1002, 'j-2');
      expect(again.accepted).assertEqual(false);
      expect(again.state.completedEvents.length).assertEqual(1);
      expect(again.state.journal.length).assertEqual(1);
      expect(JSON.stringify(again.state)).assertEqual(JSON.stringify(first.state));

      const secondEvent: ChoiceResult = engine.applyChoice(first.state, 'E02', 'E02-A', 1003, 'j-3');
      expect(secondEvent.accepted).assertEqual(true);
      expect(secondEvent.gainedClues.length).assertEqual(0);
      expect(secondEvent.state.clues.length).assertEqual(first.state.clues.length);
      expect(secondEvent.state.clues.indexOf('C1') >= 0).assertEqual(true);
    });

    // T10 异常：不存在的事件/选项、空日志标识、门槛未满足的选项、已锁定事件
    it('T10_invalidInputsRejectedWithoutMutation', 0, () => {
      const engine: CaseEngine = new CaseEngine();
      const fresh: GameState = createNewCase(1000);
      const before: string = JSON.stringify(fresh);

      const r1: ChoiceResult = engine.applyChoice(fresh, 'E99', 'E01-A', 1001, 'j-1');
      expect(r1.accepted).assertEqual(false);
      expect(JSON.stringify(r1.state)).assertEqual(before);

      const r2: ChoiceResult = engine.applyChoice(fresh, 'E01', 'NO_SUCH_CHOICE', 1002, 'j-2');
      expect(r2.accepted).assertEqual(false);
      expect(JSON.stringify(r2.state)).assertEqual(before);

      const r3: ChoiceResult = engine.applyChoice(fresh, 'E01', 'E01-A', 1003, '');
      expect(r3.accepted).assertEqual(false);
      expect(JSON.stringify(r3.state)).assertEqual(before);

      const withC1: GameState = step(engine, fresh, 'E01', 'E01-A', 4);
      const r4: ChoiceResult = engine.applyChoice(withC1, 'E05', 'E05-C', 1004, 'j-4');
      expect(r4.accepted).assertEqual(false);
      expect(r4.message.length > 0).assertEqual(true);

      const exposed: GameState = playExposedNotePath(engine);
      const r5: ChoiceResult = engine.applyChoice(exposed, 'E09', 'E09-A', 1005, 'j-5');
      expect(r5.accepted).assertEqual(false);
      expect(JSON.stringify(r5.state)).assertEqual(JSON.stringify(exposed));
    });
  });
}
