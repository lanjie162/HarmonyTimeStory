/**
 * 软键盘控制工具。
 *
 * 背景：HarmonyOS 上 `TextInput` 在控件失焦或路由切换时不保证收起 IME；
 * 表现为创建/保存/跳页后键盘仍浮在屏幕下半，遮挡列表与导航控件，
 * 真人体验差且影响 Hypium 自动化稳定性。
 *
 * 用法：在「提交 / 跳页 / 调起系统弹层」等会改变 UI 的入口首句调用：
 *   import { dismissSoftKeyboard } from '../../common/ime/SoftKeyboard';
 *   dismissSoftKeyboard();
 *
 * 实现选择：使用 `inputMethod.getController().stopInputSession()`，
 * 它在「未弹起 IME」场景下调用是幂等且静默成功的；优于
 * `hideTextInput()`（要求会话已开启，否则可能抛错）。
 */

import inputMethod from '@ohos.inputMethod';

export function dismissSoftKeyboard(): void {
  try {
    // stopInputSession 返回 Promise<boolean>；本工具采用「fire and forget」语义，
    // 同步路径不阻塞调用者，异步异常通过 .catch 兜底，避免 unhandledRejection。
    const p = inputMethod.getController().stopInputSession();
    p.then((_ok: boolean): void => { /* 收键盘成功或本就未弹起 */ })
      .catch((_e: Object): void => { /* 静默忽略 */ });
  } catch (_e) {
  }
}
