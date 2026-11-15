/**
 * CaseEngine.test.ets —— 案件引擎主套件（7 条）
 * T01 正常 / T02 正常 / T03 正常 / T04 正常 / T05 正常 / T06 正常 / T07 边界
 * 全部使用内存 Mock 输入，经 CaseEngine.applyChoice 真实演算，不依赖设备或模拟器。
 */

import { describe, it, expect } from '@ohos/hypium';
import { CaseEngine } from '../main/ets/engine/CaseEngine';
import { findEvent } from '../main/ets/model/CaseCatalog';
import {
  ChoiceResult, EventNode, GameState, Hypothesis, Verdict, createNewCase
} from '../main/ets/model/Models';
import { playExposedNotePath, playTruthPath, step, truthHypothesis } from './CaseTestHelper';

export default function caseEngineTest() {
  describe('caseEngine', () => {
    // T01 正常：接受委托推进阶段并产生第 1 条日志
    it('T01_acceptCaseAdvancesStage', 0, () => {
      const engine: CaseEngine = new CaseEngine();
      const fresh: GameState = createNewCase(1000);
      expect(engine.deriveStage(fresh)).assertEqual('BRIEFING');
      const result: ChoiceResult = engine.applyChoice(fresh, 'E01', 'E01-A', 1001, 'j-1');
      expect(result.accepted).assertEqual(true);
      expect(result.state.flags['accepted']).assertEqual(true);
      expect(result.state.clues.indexOf('C1') >= 0).assertEqual(true);
      expect(result.state.journal.length).assertEqual(1);
      expect(result.state.journal[0].seq).assertEqual(1);
      expect(engine.deriveStage(result.state)).assertEqual('SEARCH');
      expect(engine.getProgress(result.state).stageLabel).assertEqual('搜集线索');
    });

    // T02 正常：线索门槛真实生效（缺 C1 时 E05 不可达，补齐后可达）
    it('T02_clueGateBlocksEvent', 0, () => {
      const engine: CaseEngine = new CaseEngine();
      const event: EventNode | null = findEvent('E05');
      expect(event === null).assertEqual(false);
      if (event === null) {
        return;
      }
      const fresh: GameState = createNewCase(1000);
      const blocked = engine.checkAvailability(fresh, event);
      expect(blocked.available).assertEqual(false);
      expect(blocked.blockedBy).assertEqual('GATED');
      expect(blocked.missingClues.length).assertEqual(1);
      expect(blocked.missingClues[0]).assertEqual('C1');
      const withClue: GameState = step(engine, fresh, 'E01', 'E01-A', 1);
      expect(engine.checkAvailability(withClue, event).available).assertEqual(true);
    });

    // T03 正常：公开便签锁定证据链，并切换后续事件的正文与可选项
    it('T03_exposedNoteLocksEvidenceChain', 0, () => {
      const engine: CaseEngine = new CaseEngine();
      const state: GameState = playExposedNotePath(engine);
      expect(state.flags['exposed_note']).assertEqual(true);
      expect(state.lockedEvents.indexOf('E09') >= 0).assertEqual(true);
      expect(state.trust).assertEqual(35);

      const e05: EventNode | null = findEvent('E05');
      const e08: EventNode | null = findEvent('E08');
      const e09: EventNode | null = findEvent('E09');
      expect(e05 === null || e08 === null || e09 === null).assertEqual(false);
      if (e05 === null || e08 === null || e09 === null) {
        return;
      }
      expect(engine.resolveBody(state, e05)).assertEqual(e05.altBody);
      expect(engine.resolveBody(state, e08)).assertEqual(e08.altBody);
      expect(engine.availableChoices(state, e05).length).assertEqual(1);
      expect(engine.availableChoices(state, e05)[0].id).assertEqual('E05-C');
      expect(engine.checkAvailability(state, e09).blockedBy).assertEqual('LOCKED');
      expect(engine.resolveEnding(state, truthHypothesis()).id).assertEqual('END_COVER');
    });

    // T04 正常：保护证人解锁 E09，取得唯一的 ★送修回执
    it('T04_protectedWitnessUnlocksDecisiveClue', 0, () => {
      const engine: CaseEngine = new CaseEngine();
      let state: GameState = createNewCase(1000);
      state = step(engine, state, 'E01', 'E01-A', 1);
      state = step(engine, state, 'E03', 'E03-A', 2);
      state = step(engine, state, 'E04', 'E04-A', 3);
      state = step(engine, state, 'E06', 'E06-A', 4);
      state = step(engine, state, 'E08', 'E08-A', 5);
      expect(state.flags['protected_witness']).assertEqual(true);
      const e09: EventNode | null = findEvent('E09');
      expect(e09 === null).assertEqual(false);
      if (e09 === null) {
        return;
      }
      expect(engine.checkAvailability(state, e09).available).assertEqual(true);
      const result: ChoiceResult = engine.applyChoice(state, 'E09', 'E09-A', 1006, 'j-6');
      expect(result.accepted).assertEqual(true);
      expect(result.gainedClues.length).assertEqual(1);
      expect(result.gainedClues[0]).assertEqual('C5');
      expect(result.state.clues.indexOf('C5') >= 0).assertEqual(true);
    });

    // T05 正常：完整证据链 + 正确判断 → 真相结局
    it('T05_fullEvidenceChainReachesTruth', 0, () => {
      const engine: CaseEngine = new CaseEngine();
      const state: GameState = playTruthPath(engine);
      expect(state.clues.length).assertEqual(9);
      expect(state.completedEvents.length).assertEqual(14);
      expect(state.flags['timeline_fixed']).assertEqual(true);
      expect(state.flags['case_ready']).assertEqual(true);
      const verdict: Verdict = engine.validateHypothesis(state, truthHypothesis());
      expect(verdict.ready).assertEqual(true);
      expect(verdict.missingClues.length).assertEqual(0);
      expect(verdict.matchedClues.length).assertEqual(3);
      expect(engine.deriveStage(state)).assertEqual('VERDICT');
      expect(engine.getProgress(state).percent).assertEqual(100);
      expect(engine.resolveEnding(state, truthHypothesis()).id).assertEqual('END_TRUTH');
    });

    // T06 正常：指认对象错误优先于真相条件，结局唯一可复现
    it('T06_wrongSuspectOverridesTruth', 0, () => {
      const engine: CaseEngine = new CaseEngine();
      const state: GameState = playTruthPath(engine);
      const wrong: Hypothesis = truthHypothesis();
      wrong.suspect = 'lin';
      expect(engine.resolveEnding(state, wrong).id).assertEqual('END_MISJUDGE');
      const wrong2: Hypothesis = truthHypothesis();
      wrong2.suspect = 'zhou';
      expect(engine.resolveEnding(state, wrong2).id).assertEqual('END_MISJUDGE');
    });

    // T07 边界：证据链不足仍允许提交，明确列出缺口并进入残缺结局
    it('T07_incompleteEvidenceBoundary', 0, () => {
      const engine: CaseEngine = new CaseEngine();
      const fresh: GameState = createNewCase(1000);
      const partial: Hypothesis = { suspect: 'president', motive: '', timeline: '' };
      const verdict: Verdict = engine.validateHypothesis(fresh, partial);
      expect(verdict.ready).assertEqual(false);
      expect(verdict.missingClues.length).assertEqual(3);
      expect(verdict.missingClues[0]).assertEqual('C5');
      expect(verdict.missingClues[1]).assertEqual('C7');
      expect(verdict.missingClues[2]).assertEqual('C8');
      expect(verdict.errors.length > 0).assertEqual(true);
      expect(verdict.hint.length > 0).assertEqual(true);
      expect(engine.resolveEnding(fresh, partial).id).assertEqual('END_PARTIAL');
    });
  });
}
