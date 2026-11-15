/**
 * Models.ets
 * M2 单一契约源：类型定义、id 白名单、状态纯函数与 JSON 白名单反序列化。
 *
 * 约束：零系统依赖、零装饰器、无 enum、无 any / unknown、无 Map（统一 Record）。
 * 本文件可在无 ArkUI / 无 Kit 运行时的 Local Unit Test 环境直接 import。
 * 所有 id 白名单集中于此，CaseCatalog.ets 只定义内容、不另定义 id 列表，避免循环依赖。
 */

// ======================== 字符串字面量联合 ========================

export type Stage = 'BRIEFING' | 'SEARCH' | 'CROSSCHECK' | 'VERDICT' | 'ENDING';
export type EffectKind = 'ADD_CLUE' | 'SET_FLAG' | 'ADJUST_TRUST' | 'LOCK_EVENT' | 'UNLOCK_EVENT';
export type Suspect = 'president' | 'lin' | 'zhou' | '';
export type Motive = 'grade' | 'theft' | 'prank' | '';
export type Timeline = '2140' | '2138' | 'unknown' | '';

// ======================== 数据实体 ========================

export interface Clue {
  id: string;
  title: string;
  summary: string;
  detail: string;
  sceneId: string;
  tag: string;
  weight: number;
  fromEventId: string;
}

export interface Scene {
  id: string;
  name: string;
  subtitle: string;
  description: string;
  eventIds: string[];
}

/** E5：所有字段显式赋值，避免 ArkTS 下可选字段解析歧义。 */
export interface Effect {
  kind: EffectKind;
  key: string;
  boolValue: boolean;
  numValue: number;
}

export interface Choice {
  id: string;
  text: string;
  hint: string;
  requiresClues: string[];
  requiresFlags: string[];
  forbiddenFlags: string[];
  effects: Effect[];
  resultText: string;
}

export interface EventNode {
  id: string;
  sceneId: string;
  title: string;
  body: string;
  altFlag: string;
  altBody: string;
  requiresClues: string[];
  requiresFlags: string[];
  forbiddenFlags: string[];
  choices: Choice[];
}

export interface JournalEntry {
  seq: number;
  timestamp: number;
  eventId: string;
  choiceId: string;
  text: string;
  gainedClues: string[];
}

export interface Hypothesis {
  suspect: Suspect;
  motive: Motive;
  timeline: Timeline;
}

/** E8：唯一权威状态 SSOT。阶段由引擎推导，不持久化。 */
export interface GameState {
  schemaVersion: number;
  caseId: string;
  startedAt: number;
  updatedAt: number;
  currentSceneId: string;
  clues: string[];
  flags: Record<string, boolean>;
  trust: number;
  completedEvents: string[];
  lockedEvents: string[];
  journal: JournalEntry[];
  hypothesis: Hypothesis | null;
  endingId: string;
}

export interface Availability {
  available: boolean;
  missingClues: string[];
  missingFlags: string[];
  blockedBy: string;
  reason: string;
}

export interface ChoiceResult {
  accepted: boolean;
  state: GameState;
  journalEntry: JournalEntry | null;
  gainedClues: string[];
  unlockedEvents: string[];
  message: string;
}

export interface Verdict {
  ready: boolean;
  errors: string[];
  missingClues: string[];
  matchedClues: string[];
  hint: string;
}

export interface Ending {
  id: string;
  title: string;
  subtitle: string;
  body: string;
  tone: string;
}

export interface Progress {
  stage: Stage;
  stageLabel: string;
  clueCount: number;
  totalClues: number;
  eventCount: number;
  totalEvents: number;
  percent: number;
  hints: string[];
}

// ======================== 冻结常量 ========================

export const SCHEMA_VERSION: number = 1;
export const CASE_ID: string = 'CASE_2140';
export const STORAGE_NAME: string = 'foglight_state';
export const STORAGE_KEY: string = 'game_state';
export const STORAGE_BACKUP_KEY: string = 'game_state_backup';
export const MAX_JOURNAL: number = 120;
export const TRUST_MIN: number = 0;
export const TRUST_MAX: number = 100;
export const INITIAL_TRUST: number = 40;

