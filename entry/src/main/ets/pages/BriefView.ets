/**
 * BriefView.ets
 * ① 简报页：案件简介、五阶段进度、关键状态提示、存档信息与重开入口。
 */

import { GameState, Progress, createNewCase } from '../model/Models';
import { bumpVersion, C_ACCENT, C_ACCENT_SOFT, C_BG, C_CARD, C_INK, C_LINE, C_MUTED, formatClock } from '../components/UiBus';
import { getViewModel, hasViewModel } from '../viewmodel/AppContext';

function emptyProgress(): Progress {
  return {
    stage: 'BRIEFING', stageLabel: '接受调查', clueCount: 0, totalClues: 9,
    eventCount: 0, totalEvents: 14, percent: 0, hints: []
  };
}

@Component
export struct BriefView {
  @StorageLink('stateVersion') @Watch('reload') version: number = 0;
  @State state: GameState = createNewCase(0);
  @State progress: Progress = emptyProgress();
  onGoExplore: () => void = (): void => {};

  reload(): void {
    if (!hasViewModel()) {
      return;
    }
    this.state = getViewModel().getState();
    this.progress = getViewModel().getProgress();
  }

  aboutToAppear(): void {
    this.reload();
  }

  private stages(): string[] {
    return ['接受调查', '搜集线索', '交叉验证', '最终判断', '案件结案'];
  }

  private isCurrent(label: string): boolean {
    return this.progress.stageLabel === label;
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
          Text('校庆前夜 · 21:40')
            .fontSize(11)
            .fontColor(C_ACCENT)
          Text('钟楼的第七盏灯')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(C_INK)
            .width('100%')
          Text('断电十四分钟，校庆奖杯与评优推荐名单一起消失。你是校刊见习记者，天亮前要交出一份能刊印的结论。三个场景、九条线索、若干会改变后续的选择——先看清证据，再写下名字。')
            .fontSize(13)
            .fontColor(C_MUTED)
            .lineHeight(21)
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(C_CARD)
        .borderRadius(12)
        .border({ width: 1, color: C_LINE })

        Column({ space: 10 }) {
          Text('调查阶段')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(C_INK)
            .width('100%')
          Row({ space: 4 }) {
            ForEach(this.stages(), (label: string, index: number) => {
              Column({ space: 4 }) {
                Text((index + 1).toString())
                  .fontSize(11)
                  .fontColor(this.isCurrent(label) ? '#FFFFFF' : C_MUTED)
                  .width(24)
                  .height(24)
                  .borderRadius(12)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(this.isCurrent(label) ? C_ACCENT : C_ACCENT_SOFT)
                Text(label)
                  .fontSize(10)
                  .fontColor(this.isCurrent(label) ? C_ACCENT : C_MUTED)
              }
              .layoutWeight(1)
            }, (label: string) => label)
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(C_CARD)
        .borderRadius(12)
        .border({ width: 1, color: C_LINE })

        Column({ space: 8 }) {
          Text('关键状态提示')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(C_INK)
            .width('100%')
          ForEach(this.progress.hints, (hint: string) => {
            Row({ space: 8 }) {
              Text('·')
                .fontSize(14)
                .fontColor(C_ACCENT)
              Text(hint)
                .fontSize(12)
                .fontColor(C_INK)
                .layoutWeight(1)
            }
            .width('100%')
          }, (hint: string) => hint)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(C_ACCENT_SOFT)
        .borderRadius(12)

        Column({ space: 6 }) {
          Text('存档状态')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(C_INK)
            .width('100%')
          Text('开局时间 ' + formatClock(this.state.startedAt))
            .fontSize(11)
            .fontColor(C_MUTED)
            .width('100%')
          Text('最近保存 ' + formatClock(this.state.updatedAt))
            .fontSize(11)
            .fontColor(C_MUTED)
            .width('100%')
          Text('调查日志 ' + this.state.journal.length.toString() + ' 条 · 线索 ' +
               this.state.clues.length.toString() + ' 条 · 已查阅事件 ' +
               this.state.completedEvents.length.toString() + ' 个')
            .fontSize(11)
            .fontColor(C_MUTED)
            .width('100%')
          Text('每次操作后即时写入 Preferences，结束进程后重新打开可继续。')
            .fontSize(11)
            .fontColor(C_ACCENT)
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(C_CARD)
        .borderRadius(12)
        .border({ width: 1, color: C_LINE })

        Button(this.state.flags['accepted'] === true ? '继续调查' : '接受调查，前往旧馆')
          .width('100%')
          .height(46)
          .fontSize(15)
          .backgroundColor(C_ACCENT)
          .fontColor('#FFFFFF')
          .borderRadius(10)
          .onClick(() => {
            this.onGoExplore();
          })

        Button('重新开局（清空全部进度）')
          .width('100%')
          .height(40)
          .fontSize(13)
          .backgroundColor(C_CARD)
          .fontColor(C_MUTED)
          .border({ width: 1, color: C_LINE })
          .onClick(() => {
            void this.restart();
          })
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C_BG)
  }
}
