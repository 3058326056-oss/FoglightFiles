/**
 * AppContext.ets
 * M5 模块级单例：全局持有唯一的 CaseViewModel 实例。
 * 零系统依赖、零装饰器；EntryAbility 在 bootstrap 中装配，各页面通过 getViewModel 取同一实例。
 */

import { CaseViewModel } from './CaseViewModel';

let current: CaseViewModel | undefined = undefined;

export function setViewModel(vm: CaseViewModel): void {
  current = vm;
}

export function getViewModel(): CaseViewModel {
  const vm: CaseViewModel | undefined = current;
  if (vm === undefined) {
    throw new Error('CaseViewModel 尚未装配，请先调用 setViewModel()');
  }
  return vm;
}

export function hasViewModel(): boolean {
  return current !== undefined;
}

export class AppContext {
  static setViewModel(vm: CaseViewModel): void {
    setViewModel(vm);
  }

  static getViewModel(): CaseViewModel {
    return getViewModel();
  }
}