export const SCENE_IDS: string[] = ['S1', 'S2', 'S3'];
export const CLUE_IDS: string[] = ['C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'C7', 'C8', 'C9'];
export const EVENT_IDS: string[] = [
  'E01', 'E02', 'E03', 'E04', 'E05', 'E06', 'E07',
  'E08', 'E09', 'E10', 'E11', 'E12', 'E13', 'E14'
];
/** 定案线索：推理验证的三项硬条件。 */
export const DECISIVE_CLUE_IDS: string[] = ['C5', 'C7', 'C8'];
export const ENDING_IDS: string[] = ['END_TRUTH', 'END_PARTIAL', 'END_MISJUDGE', 'END_COVER'];
export const SUSPECT_IDS: string[] = ['president', 'lin', 'zhou'];
export const MOTIVE_IDS: string[] = ['grade', 'theft', 'prank'];
export const TIMELINE_IDS: string[] = ['2140', '2138', 'unknown'];

/** flag 白名单：存档恢复时逐键校验，目录外的键视为损坏。 */
export const FLAG_KEYS: string[] = [
  'accepted', 'asked_first', 'registry_checked', 'photo_seen', 'note_kept',
  'exposed_note', 'trust_lin', 'witness_recanted', 'protected_witness',
  'witness_full', 'roster_checked', 'confronted_president', 'scratch_matched',
  'assumed_theft', 'repair_found', 'power_checked', 'timeline_fixed',
  'trail_followed', 'names_diff', 'case_ready'
];

// ======================== 基础纯函数 ========================

export function isFiniteNumber(v: number): boolean {
  return v === v && v !== Infinity && v !== -Infinity;
}

export function clampTrust(v: number): number {
  if (!isFiniteNumber(v)) {
    return TRUST_MIN;
  }
  if (v < TRUST_MIN) {
    return TRUST_MIN;
  }
  if (v > TRUST_MAX) {
    return TRUST_MAX;
  }
  return v;
}

export function contains(list: string[], value: string): boolean {
  for (let i = 0; i < list.length; i++) {
    if (list[i] === value) {
      return true;
    }
  }
  return false;
}

export function isValidClueId(id: string): boolean {
  return contains(CLUE_IDS, id);
}

export function isValidEventId(id: string): boolean {
  return contains(EVENT_IDS, id);
}

// ======================== 深拷贝 / 新建 / 裁剪 ========================

export function cloneStringArray(src: string[]): string[] {
  const out: string[] = [];
  for (let i = 0; i < src.length; i++) {
    out.push(src[i]);
  }
  return out;
}

export function cloneFlags(src: Record<string, boolean>): Record<string, boolean> {
  const out: Record<string, boolean> = {};
  for (let i = 0; i < FLAG_KEYS.length; i++) {
    const key: string = FLAG_KEYS[i];
    const value: boolean | undefined = src[key];
    if (value !== undefined) {
      out[key] = value;
    }
  }
  return out;
}

export function cloneJournalEntry(src: JournalEntry): JournalEntry {
  const out: JournalEntry = {
    seq: src.seq,
    timestamp: src.timestamp,
    eventId: src.eventId,
    choiceId: src.choiceId,
    text: src.text,
    gainedClues: cloneStringArray(src.gainedClues)
  };
  return out;
}

/** FIFO 裁剪：超过 MAX_JOURNAL 时保留最新的 MAX_JOURNAL 条。 */
export function capJournal(src: JournalEntry[]): JournalEntry[] {
  const start: number = src.length > MAX_JOURNAL ? src.length - MAX_JOURNAL : 0;
  const out: JournalEntry[] = [];
  for (let i = start; i < src.length; i++) {
    out.push(cloneJournalEntry(src[i]));
  }
  return out;
}

export function cloneHypothesis(src: Hypothesis | null): Hypothesis | null {
  if (src === null) {
    return null;
  }
  const out: Hypothesis = { suspect: src.suspect, motive: src.motive, timeline: src.timeline };
  return out;
}

export function cloneGameState(src: GameState): GameState {
  const out: GameState = {
    schemaVersion: src.schemaVersion,
    caseId: src.caseId,
    startedAt: src.startedAt,
    updatedAt: src.updatedAt,
    currentSceneId: src.currentSceneId,
    clues: cloneStringArray(src.clues),
    flags: cloneFlags(src.flags),
    trust: clampTrust(src.trust),
    completedEvents: cloneStringArray(src.completedEvents),
    lockedEvents: cloneStringArray(src.lockedEvents),
    journal: capJournal(src.journal),
    hypothesis: cloneHypothesis(src.hypothesis),
    endingId: src.endingId
  };
  return out;
}

export function createNewCase(now: number): GameState {
  const state: GameState = {
    schemaVersion: SCHEMA_VERSION,
    caseId: CASE_ID,
    startedAt: now,
    updatedAt: now,
    currentSceneId: 'S1',
    clues: [],
    flags: {},
    trust: INITIAL_TRUST,
    completedEvents: [],
    lockedEvents: [],
    journal: [],
    hypothesis: null,
    endingId: ''
  };
  return state;
}

export function createEmptyHypothesis(): Hypothesis {
  return { suspect: '', motive: '', timeline: '' };
}

// ======================== JSON.parse 白名单反序列化 ========================

type RawObject = Record<string, Object>;

function asRawObject(value: Object | undefined): RawObject | null {
  if (value === undefined || value === null) {
    return null;
  }
  if (Array.isArray(value) || typeof value !== 'object') {
    return null;
  }
  return value as RawObject;
}

function asRawArray(value: Object | undefined): Object[] | null {
  if (value === undefined || value === null || !Array.isArray(value)) {
    return null;
  }
  return value as Object[];
}

function readNumber(root: RawObject, key: string, fallback: number): number {
  const v: Object | undefined = root[key];
  if (v === undefined || typeof v !== 'number') {
    return fallback;
  }
  const n: number = v as number;
  return isFiniteNumber(n) ? n : fallback;
}

function readString(root: RawObject, key: string, fallback: string): string {
  const v: Object | undefined = root[key];
  if (v === undefined || typeof v !== 'string') {
    return fallback;
  }
  return v as string;
}

function readIdArray(value: Object | undefined, allowed: string[]): string[] | null {
  const arr: Object[] | null = asRawArray(value);
  if (arr === null) {
    return null;
  }
  const out: string[] = [];
  for (let i = 0; i < arr.length; i++) {
    if (typeof arr[i] !== 'string') {
      return null;
    }
    const id: string = arr[i] as string;
    if (!contains(allowed, id)) {
      return null;
    }
    if (!contains(out, id)) {
      out.push(id);
    }
  }
  return out;
}

function readFlags(value: Object | undefined): Record<string, boolean> | null {
  const root: RawObject | null = asRawObject(value);
  if (root === null) {
    return null;
  }
  const out: Record<string, boolean> = {};
  for (let i = 0; i < FLAG_KEYS.length; i++) {
    const key: string = FLAG_KEYS[i];
    const v: Object | undefined = root[key];
    if (v === undefined) {
      continue;
    }
    if (typeof v !== 'boolean') {
      return null;
    }
    out[key] = v as boolean;
  }
  return out;
}

function readJournalEntry(value: Object): JournalEntry | null {
  const root: RawObject | null = asRawObject(value);
  if (root === null) {
    return null;
  }
  const seq: number = readNumber(root, 'seq', -1);
  const timestamp: number = readNumber(root, 'timestamp', -1);
  const eventId: string = readString(root, 'eventId', '');
  const choiceId: string = readString(root, 'choiceId', '');
  const text: string = readString(root, 'text', '');
  const gained: string[] | null = readIdArray(root['gainedClues'], CLUE_IDS);
  if (seq < 1 || timestamp < 0 || !isValidEventId(eventId) || choiceId.length === 0 || gained === null) {
    return null;
  }
  const out: JournalEntry = {
    seq: seq,
    timestamp: timestamp,
    eventId: eventId,
    choiceId: choiceId,
    text: text,
    gainedClues: gained
  };
  return out;
}

function readJournal(value: Object | undefined): JournalEntry[] | null {
  const arr: Object[] | null = asRawArray(value);
  if (arr === null) {
    return null;
  }
  const start: number = arr.length > MAX_JOURNAL ? arr.length - MAX_JOURNAL : 0;
  const out: JournalEntry[] = [];
  for (let i = start; i < arr.length; i++) {
    const entry: JournalEntry | null = readJournalEntry(arr[i]);
    if (entry === null) {
      return null;
    }
    out.push(entry);
  }
  return out;
}

function readHypothesis(value: Object | undefined): Hypothesis | null {
  // 与 createNewCase() 保持一致：未提交过判断时为 null，
  // 否则「损坏回落的新案」与「再次 load 该存档」会产生不同的 hypothesis，破坏幂等。
  if (value === undefined || value === null) {
    return null;
  }
  const root: RawObject | null = asRawObject(value);
  if (root === null) {
    return null;
  }
  const suspect: string = readString(root, 'suspect', '');
  const motive: string = readString(root, 'motive', '');
  const timeline: string = readString(root, 'timeline', '');
  if (suspect !== '' && !contains(SUSPECT_IDS, suspect)) {
    return null;
  }
  if (motive !== '' && !contains(MOTIVE_IDS, motive)) {
    return null;
  }
  if (timeline !== '' && !contains(TIMELINE_IDS, timeline)) {
    return null;
  }
  const out: Hypothesis = {
    suspect: suspect as Suspect,
    motive: motive as Motive,
    timeline: timeline as Timeline
  };
  return out;
}

/**
 * 逐字段重建 GameState，绝不直接 as GameState 信任 JSON.parse 结果。
 * 校验失败返回 null，由仓储层写备份键并回落 createNewCase。
 */
export function sanitizeGameState(raw: string): GameState | null {
  if (raw.length === 0) {
    return null;
  }
  let parsed: Object;
  try {
    parsed = JSON.parse(raw);
  } catch (err) {
    return null;
  }
  const root: RawObject | null = asRawObject(parsed);
  if (root === null) {
    return null;
  }
  if (readNumber(root, 'schemaVersion', -1) !== SCHEMA_VERSION) {
    return null;
  }
  if (readString(root, 'caseId', '') !== CASE_ID) {
    return null;
  }
  const startedAt: number = readNumber(root, 'startedAt', -1);
  const updatedAt: number = readNumber(root, 'updatedAt', -1);
  if (startedAt < 0 || updatedAt < 0) {
    return null;
  }
  const sceneId: string = readString(root, 'currentSceneId', '');
  if (!contains(SCENE_IDS, sceneId)) {
    return null;
  }
  const clues: string[] | null = readIdArray(root['clues'], CLUE_IDS);
  const completed: string[] | null = readIdArray(root['completedEvents'], EVENT_IDS);
  const locked: string[] | null = readIdArray(root['lockedEvents'], EVENT_IDS);
  const flags: Record<string, boolean> | null = readFlags(root['flags']);
  const journal: JournalEntry[] | null = readJournal(root['journal']);
  const hypothesis: Hypothesis | null = readHypothesis(root['hypothesis']);
  if (clues === null || completed === null || locked === null || flags === null ||
      journal === null || hypothesis === null) {
    return null;
  }
  const trust: number = readNumber(root, 'trust', -1);
  if (trust < TRUST_MIN || trust > TRUST_MAX) {
    return null;
  }
  const endingId: string = readString(root, 'endingId', '');
  if (endingId !== '' && !contains(ENDING_IDS, endingId)) {
    return null;
  }
  const state: GameState = {
    schemaVersion: SCHEMA_VERSION,
    caseId: CASE_ID,
    startedAt: startedAt,
    updatedAt: updatedAt,
    currentSceneId: sceneId,
    clues: clues,
    flags: flags,
    trust: trust,
    completedEvents: completed,
    lockedEvents: locked,
    journal: journal,
    hypothesis: hypothesis,
    endingId: endingId
  };
  return state;
}
