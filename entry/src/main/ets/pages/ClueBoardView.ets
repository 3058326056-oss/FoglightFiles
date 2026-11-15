/**
 * ClueBoardView.ets
 * ③ 线索板：9 张线索卡（按全部 / 已获得 / 未获得 / ★定案筛选）、定案齐备度与关键提示。
 */

import { Clue, DECISIVE_CLUE_IDS, GameState, contains, createNewCase } from '../model/Models';
import { CLUES, clueTitle } from '../model/CaseCatalog';
import { ClueCard } from '../components/ClueCard';
import {
  C_ACCENT, C_ACCENT_SOFT, C_BG, C_CARD, C_INK, C_LINE, C_MUTED, C_OK
} from '../components/UiBus';
import { getViewModel, hasViewModel } from '../viewmodel/AppContext';

@Component
export struct ClueBoardView {
  @StorageLink('stateVersion') @Watch('reload') version: number = 0;
  @State state: GameState = createNewCase(0);
  @State visible: Clue[] = [];
  @State filterIndex: number = 0;

  reload(): void {
    if (!hasViewModel()) {
      return;
    }
    this.state = getViewModel().getState();
    this.visible = this.filterClues();
  }

  aboutToAppear(): void {
    this.reload();
  }

  private filterClues(): Clue[] {
    const out: Clue[] = [];
    for (let i = 0; i < CLUES.length; i++) {
      const clue: Clue = CLUES[i];
      const owned: boolean = contains(this.state.clues, clue.id);
      const decisive: boolean = contains(DECISIVE_CLUE_IDS, clue.id);
      let pass: boolean = true;
      if (this.filterIndex === 1) {
        pass = owned;
      } else if (this.filterIndex === 2) {
        pass = !owned;
      } else if (this.filterIndex === 3) {
        pass = decisive;
      }
      if (pass) {
        out.push(clue);
      }
    }
    return out;
  }

  private setFilter(index: number): void {
    this.filterIndex = index;
    this.visible = this.filterClues();
  }

  private decisiveOwned(): number {
    let count: number = 0;
    for (let i = 0; i < DECISIVE_CLUE_IDS.length; i++) {
      if (contains(this.state.clues, DECISIVE_CLUE_IDS[i])) {
        count += 1;
      }
    }
    return count;
  }

  private missingText(): string {
    const names: string[] = [];
    for (let i = 0; i < DECISIVE_CLUE_IDS.length; i++) {
      const id: string = DECISIVE_CLUE_IDS[i];
      if (!contains(this.state.clues, id)) {
        names.push(clueTitle(id));
      }
    }
    return names.length === 0 ? '三条定案线索齐备，可前往推理台' : '仍缺：' + names.join('、');
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 8 }) {
            Text('证据链 · 定案线索 ' + this.decisiveOwned().toString() + '/3')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(C_INK)
              .width('100%')
            Text(this.missingText())
              .fontSize(12)
              .fontColor(this.decisiveOwned() === 3 ? C_OK : C_ACCENT)
              .width('100%')
            Text('★ 定案线索必须由具体选择取得；若在便签处公开了消息，送修回执所在的取证路径会被关闭。')
              .fontSize(11)
              .fontColor(C_MUTED)
              .lineHeight(18)
              .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor(C_ACCENT_SOFT)
          .borderRadius(12)

          Row({ space: 8 }) {
            this.filterChip(0, '全部')
            this.filterChip(1, '已获得')
            this.filterChip(2, '未获得')
            this.filterChip(3, '★定案')
          }
          .width('100%')

          ForEach(this.visible, (clue: Clue) => {
            ClueCard({
              clueId: clue.id,
              owned: contains(this.state.clues, clue.id),
              decisive: contains(DECISIVE_CLUE_IDS, clue.id)
            })
          }, (clue: Clue) => clue.id + '|' + this.state.clues.length.toString())
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
  filterChip(index: number, label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.filterIndex === index ? '#FFFFFF' : C_MUTED)
      .backgroundColor(this.filterIndex === index ? C_ACCENT : C_CARD)
      .borderRadius(8)
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .border({ width: 1, color: this.filterIndex === index ? C_ACCENT : C_LINE })
      .onClick(() => {
        this.setFilter(index);
      })
  }
}
