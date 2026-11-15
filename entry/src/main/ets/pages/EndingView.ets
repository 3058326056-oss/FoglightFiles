/**
 * EndingView.ets
 * ⑥ 结局页：展示由条件判定的结局正文，并回顾本局线索、事件、分支与信任度。
 * 冷启动恢复到已结案的存档时，Index 直接渲染本页，证明结局也可持久化恢复。
 */

import { Ending, GameState, createNewCase } from '../model/Models';
import {
  bumpVersion, C_ACCENT, C_ACCENT_SOFT, C_BG, C_CARD, C_INK, C_LINE, C_MUTED
} from '../components/UiBus';
import { getViewModel, hasViewModel } from '../viewmodel/AppContext';

@Component
export struct EndingView {
  @StorageLink('stateVersion') @Watch('reload') version: number = 0;
  @State state: GameState = createNewCase(0);
  @State title: string = '';
  @State subtitle: string = '';
  @State body: string = '';
  @State flags: string[] = [];

  reload(): void {
    if (!hasViewModel()) {
      return;
    }
    this.state = getViewModel().getState();
    const ending: Ending | null = getViewModel().getEnding();
    if (ending !== null) {
      this.title = ending.title;
      this.subtitle = ending.subtitle;
      this.body = ending.body;
    }
    this.flags = this.branchReview();
  }

  aboutToAppear(): void {
    this.reload();
  }

  private branchReview(): string[] {
    const out: string[] = [];
    if (this.state.flags['exposed_note'] === true) {
      out.push('公开了匿名便签 → 证人改口，取证路径被关闭');
    }
    if (this.state.flags['protected_witness'] === true) {
      out.push('替目击者保密 → 解锁经费单据与送修回执');
    }
    if (this.state.flags['timeline_fixed'] === true) {
      out.push('导出了完整监控片段 → 时间线已固定');
    }
    if (this.state.flags['case_ready'] === true) {
      out.push('在第七盏灯下还原了完整时间线');
    }
    if (this.state.flags['assumed_theft'] === true) {
      out.push('曾按「奖杯失窃」写下过推断');
    }
    if (out.length === 0) {
      out.push('本局没有触发关键分支，证据链较薄弱');
    }
    return out;
  }

  private async restart(): Promise<void> {
    if (!hasViewModel()) {
      return;
    }
    await getViewModel().restartCase();
    bumpVersion();
    this.reload();
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Column({ space: 10 }) {
          Text(this.subtitle)
            .fontSize(11)
            .fontColor(C_ACCENT)
            .width('100%')
          Text(this.title)
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(C_INK)
            .width('100%')
          Text(this.body)
            .fontSize(14)
            .fontColor(C_INK)
            .lineHeight(23)
            .width('100%')
        }
        .width('100%')
        .padding(18)
        .backgroundColor(C_CARD)
        .borderRadius(14)
        .border({ width: 1, color: C_ACCENT })
        .transition(TransitionEffect.OPACITY)

        Column({ space: 8 }) {
          Text('本局回顾')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(C_INK)
            .width('100%')
          Text('线索 ' + this.state.clues.length.toString() + '/9 · 事件 ' +
               this.state.completedEvents.length.toString() + '/14 · 日志 ' +
               this.state.journal.length.toString() + ' 条 · 信任度 ' +
               this.state.trust.toString())
            .fontSize(12)
            .fontColor(C_MUTED)
            .width('100%')
          ForEach(this.flags, (line: string) => {
            Text('· ' + line)
              .fontSize(12)
              .fontColor(C_INK)
              .width('100%')
          }, (line: string) => line)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(C_ACCENT_SOFT)
        .borderRadius(12)

        Column({ space: 6 }) {
          Text('存档已写入 Preferences')
            .fontSize(12)
            .fontColor(C_ACCENT)
            .width('100%')
          Text('结束应用进程后重新打开，会直接回到本结局页；线索、日志与分支回顾逐项一致。')
            .fontSize(11)
            .fontColor(C_MUTED)
            .lineHeight(18)
            .width('100%')
        }
        .width('100%')
        .padding(14)
        .backgroundColor(C_CARD)
        .borderRadius(12)
        .border({ width: 1, color: C_LINE })

        Button('重新开局，换一种选择')
          .width('100%')
          .height(46)
          .fontSize(15)
          .backgroundColor(C_ACCENT)
          .fontColor('#FFFFFF')
          .borderRadius(10)
          .onClick(() => {
            void this.restart();
          })
      }
      .width('100%')
      .padding(18)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C_BG)
  }
}
