/**
 * ClueCard.ets
 * 线索板卡片：未获得时以灰色剪影呈现，点击展开详情；★ 定案线索有琥珀色标记。
 * 数据由本地目录按 id 查询，组件不持有第二份业务状态。
 */

import { Clue } from '../model/Models';
import { findClue } from '../model/CaseCatalog';
import {
  C_ACCENT, C_ACCENT_SOFT, C_CARD, C_INK, C_LINE, C_LOCK, C_MUTED
} from './UiBus';

@Component
export struct ClueCard {
  @Prop clueId: string = '';
  @Prop owned: boolean = false;
  @Prop decisive: boolean = false;
  @State expanded: boolean = false;

  private clue(): Clue | null {
    return findClue(this.clueId);
  }

  private titleText(): string {
    const clue: Clue | null = this.clue();
    return clue === null ? '' : clue.title;
  }

  private summaryText(): string {
    const clue: Clue | null = this.clue();
    return clue === null ? '' : clue.summary;
  }

  private detailText(): string {
    const clue: Clue | null = this.clue();
    return clue === null ? '' : clue.detail;
  }

  private tagText(): string {
    const clue: Clue | null = this.clue();
    return clue === null ? '' : clue.tag;
  }

  private sceneText(): string {
    const clue: Clue | null = this.clue();
    return clue === null ? '' : clue.fromEventId;
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Text(this.decisive ? '★ 定案' : this.tagText())
          .fontSize(10)
          .fontColor(this.decisive ? C_ACCENT : C_MUTED)
          .backgroundColor(this.decisive ? C_ACCENT_SOFT : '#F0EEE9')
          .borderRadius(6)
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })

        Blank()

        Text(this.owned ? '已获得' : '未获得')
          .fontSize(10)
          .fontColor(this.owned ? '#3F7D5C' : C_LOCK)
      }
      .width('100%')

      Text(this.owned ? this.titleText() : '尚未发现的线索')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.owned ? C_INK : C_LOCK)
        .width('100%')

      Text(this.owned ? this.summaryText() : '继续在场景中调查，或检查之前的选择是否关闭了取证路径')
        .fontSize(12)
        .fontColor(C_MUTED)
        .width('100%')

      if (this.expanded && this.owned) {
        Column({ space: 6 }) {
          Text(this.detailText())
            .fontSize(12)
            .fontColor(C_INK)
            .width('100%')
          Text('来源事件 ' + this.sceneText())
            .fontSize(10)
            .fontColor(C_MUTED)
            .width('100%')
        }
        .width('100%')
        .padding(10)
        .backgroundColor('#FAF8F4')
        .borderRadius(8)
        .transition(TransitionEffect.OPACITY)
      }

      Text(this.expanded ? '收起详情' : '查看线索详情')
        .fontSize(11)
        .fontColor(C_ACCENT)
        .width('100%')
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(C_CARD)
    .borderRadius(12)
    .border({ width: 1, color: this.decisive && this.owned ? C_ACCENT : C_LINE })
    .onClick(() => {
      this.expanded = !this.expanded;
    })
  }
}
