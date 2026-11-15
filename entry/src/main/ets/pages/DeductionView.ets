/**
 * DeductionView.ets
 * ④ 推理验证页：组装三项断言 → 验证推理条件（ready / 缺失线索 / 错误项）→ 提交最终判断。
 * 条件不足仍允许提交，但会进入残缺结局，用于演示边界并给出明确反馈。
 */

import {
  GameState, Hypothesis, Motive, Suspect, Timeline, Verdict,
  DECISIVE_CLUE_IDS, contains, createNewCase
} from '../model/Models';
import { clueTitle } from '../model/CaseCatalog';
import {
  bumpVersion, C_ACCENT, C_ACCENT_SOFT, C_BG, C_CARD, C_INK, C_LINE, C_MUTED, C_OK, C_WARN
} from '../components/UiBus';
import { getViewModel, hasViewModel } from '../viewmodel/AppContext';

const SUSPECT_OPTIONS: string[][] = [
  ['president', '社长'], ['lin', '林学姐'], ['zhou', '小周']
];
const MOTIVE_OPTIONS: string[][] = [
  ['grade', '改评优名单'], ['theft', '贪图奖杯'], ['prank', '恶作剧']
];
const TIMELINE_OPTIONS: string[][] = [
  ['2140', '21:40 人为拉闸'], ['2138', '21:38 自然故障'], ['unknown', '无法判断']
];

@Component
export struct DeductionView {
  @StorageLink('stateVersion') @Watch('reload') version: number = 0;
  @State state: GameState = createNewCase(0);
  @State hypothesis: Hypothesis = { suspect: '', motive: '', timeline: '' };
  @State verdictShown: boolean = false;
  @State verdictReady: boolean = false;
  @State verdictHint: string = '';
  @State verdictErrors: string[] = [];
  @State verdictMissing: string[] = [];

  reload(): void {
    if (!hasViewModel()) {
      return;
    }
    this.state = getViewModel().getState();
    const saved: Hypothesis | null = this.state.hypothesis;
    if (saved !== null) {
      this.hypothesis = { suspect: saved.suspect, motive: saved.motive, timeline: saved.timeline };
    }
  }

  aboutToAppear(): void {
    this.reload();
  }

  private async saveHypothesis(next: Hypothesis): Promise<void> {
    this.hypothesis = next;
    this.verdictShown = false;
    if (hasViewModel()) {
      await getViewModel().setHypothesis(next);
    }
  }

  private verify(): void {
    if (!hasViewModel()) {
      return;
    }
    const verdict: Verdict = getViewModel().getVerdict(this.hypothesis);
    this.verdictReady = verdict.ready;
    this.verdictHint = verdict.hint;
    this.verdictErrors = verdict.errors;
    this.verdictMissing = verdict.missingClues;
    this.verdictShown = true;
  }

  private async submit(): Promise<void> {
    if (!hasViewModel()) {
      return;
    }
    await getViewModel().submitVerdict(this.hypothesis);
    bumpVersion();
  }

  private decisiveState(id: string): string {
    return contains(this.state.clues, id) ? '已获得' : '缺失';
  }

