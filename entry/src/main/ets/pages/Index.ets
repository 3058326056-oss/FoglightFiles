/**
 * Index.ets
 * 应用唯一 @Entry：冷启动加载态门禁 + 5 页签主容器 + 结案条件渲染。
 *
 * @StorageLink('isReady')：恢复完成前只渲染加载态，杜绝默认新案闪现或被回写覆盖存档。
 * @StorageLink('stateVersion')：任一页面改变状态后广播，本页与所有子视图统一重新拉取 SSOT。
 * endingId 非空时直接渲染 EndingView，保证杀进程重启后仍停留在已达成结局。
 */

import { GameState, Progress, createNewCase } from '../model/Models';
import { HeaderBar } from '../components/HeaderBar';
import { C_ACCENT, C_ACCENT_SOFT, C_BG, C_INK, C_MUTED } from '../components/UiBus';
import { getViewModel, hasViewModel } from '../viewmodel/AppContext';
import { BriefView } from './BriefView';
import { ExploreView } from './ExploreView';
import { ClueBoardView } from './ClueBoardView';
import { DeductionView } from './DeductionView';
import { JournalView } from './JournalView';
import { EndingView } from './EndingView';

function emptyProgress(): Progress {
  return {
    stage: 'BRIEFING', stageLabel: '接受调查', clueCount: 0, totalClues: 9,
    eventCount: 0, totalEvents: 14, percent: 0, hints: []
  };
}

@Entry
@Component
struct Index {
  @StorageLink('isReady') @Watch('onReadyChanged') isReady: boolean = false;
  @StorageLink('restoreFallback') restoreFallback: boolean = false;
  @StorageLink('stateVersion') @Watch('syncFromModel') version: number = 0;
  @State state: GameState = createNewCase(0);
  @State progress: Progress = emptyProgress();
  @State currentTab: number = 0;
  private hydrated: boolean = false;

  aboutToAppear(): void {
    this.tryHydrate();
  }

  onReadyChanged(): void {
    this.tryHydrate();
  }

  private tryHydrate(): void {
    if (!this.isReady || this.hydrated || !hasViewModel()) {
      return;
    }
    this.hydrated = true;
    this.syncFromModel();
  }

  /** 状态变更后整体重新赋值（新对象引用），触发 ArkUI V1 一级观测重绘。 */
  syncFromModel(): void {
    if (!hasViewModel()) {
      return;
    }
    this.state = getViewModel().getState();
    this.progress = getViewModel().getProgress();
  }

  build() {
    Column() {
      if (!this.isReady) {
        Column({ space: 12 }) {
          Text('雾灯档案')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(C_INK)
          Text('正在恢复存档…')
            .fontSize(13)
            .fontColor(C_MUTED)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(C_BG)
      } else if (this.state.endingId.length > 0) {
        EndingView()
      } else {
        Column() {
          HeaderBar({
            stageLabel: this.progress.stageLabel,
            percent: this.progress.percent,
            clueCount: this.progress.clueCount,
            totalClues: this.progress.totalClues,
            eventCount: this.progress.eventCount,
            totalEvents: this.progress.totalEvents,
            trust: this.state.trust
          })

          if (this.restoreFallback) {
            Text('存档异常，已回落为新案件（原数据保留在备份键）')
              .fontSize(11)
              .fontColor(C_ACCENT)
              .width('100%')
              .padding({ left: 16, right: 16, top: 6, bottom: 6 })
              .backgroundColor(C_ACCENT_SOFT)
          }

          Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
            TabContent() {
              BriefView({
                onGoExplore: (): void => {
                  this.currentTab = 1;
                }
              })
            }
            .tabBar('简报')

            TabContent() {
              ExploreView()
            }
            .tabBar('探索')

            TabContent() {
              ClueBoardView()
            }
            .tabBar('线索板')

            TabContent() {
              DeductionView()
            }
            .tabBar('推理')

            TabContent() {
              JournalView()
            }
            .tabBar('日志')
          }
          .barMode(BarMode.Fixed)
          .barHeight(56)
          .layoutWeight(1)
          .width('100%')
          .backgroundColor(C_BG)
          .onChange((index: number) => {
            this.currentTab = index;
            this.syncFromModel();
          })
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C_BG)
  }
}
