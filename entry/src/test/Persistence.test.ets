/**
 * Persistence.test.ets —— 持久化套件（2 条）
 * T11 异常：四类损坏存档回落新案并留备份原文 / T12 正常：冷启动恢复逐字段一致 + 日志 FIFO
 */

import { describe, it, expect } from '@ohos/hypium';
import { CaseEngine } from '../main/ets/engine/CaseEngine';
import {
  GameState, JournalEntry, cloneGameState, createNewCase, sanitizeGameState
} from '../main/ets/model/Models';
import { InMemoryStateRepository } from '../main/ets/repository/InMemoryStateRepository';
import { playTruthPath, truthHypothesis } from './CaseTestHelper';

export default function persistenceTest() {
  describe('casePersistence', () => {
    // T11 异常：坏 JSON / 版本不符 / 目录外线索 id / trust 非数值
    it('T11_corruptSaveFallsBackToNewCase', 0, async () => {
      const repo1: InMemoryStateRepository = new InMemoryStateRepository((): number => 2000);
      repo1.seedCorrupt('{bad json');
      const loaded1: GameState = await repo1.load();
      expect(loaded1.clues.length).assertEqual(0);
      expect(loaded1.endingId).assertEqual('');
      expect(loaded1.schemaVersion).assertEqual(1);
      expect(await repo1.readBackup()).assertEqual('{bad json');
      const again: GameState = await repo1.load();
      expect(JSON.stringify(again)).assertEqual(JSON.stringify(loaded1));

      const badSchema: GameState = cloneGameState(createNewCase(1000));
      badSchema.schemaVersion = 999;
      const badSchemaRaw: string = JSON.stringify(badSchema);
      const repo2: InMemoryStateRepository = new InMemoryStateRepository((): number => 2000);
      repo2.seedCorrupt(badSchemaRaw);
      expect((await repo2.load()).schemaVersion).assertEqual(1);
      expect(await repo2.readBackup()).assertEqual(badSchemaRaw);

      const unknownClue: GameState = cloneGameState(createNewCase(1000));
      unknownClue.clues.push('C99');
      expect(sanitizeGameState(JSON.stringify(unknownClue)) === null).assertEqual(true);

      const nanTrust: GameState = cloneGameState(createNewCase(1000));
      nanTrust.trust = Number.NaN;
      expect(sanitizeGameState(JSON.stringify(nanTrust)) === null).assertEqual(true);
    });

    // T12 正常：构造含 9 线索 / 14 日志 / 1 结局的状态，跨实例恢复逐字段一致
    it('T12_coldStartRestoreConsistency', 0, async () => {
      const engine: CaseEngine = new CaseEngine();
      const played: GameState = playTruthPath(engine);
      played.hypothesis = truthHypothesis();
      played.endingId = 'END_TRUTH';
      const expected: GameState = cloneGameState(played);

      const repo1: InMemoryStateRepository = new InMemoryStateRepository((): number => 1000);
      repo1.seedState(expected);
      const loaded1: GameState = await repo1.load();
      expect(JSON.stringify(loaded1)).assertEqual(JSON.stringify(expected));
      expect(loaded1.clues.length).assertEqual(9);
      expect(loaded1.journal.length).assertEqual(14);
      expect(loaded1.endingId).assertEqual('END_TRUTH');
      expect(loaded1.flags['case_ready']).assertEqual(true);
      expect((await repo1.readBackup()).length).assertEqual(0);

      // 模拟「杀掉进程后新实例读取同一份磁盘串」
      const raw: string = JSON.stringify(expected);
      const repo2: InMemoryStateRepository = new InMemoryStateRepository((): number => 1000);
      repo2.seedCorrupt(raw);
      const loaded2: GameState = await repo2.load();
      expect(JSON.stringify(loaded2)).assertEqual(JSON.stringify(expected));
      expect(engine.deriveStage(loaded2)).assertEqual('ENDING');

      // 日志上限 120 条 FIFO：125 条中保留最新 120 条，首条 seq=6
      const big: GameState = cloneGameState(expected);
      big.journal = [];
      for (let i = 1; i <= 125; i++) {
        const entry: JournalEntry = {
          seq: i, timestamp: 1000 + i, eventId: 'E01', choiceId: 'E01-A',
          text: 'mock', gainedClues: []
        };
        big.journal.push(entry);
      }
      const capped: GameState | null = sanitizeGameState(JSON.stringify(big));
      expect(capped === null).assertEqual(false);
      if (capped !== null) {
        expect(capped.journal.length).assertEqual(120);
        expect(capped.journal[0].seq).assertEqual(6);
        expect(capped.journal[119].seq).assertEqual(125);
      }
    });
  });
}
