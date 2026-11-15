/**
 * EntryAbility.ets
 * M6 应用装配与生命周期。
 *
 * 冷启动门禁（EX-04 / B5）：onWindowStageCreate 先置 isReady=false → 加载 Index（只渲染加载态）
 * → loadContent 回调里 void bootstrap() → await vm.restore() → isReady=true → 一次性 hydrate。
 * 保证恢复完成前不渲染业务内容，也不会把默认新案回写覆盖存档。
 * onBackground 兜底 flush()（EX-06）。
 */

import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { promptAction, window } from '@kit.ArkUI';
import { CaseEngine } from '../engine/CaseEngine';
import { InMemoryStateRepository } from '../repository/InMemoryStateRepository';
import { StateRepository } from '../repository/StateRepository';
import { CaseViewModel } from '../viewmodel/CaseViewModel';
import { getViewModel, hasViewModel, setViewModel } from '../viewmodel/AppContext';

const DOMAIN: number = 0x0000;
const TAG: string = 'FoglightAbility';

export default class EntryAbility extends UIAbility {
  private mainWindowStage: window.WindowStage | undefined = undefined;
  private journalSeq: number = 0;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    AppStorage.setOrCreate('isReady', false);
    AppStorage.setOrCreate('restoreFallback', false);
    this.mainWindowStage = windowStage;

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
        AppStorage.setOrCreate('isReady', true);
        return;
      }
      hilog.info(DOMAIN, TAG, '%{public}s', 'loadContent succeeded');
      void this.bootstrap();
    });

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'setColorMode failed: %{public}s', JSON.stringify(err));
    }
  }

  private async bootstrap(): Promise<void> {
    try {
      const repo: StateRepository = new StateRepository(this.context);
      const vm: CaseViewModel = new CaseViewModel(
        repo, new CaseEngine(), (): number => Date.now(), this.createIdGen());
      setViewModel(vm);
      await vm.restore();
      const fallback: boolean = vm.didRestoreFallback();
      AppStorage.setOrCreate('restoreFallback', fallback);
      AppStorage.setOrCreate('isReady', true);
      if (fallback) {
        this.showToast('存档异常，已重新开局');
      }
      hilog.info(DOMAIN, TAG, 'bootstrap finished, fallback=%{public}s', fallback ? 'true' : 'false');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'bootstrap failed: %{public}s', JSON.stringify(err));
      await this.installFallbackViewModel();
      AppStorage.setOrCreate('restoreFallback', true);
      AppStorage.setOrCreate('isReady', true);
      this.showToast('存档异常，已重新开局');
    }
  }

  /** 末位兜底：Preferences 完全不可用时改用纯内存替身，保证应用仍可交互。 */
  private async installFallbackViewModel(): Promise<void> {
    try {
      if (hasViewModel()) {
        return;
      }
      const repo: InMemoryStateRepository = new InMemoryStateRepository((): number => Date.now());
      const vm: CaseViewModel = new CaseViewModel(
        repo, new CaseEngine(), (): number => Date.now(), this.createIdGen());
      setViewModel(vm);
      await vm.restore();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'installFallbackViewModel failed: %{public}s', JSON.stringify(err));
    }
  }

  private createIdGen(): () => string {
    return (): string => {
      this.journalSeq += 1;
      return 'j-' + Date.now().toString() + '-' + this.journalSeq.toString();
    };
  }

  private showToast(message: string): void {
    const stage: window.WindowStage | undefined = this.mainWindowStage;
    if (stage === undefined) {
      return;
    }
    try {
      const options: promptAction.ShowToastOptions = { message: message, duration: 2000 };
      stage.getMainWindowSync().getUIContext().getPromptAction().showToast(options);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'showToast failed: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    void this.flushPending();
  }

  private async flushPending(): Promise<void> {
    try {
      if (hasViewModel()) {
        await getViewModel().flush();
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'flush failed: %{public}s', JSON.stringify(err));
    }
  }
}