  /**
   * @Builder 的普通参数不是响应式的：选中态必须直接读 @State hypothesis，
   * 否则点击选项后高亮不刷新（值虽已保存，视觉却看不出来）。
   */
  private selectedOf(group: number): string {
    if (group === 1) {
      return this.hypothesis.suspect;
    }
    if (group === 2) {
      return this.hypothesis.motive;
    }
    return this.hypothesis.timeline;
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 6 }) {
            Text('推理台 · 验证推理条件')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(C_INK)
              .width('100%')
            Text('先验证证据链是否闭合，再写下最终判断。缺少定案线索或时间线未固定时，提交会得到残缺结局。')
              .fontSize(12)
              .fontColor(C_MUTED)
              .lineHeight(19)
              .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor(C_ACCENT_SOFT)
          .borderRadius(12)

          Column({ space: 6 }) {
            Text('定案线索清单')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(C_INK)
              .width('100%')
            ForEach(DECISIVE_CLUE_IDS, (id: string) => {
              Row() {
                Text(clueTitle(id))
                  .fontSize(12)
                  .fontColor(C_INK)
                  .layoutWeight(1)
                Text(this.decisiveState(id))
                  .fontSize(11)
                  .fontColor(this.decisiveState(id) === '已获得' ? C_OK : C_WARN)
              }
              .width('100%')
            }, (id: string) => id)
            Text('时间线 ' + (this.state.flags['timeline_fixed'] === true ? '已固定' : '未固定'))
              .fontSize(11)
              .fontColor(this.state.flags['timeline_fixed'] === true ? C_OK : C_WARN)
              .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor(C_CARD)
          .borderRadius(12)
          .border({ width: 1, color: C_LINE })

          this.selectorBlock('指认对象', SUSPECT_OPTIONS, 1)
          this.selectorBlock('动机', MOTIVE_OPTIONS, 2)
          this.selectorBlock('断电时间线', TIMELINE_OPTIONS, 3)

          if (this.verdictShown) {
            Column({ space: 8 }) {
              Text(this.verdictReady ? '证据链已闭合' : '证据链尚未闭合')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.verdictReady ? C_OK : C_WARN)
                .width('100%')
              Text(this.verdictHint)
                .fontSize(12)
                .fontColor(C_INK)
                .width('100%')
              ForEach(this.verdictErrors, (err: string) => {
                Text('· ' + err)
                  .fontSize(11)
                  .fontColor(C_WARN)
                  .width('100%')
              }, (err: string) => err)
              ForEach(this.verdictMissing, (id: string) => {
                Text('· 缺少 ' + clueTitle(id))
                  .fontSize(11)
                  .fontColor(C_WARN)
                  .width('100%')
              }, (id: string) => id)
            }
            .width('100%')
            .padding(14)
            .backgroundColor(this.verdictReady ? '#EAF3EC' : '#FBECEA')
            .borderRadius(12)
            .transition(TransitionEffect.OPACITY)
          }

          Row({ space: 10 }) {
            Button('验证推理条件')
              .layoutWeight(1)
              .height(42)
              .fontSize(13)
              .backgroundColor(C_CARD)
              .fontColor(C_ACCENT)
              .border({ width: 1, color: C_ACCENT })
              .onClick(() => {
                this.verify();
              })
            Button('提交最终判断')
              .layoutWeight(1)
              .height(42)
              .fontSize(13)
              .backgroundColor(C_ACCENT)
              .fontColor('#FFFFFF')
              .onClick(() => {
                void this.submit();
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C_BG)
  }

  @Builder
  selectorBlock(title: string, options: string[][], group: number) {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(C_INK)
        .width('100%')
      ForEach(options, (option: string[]) => {
        Text(option[1])
          .fontSize(12)
          .fontColor(this.selectedOf(group) === option[0] ? '#FFFFFF' : C_INK)
          .width('100%')
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor(this.selectedOf(group) === option[0] ? C_ACCENT : C_CARD)
          .borderRadius(8)
          .border({ width: 1, color: this.selectedOf(group) === option[0] ? C_ACCENT : C_LINE })
          .onClick(() => {
            const next: Hypothesis = {
              suspect: group === 1 ? option[0] as Suspect : this.hypothesis.suspect,
              motive: group === 2 ? option[0] as Motive : this.hypothesis.motive,
              timeline: group === 3 ? option[0] as Timeline : this.hypothesis.timeline
            };
            void this.saveHypothesis(next);
          })
      }, (option: string[]) => option[0] + '|' + this.selectedOf(group))
    }
    .width('100%')
    .padding(14)
    .backgroundColor(C_CARD)
    .borderRadius(12)
    .border({ width: 1, color: C_LINE })
  }
}
