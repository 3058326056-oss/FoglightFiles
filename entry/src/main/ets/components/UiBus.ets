/**
 * UiBus.ets
 * M5 轻量事件通信：模块级版本号 + AppStorage 广播。
 * 任一页面改变 GameState 后调用 bumpVersion()，所有 @StorageLink('stateVersion')
 * 的组件通过 @Watch('reload') 重新拉取权威状态，避免多份状态副本不一致。
 * 同时集中定义视觉配色与时间格式化，供所有页面复用。
 */

export const C_BG: string = '#F5F3EF';
export const C_CARD: string = '#FFFFFF';
export const C_INK: string = '#2F3E4E';
export const C_MUTED: string = '#7A7A72';
export const C_ACCENT: string = '#B4782D';
export const C_ACCENT_SOFT: string = '#F6EAD8';
export const C_LINE: string = '#E3DED4';
export const C_OK: string = '#3F7D5C';
export const C_WARN: string = '#B0473C';
export const C_LOCK: string = '#9A9A94';

let version: number = 0;

export function bumpVersion(): void {
  version += 1;
  AppStorage.setOrCreate('stateVersion', version);
}

/** 时间戳转本地 HH:mm:ss；不依赖第三方库。 */
export function formatClock(ts: number): string {
  const d: Date = new Date(ts);
  const h: number = d.getHours();
  const m: number = d.getMinutes();
  const s: number = d.getSeconds();
  const hh: string = (h < 10 ? '0' : '') + h.toString();
  const mm: string = (m < 10 ? '0' : '') + m.toString();
  const ss: string = (s < 10 ? '0' : '') + s.toString();
  return hh + ':' + mm + ':' + ss;
}

/** 信任度分档文案，用于关键状态提示。 */
export function trustLabel(trust: number): string {
  if (trust >= 75) {
    return '受访者愿意开口';
  }
  if (trust >= 45) {
    return '尚可沟通';
  }
  return '证词谨慎';
}
