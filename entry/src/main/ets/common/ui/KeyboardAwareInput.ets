/**
 * 输入组件键盘收起封装。
 *
 * 背景：HarmonyOS 上 TextInput / TextArea 在控件失焦或路由切换时不保证收起 IME，
 * 表现为键盘遮挡列表与导航控件，影响用户体验与 Hypium 自动化稳定性。
 *
 * 用法：
 *   1) import { TextInputWithKeyboard, TextAreaWithKeyboard } from '../../common/ui/KeyboardAwareInput';
 *   2) 替代原生 TextInput / TextArea：
 *      TextInputWithKeyboard({ placeholder: '名称', value: this.name, onChange: (v) => { this.name = v; } })
 *   onSubmit 可选：不传时按 Done 仅收键盘（适合多字段编辑页）；
 *                  传时先执行业务回调，再自动收键盘。
 *
 * @see document/techdoc/[研发]输入组件键盘收起规范.md
 */

import { dismissSoftKeyboard } from '../ime/SoftKeyboard';

export interface TextInputParams {
  placeholder: ResourceStr;
  value: string;
  onChange: (v: string) => void;
  onSubmit?: () => void;
  height?: Length;
  layoutWeight?: number;
}

export interface TextAreaParams {
  placeholder: ResourceStr;
  value: string;
  onChange: (v: string) => void;
  onSubmit?: () => void;
  height?: Length;
  layoutWeight?: number;
}

@Builder
export function TextInputWithKeyboard(params: TextInputParams) {
  TextInput({ placeholder: params.placeholder, text: params.value })
    .onChange((v: string): void => {
      params.onChange(v);
    })
    .enterKeyType(EnterKeyType.Done)
    .onSubmit((): void => {
      if (params.onSubmit) {
        params.onSubmit();
      }
      dismissSoftKeyboard();
    })
    .width(params.layoutWeight !== undefined ? undefined : '100%')
    .layoutWeight(params.layoutWeight ?? undefined)
    .height(params.height ?? 48)
    .backgroundColor($r('app.color.ts_surface_container_high'))
    .borderRadius(10)
    .padding({ left: 12, right: 12 })
}

@Builder
export function TextAreaWithKeyboard(params: TextAreaParams) {
  TextArea({ placeholder: params.placeholder, text: params.value })
    .onChange((v: string): void => {
      params.onChange(v);
    })
    .width(params.layoutWeight !== undefined ? undefined : '100%')
    .layoutWeight(params.layoutWeight ?? undefined)
    .height(params.height ?? 80)
    .backgroundColor($r('app.color.ts_surface_container_high'))
    .borderRadius(10)
    .padding({ left: 12, right: 12 })
}