/**
 * HeaderBar.ets
 * 全局头部：作品名、当前阶段、线索/事件计数、信任度与阶段进度条。
 * 只接收基本类型 @Prop，避免复杂对象在 ArkUI V1 下的一级观测刷新问题。
 */

import {
  C_ACCENT, C_CARD, C_INK, C_LINE, C_MUTED, C_OK, trustLabel
} from './UiBus';

@Component
export struct HeaderBar {
  @Prop stageLabel: string = '接受调查';
  @Prop percent: number = 0;
  @Prop clueCount: number = 0;
  @Prop totalClues: number = 9;
  @Prop eventCount: number = 0;
  @Prop totalEvents: number = 14;
  @Prop trust: number = 40;

  build() {
    Column({ space: 8 }) {
      Row() {
        Column({ space: 2 }) {
          Text('雾灯档案')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(C_INK)
          Text('CASE_2140 · 钟楼第七盏灯')
            .fontSize(11)
            .fontColor(C_MUTED)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Column({ space: 2 }) {
          Text(this.stageLabel)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(C_ACCENT)
          Text('信任度 ' + this.trust.toString() + ' · ' + trustLabel(this.trust))
            .fontSize(10)
            .fontColor(C_MUTED)
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')

      Row({ space: 10 }) {
        Text('线索 ' + this.clueCount.toString() + '/' + this.totalClues.toString())
          .fontSize(11)
          .fontColor(C_MUTED)
        Text('事件 ' + this.eventCount.toString() + '/' + this.totalEvents.toString())
          .fontSize(11)
          .fontColor(C_MUTED)
        Blank()
        Text(this.percent.toString() + '%')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(C_OK)
      }
      .width('100%')

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(7)
          .borderRadius(4)
          .backgroundColor(C_LINE)
        Row()
          .width(this.percent.toString() + '%')
          .height(7)
          .borderRadius(4)
          .backgroundColor(C_ACCENT)
          .animation({ duration: 320, curve: Curve.EaseOut })
      }
      .width('100%')
      .height(7)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 10 })
    .backgroundColor(C_CARD)
    .border({ width: 1, color: C_LINE })
  }
}
