/**
 * ExploreView.ets
 * ② 场景探索页：3 个场景切换、事件卡片（含锁定原因与分支变体）、选择交互与结果动画反馈。
 * 选择统一交给 CaseViewModel.choose()，后者完成纯引擎演算与 await 落盘。
 */

import { Availability, Choice, ChoiceResult, EventNode, GameState, Scene, createNewCase } from '../model/Models';
import { SCENES, findScene } from '../model/CaseCatalog';
import { EventCard } from '../components/EventCard';
import {
  bumpVersion, C_ACCENT, C_ACCENT_SOFT, C_BG, C_CARD, C_INK, C_LINE, C_MUTED, C_OK, C_WARN
} from '../components/UiBus';
import { getViewModel, hasViewModel } from '../viewmodel/AppContext';

interface EventViewData {
  eventId: string;
  title: string;
  body: string;
  available: boolean;
  reason: string;
  completed: boolean;
  choiceIds: string[];
}

@Component
export struct ExploreView {
  @StorageLink('stateVersion') @Watch('reload') version: number = 0;
  @State state: GameState = createNewCase(0);
  @State sceneId: string = 'S1';
  @State cards: EventViewData[] = [];
  @State showResult: boolean = false;
  @State lastMessage: string = '';
  @State lastSuccess: boolean = true;

  reload(): void {
    if (!hasViewModel()) {
      return;
    }
    this.state = getViewModel().getState();
    this.sceneId = this.state.currentSceneId;
    this.cards = this.buildCards();
  }

  aboutToAppear(): void {
    this.reload();
  }

  private buildCards(): EventViewData[] {
    const out: EventViewData[] = [];
    if (!hasViewModel()) {
      return out;
    }
    const vm = getViewModel();
    const events: EventNode[] = vm.getSceneEvents(this.sceneId);
    for (let i = 0; i < events.length; i++) {
      const event: EventNode = events[i];
      const availability: Availability = vm.getAvailability(event);
      const choices: Choice[] = vm.getChoices(event);
      const ids: string[] = [];
      for (let j = 0; j < choices.length; j++) {
        ids.push(choices[j].id);
      }
      const data: EventViewData = {
        eventId: event.id,
        title: event.title,
        body: vm.getBody(event),
        available: availability.available,
        reason: availability.reason,
        completed: this.state.completedEvents.indexOf(event.id) >= 0,
        choiceIds: ids
      };
      out.push(data);
    }
    return out;
  }

  private async selectScene(id: string): Promise<void> {
    this.sceneId = id;
    this.cards = this.buildCards();
    this.showResult = false;
    if (hasViewModel()) {
      await getViewModel().selectScene(id);
    }
    this.state = getViewModel().getState();
  }

  private async doChoose(eventId: string, choiceId: string): Promise<void> {
    if (!hasViewModel()) {
      return;
    }
    const result: ChoiceResult = await getViewModel().choose(eventId, choiceId);
    this.lastMessage = result.message;
    this.lastSuccess = result.accepted;
    this.showResult = true;
    bumpVersion();
    this.reload();
  }

  private sceneName(): string {
    const scene = findScene(this.sceneId);
    return scene === null ? '' : scene.name;
  }

  private sceneSubtitle(): string {
    const scene = findScene(this.sceneId);
    return scene === null ? '' : scene.subtitle;
  }

  private sceneDescription(): string {
    const scene = findScene(this.sceneId);
    return scene === null ? '' : scene.description;
  }

  build() {
    Column() {
      if (this.showResult) {
        Column({ space: 6 }) {
          Text(this.lastSuccess ? '调查记录已更新' : '操作未生效')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.lastSuccess ? C_OK : C_WARN)
            .width('100%')
          Text(this.lastMessage)
            .fontSize(12)
            .fontColor(C_INK)
            .width('100%')
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.lastSuccess ? '#EAF3EC' : '#FBECEA')
        .borderRadius(10)
        .transition(TransitionEffect.OPACITY)
      }

      Scroll() {
        Column({ space: 12 }) {
          Row({ space: 8 }) {
            ForEach(SCENES, (scene: Scene) => {
              Text(scene.id)
                .fontSize(12)
                .fontColor(this.sceneId === scene.id ? '#FFFFFF' : C_MUTED)
                .backgroundColor(this.sceneId === scene.id ? C_ACCENT : C_CARD)
                .borderRadius(8)
                .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                .border({ width: 1, color: this.sceneId === scene.id ? C_ACCENT : C_LINE })
                .onClick(() => {
                  void this.selectScene(scene.id);
                })
            }, (scene: Scene) => scene.id)
          }
          .width('100%')

          Column({ space: 6 }) {
            Text(this.sceneName())
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(C_INK)
              .width('100%')
            Text(this.sceneSubtitle())
              .fontSize(11)
              .fontColor(C_ACCENT)
              .width('100%')
            Text(this.sceneDescription())
              .fontSize(12)
              .fontColor(C_MUTED)
              .lineHeight(19)
              .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor(C_ACCENT_SOFT)
          .borderRadius(12)

          ForEach(this.cards, (card: EventViewData) => {
            EventCard({
              eventId: card.eventId,
              title: card.title,
              body: card.body,
              available: card.available,
              reason: card.reason,
              completed: card.completed,
              choiceIds: card.choiceIds,
              onChoose: (eventId: string, choiceId: string): void => {
                void this.doChoose(eventId, choiceId);
              }
            })
          }, (card: EventViewData) => card.eventId + '|' + card.available.toString() + '|' +
               card.completed.toString() + '|' + card.choiceIds.join(',') + '|' +
               card.body.length.toString())
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 24 })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C_BG)
  }
}
