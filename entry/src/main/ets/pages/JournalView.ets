/**
 * JournalView.ets
 * ⑤ 调查日志页：按时间倒序展示每次有效选择，含事件、选项、获得的线索与时间戳。
 * 日志是持久化证据之一：冷启动恢复后条数与内容应与杀进程前一致。
 */

import { GameState, JournalEntry, createNewCase } from '../model/Models';
import { findEvent } from '../model/CaseCatalog';
import {
  C_ACCENT, C_BG, C_CARD, C_INK, C_LINE, C_MUTED, formatClock
} from '../components/UiBus';
import { getViewModel, hasViewModel } from '../viewmodel/AppContext';

@Component
export struct JournalView {
  @StorageLink('stateVersion') @Watch('reload') version: number = 0;
  @State state: GameState = createNewCase(0);
  @State entries: JournalEntry[] = [];

  reload(): void {
    if (!hasViewModel()) {
      return;
    }
    this.state = getViewModel().getState();
    const reversed: JournalEntry[] = [];
    for (let i = this.state.journal.length - 1; i >= 0; i--) {
      reversed.push(this.state.journal[i]);
    }
    this.entries = reversed;
  }

  aboutToAppear(): void {
    this.reload();
  }

  private eventTitle(id: string): string {
    const event = findEvent(id);
    return event === null ? id : event.title;
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 6 }) {
            Text('调查日志')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(C_INK)
              .width('100%')
            Text('共 ' + this.state.journal.length.toString() +
                 ' 条记录 · 上限 120 条（FIFO）· 每次操作即时写入 Preferences')
              .fontSize(11)
              .fontColor(C_MUTED)
              .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor(C_CARD)
          .borderRadius(12)
          .border({ width: 1, color: C_LINE })

          if (this.entries.length === 0) {
            Column() {
              Text('还没有调查记录')
                .fontSize(14)
                .fontColor(C_MUTED)
              Text('去「探索」页接受委托并作出第一个选择')
                .fontSize(12)
                .fontColor(C_MUTED)
                .margin({ top: 6 })
            }
            .width('100%')
            .padding(30)
            .backgroundColor(C_CARD)
            .borderRadius(12)
          }

          ForEach(this.entries, (entry: JournalEntry) => {
            Column({ space: 7 }) {
              Row() {
                Text('#' + entry.seq.toString())
                  .fontSize(11)
                  .fontColor(C_ACCENT)
                Blank()
                Text(formatClock(entry.timestamp))
                  .fontSize(11)
                  .fontColor(C_MUTED)
              }
              .width('100%')

              Text(this.eventTitle(entry.eventId))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(C_INK)
                .width('100%')

              Text(entry.text)
                .fontSize(12)
                .fontColor(C_MUTED)
                .lineHeight(19)
                .width('100%')

              if (entry.gainedClues.length > 0) {
                Text('获得线索：' + entry.gainedClues.join('、'))
                  .fontSize(11)
                  .fontColor(C_ACCENT)
                  .width('100%')
              }
            }
            .width('100%')
            .padding(14)
            .backgroundColor(C_CARD)
            .borderRadius(12)
            .border({ width: 1, color: C_LINE })
          }, (entry: JournalEntry) => entry.seq.toString() + '-' + entry.eventId)
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
}
