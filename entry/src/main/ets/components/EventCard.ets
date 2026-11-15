/**
 * EventCard.ets
 * 场景事件卡片：显示正文（可由分支切换）、锁定/门槛原因、已完成标记与当前分支可用选项。
 * 点击选项只把 (eventId, choiceId) 回调给 ExploreView，由后者统一调用 ViewModel 并落盘。
 */

import { Choice, EventNode } from '../model/Models';
import { findChoice, findEvent } from '../model/CaseCatalog';
import {
  C_ACCENT, C_ACCENT_SOFT, C_CARD, C_INK, C_LINE, C_LOCK, C_MUTED, C_OK
} from './UiBus';

@Component
export struct EventCard {
  @Prop eventId: string = '';
  @Prop title: string = '';
  @Prop body: string = '';
  @Prop available: boolean = false;
  @Prop reason: string = '';
  @Prop completed: boolean = false;
  @Prop choiceIds: string[] = [];
  onChoose: (eventId: string, choiceId: string) => void =
    (eventId: string, choiceId: string): void => {};

  private choiceText(id: string): string {
    const event: EventNode | null = findEvent(this.eventId);
    if (event === null) {
      return id;
    }
    const choice: Choice | null = findChoice(event, id);
    return choice === null ? id : choice.text;
  }

  private choiceHint(id: string): string {
    const event: EventNode | null = findEvent(this.eventId);
    if (event === null) {
      return '';
    }
    const choice: Choice | null = findChoice(event, id);
    return choice === null ? '' : choice.hint;
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text(this.eventId)
          .fontSize(10)
          .fontColor(C_ACCENT)
          .backgroundColor(C_ACCENT_SOFT)
          .borderRadius(6)
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
        Blank()
        Text(this.completed ? '已查阅' : (this.available ? '可查阅' : '暂不可达'))
          .fontSize(10)
          .fontColor(this.completed ? C_OK : (this.available ? C_ACCENT : C_LOCK))
      }
      .width('100%')

      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.available ? C_INK : C_LOCK)
        .width('100%')

      Text(this.body)
        .fontSize(13)
        .fontColor(C_MUTED)
        .lineHeight(20)
        .width('100%')

      if (!this.available && this.reason.length > 0) {
        Row({ space: 6 }) {
          Text('!')
            .fontSize(11)
            .fontColor(C_ACCENT)
          Text(this.reason)
            .fontSize(11)
            .fontColor(C_ACCENT)
        }
        .width('100%')
        .padding(8)
        .backgroundColor(C_ACCENT_SOFT)
        .borderRadius(8)
      }

      if (this.available) {
        ForEach(this.choiceIds, (choiceId: string) => {
          Column({ space: 3 }) {
            Text(this.choiceText(choiceId))
              .fontSize(13)
              .fontColor(C_INK)
              .width('100%')
            Text(this.choiceHint(choiceId))
              .fontSize(11)
              .fontColor(C_MUTED)
              .width('100%')
          }
          .width('100%')
          .padding(10)
          .backgroundColor('#FAF8F4')
          .borderRadius(10)
          .border({ width: 1, color: C_LINE })
          .onClick(() => {
            this.onChoose(this.eventId, choiceId);
          })
        }, (choiceId: string) => choiceId)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(C_CARD)
    .borderRadius(12)
    .border({ width: 1, color: this.available ? C_ACCENT : C_LINE })
    .opacity(this.completed ? 0.78 : 1)
    .animation({ duration: 240, curve: Curve.EaseOut })
  }
}
