import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import { common } from '@kit.AbilityKit';
import BuildProfile from 'BuildProfile';
import { getImportService } from '../../features/import/ImportFeature';
import { getPersonService } from '../../features/person/PersonFeature';
import { getStoryService } from '../../features/story/StoryFeature';
import { DomainRules } from '../../domain/rules/Rules';
import { PermissionManager } from '../../infrastructure/api/PermissionManager';

type ImportCtx = 'person' | 'story';
type WizardStep = 'pick' | 'prepare' | 'conditions' | 'scan' | 'confirm' | 'done';

const IMPORT_STEP_FLOW: WizardStep[] = ['pick', 'prepare', 'conditions', 'scan', 'confirm', 'done'];

function sleepMs(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void): void => {
    setTimeout((): void => {
      resolve();
    }, ms);
  });
}

function parseCtx(params: Record<string, Object>): ImportCtx {
  const raw = params['ctx'];
  if (typeof raw === 'string' && (raw as string) === 'story') {
    return 'story';
  }
  return 'person';
}

function parseOwnerId(params: Record<string, Object>): number {
  const raw = params['ownerId'];
  if (typeof raw === 'number') {
    return raw as number;
  }
  if (typeof raw === 'string') {
    const n = Number.parseInt(raw as string, 10);
    return Number.isNaN(n) ? 0 : n;
  }
  return 0;
}

@Entry
@Component
export struct ImportPage {
  @State ctx: ImportCtx = 'person';
  @State ownerId: number = 0;
  @State step: WizardStep = 'pick';
  @State pickedUris: string[] = [];
  @State condAllowHeic: boolean = true;
  @State condSkipDuplicates: boolean = true;
  @State condRequireCaptureTime: boolean = false;
  @State condRequireLocationTag: boolean = false;
  @State condRequireFaceMatch: boolean = false;
  @State faceClauseHintVisible: boolean = false;
  @State candidateSelected: boolean[] = [];
  @State scanCancelling: boolean = false;
  @State scanning: boolean = false;
  @State scanProgress: number = 0;
  @State scanRequestId: number = 0;
  @State scanOutcome: '' | 'ok' | 'cancelled' | 'failed' = '';
  @State uiLocked: boolean = false;
  /** DEBUG：Hypium 断言 B2 错误 requestId 分支（与 Toast 同文案场景）。 */
  @State debugB2WrongCancelBanner: string = '';
  @State ownerName: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    this.ctx = parseCtx(params);
    this.ownerId = parseOwnerId(params);
    this.lookupOwnerName();
  }

  private lookupOwnerName(): void {
    if (this.ownerId <= 0) {
      this.ownerName = '未知';
      return;
    }
    if (this.ctx === 'person') {
      const p = getPersonService().getPerson(this.ownerId);
      this.ownerName = p !== null ? p.displayName : `人物 #${this.ownerId}`;
    } else {
      const s = getStoryService().getStory(this.ownerId);
      this.ownerName = s !== null ? s.title : `故事 #${this.ownerId}`;
    }
  }

  private contextLabel(): string {
    if (this.ownerId <= 0) {
      return '未携带上下文（需从人物/故事详情进入，带 ownerId）';
    }
    return this.ctx === 'person' ? `形态二 · ${this.ownerName}` : `形态一 · ${this.ownerName}`;
  }

  private stepShortLabel(s: WizardStep): string {
    switch (s) {
      case 'pick':
        return '选图';
      case 'prepare':
        return '准备';
      case 'conditions':
        return '条件';
      case 'scan':
        return '扫描';
      case 'confirm':
        return '候选';
      case 'done':
        return '完成';
      default:
        return '';
    }
  }

  private async pickPhotos(): Promise<void> {
    if (this.ownerId <= 0) {
      promptAction.showToast({ message: '缺少 ownerId，请从详情页进入导入' });
      return;
    }
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.maxSelectNumber = 9;
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(options);
      const uris = result.photoUris;
      if (!uris || uris.length === 0) {
        return;
      }
      this.pickedUris = [...uris];
      promptAction.showToast({ message: `已选 ${this.pickedUris.length} 张（单次≤${DomainRules.maxStoryPhotos}，ST-07）` });
      this.step = 'prepare';
    } catch (_e) {
      promptAction.showToast({ message: '选图取消（IM-09）' });
    }
  }

  private initCandidateSelection(): void {
    const next: boolean[] = [];
    for (let i = 0; i < this.pickedUris.length; i++) {
      next.push(true);
    }
    this.candidateSelected = next;
  }

  private selectedCount(): number {
    let n = 0;
    for (let i = 0; i < this.candidateSelected.length; i++) {
      if (this.candidateSelected[i]) {
        n++;
      }
    }
    return n;
  }

  private selectedImportUris(): string[] {
    const out: string[] = [];
    for (let i = 0; i < this.pickedUris.length; i++) {
      if (i < this.candidateSelected.length && this.candidateSelected[i]) {
        out.push(this.pickedUris[i]);
      }
    }
    return out;
  }

  private selectAllCandidates(on: boolean): void {
    const next: boolean[] = [];
    for (let i = 0; i < this.pickedUris.length; i++) {
      next.push(on);
    }
    this.candidateSelected = next;
  }

  private invertCandidates(): void {
    const next: boolean[] = [];
    for (let i = 0; i < this.pickedUris.length; i++) {
      const cur = i < this.candidateSelected.length ? this.candidateSelected[i] : false;
      next.push(!cur);
    }
    this.candidateSelected = next;
  }

  private commitImport(): void {
    if (this.ownerId <= 0) {
      promptAction.showToast({ message: '缺少 ownerId' });
      return;
    }
    const uris = this.selectedImportUris();
    if (uris.length === 0) {
      promptAction.showToast({ message: '请至少勾选一项候选' });
      return;
    }
    if (this.selectedCount() > DomainRules.maxStoryPhotos) {
      AlertDialog.show({
        title: '超上限阻断',
        message: `当前勾选 ${this.selectedCount()} 张，超出单故事上限 ${DomainRules.maxStoryPhotos} 张（ST-07）。请减少勾选后重试。`,
        primaryButton: {
          value: '取消',
          action: (): void => {
            // do nothing
          }
        },
        secondaryButton: {
          value: '减少勾选',
          fontColor: $r('app.color.ts_brand_primary'),
          action: (): void => {
            // do nothing, user can uncheck and retry
          }
        }
      });
      return;
    }
    let ok = 0;
    let dup = 0;
    for (const uri of uris) {
      if (this.ctx === 'person') {
        const r = getPersonService().addPhotoToPerson(this.ownerId, uri);
        if (r.duplicate) {
          dup++;
        } else if (r.success) {
          ok++;
        }
      } else {
        const r = getStoryService().addPhotoToStory(this.ownerId, uri);
        if (r.duplicate) {
          dup++;
        } else if (r.success) {
          ok++;
        }
      }
    }
    promptAction.showToast({
      message: `确认导入：成功 ${ok}，重复跳过 ${dup}（PH-01）；返回详情可看网格`
    });
    this.step = 'done';
    router.back();
  }

  private rangeIndices(len: number): number[] {
    const out: number[] = [];
    for (let i = 0; i < len; i++) {
      out.push(i);
    }
    return out;
  }

  private uriPreviewLine(idx: number): string {
    const u = this.pickedUris[idx];
    const head = u.length > 48 ? `${u.substring(0, 48)}…` : u;
    return `${idx + 1}. ${head}`;
  }

  private async runScanLoop(): Promise<void> {
    this.debugB2WrongCancelBanner = '';
    this.scanning = true;
    this.uiLocked = true;
    this.scanProgress = 0;
    this.scanOutcome = '';
    this.step = 'scan';
    const imp = getImportService();
    this.scanRequestId = imp.beginLongTask();
    for (let p = 0; p <= 100; p += 10) {
      if (imp.isCancelled(this.scanRequestId)) {
        this.scanOutcome = 'cancelled';
        this.step = 'conditions';
        imp.endLongTask(this.scanRequestId);
        this.scanning = false;
        this.uiLocked = false;
        this.scanCancelling = false;
        promptAction.showToast({ message: '扫描已取消（cancelRequest），已回条件步' });
        return;
      }
      this.scanProgress = p;
      await sleepMs(280);
    }
    imp.endLongTask(this.scanRequestId);
    this.scanning = false;
    this.uiLocked = false;
    this.scanOutcome = 'ok';
    this.initCandidateSelection();
    this.step = 'confirm';
    promptAction.showToast({ message: '扫描完成，请确认候选' });
  }

  private async onCancelScanConfirmed(): Promise<void> {
    try {
      const res = await promptAction.showDialog({
        title: '确认取消扫描（IM-09）',
        message: '确定取消当前扫描？将显示「正在取消…」，完成后返回条件步并保留已选条件。',
        buttons: [
          { text: '返回', color: $r('app.color.ts_text_tertiary') },
          { text: '确定取消', color: $r('app.color.ts_color_error') }
        ]
      });
      if (res.index !== 1) {
        return;
      }
      this.scanCancelling = true;
      const ok = getImportService().cancelRequest(this.scanRequestId);
      if (!ok) {
        this.scanCancelling = false;
        promptAction.showToast({ message: '取消未生效（requestId 不匹配）' });
      }
    } catch (_e) {
      this.scanCancelling = false;
    }
  }

  private retryAfterInterrupt(): void {
    this.scanOutcome = '';
    this.step = 'conditions';
    promptAction.showToast({ message: '可重试：返回条件步（IM-09）' });
  }

  /** CR-01: 权限测试临时入口。T-31 后台扫描上线后移除。 */
  private async runPermissionTest(): Promise<void> {
    const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (PermissionManager.getInstance().hasMediaPermission(ctx)) {
      promptAction.showToast({ message: '权限已授予，无需操作' });
      return;
    }
    const result = await PermissionManager.getInstance().requestMediaPermission(ctx);
    if (!result.granted) {
      if (result.isPermanentlyDenied) {
        this.showPermissionDeniedDialog(ctx);
      } else {
        // T-32 ER-02：用户取消态弹窗，区分于权限拒绝态
        this.showUserCancelledDialog();
      }
    } else {
      promptAction.showToast({ message: '权限已授予' });
    }
  }

  /**
   * T-32 ER-02：权限拒绝引导弹窗（永久拒绝态）。
   * 显示引导文案 + 系统设置跳转链接。
   */
  private showPermissionDeniedDialog(ctx: common.UIAbilityContext): void {
    AlertDialog.show({
      title: '需要相册权限',
      message: '时光故事需要访问您的照片，以便将照片导入到人物档案或故事时间线中。所有照片数据仅保存在本地，不会上传至任何服务器。\n\n您已选择"不再询问"，请在系统设置中手动开启"媒体和照片"权限。',
      primaryButton: {
        value: '取消',
        action: (): void => {}
      },
      secondaryButton: {
        value: '前往设置',
        fontColor: $r('app.color.ts_brand_primary'),
        action: (): void => {
          PermissionManager.getInstance().openAppPermissionSettings(ctx);
        }
      }
    });
  }

  /**
   * T-32 ER-02：用户取消权限弹窗（非永久拒绝态）。
   * 简短说明需要权限的原因。
   */
  private showUserCancelledDialog(): void {
    AlertDialog.show({
      title: '需要相册权限',
      message: '时光故事需要访问您的照片，才能将照片导入到人物档案或故事时间线中。所有照片数据仅保存在本地，不会上传至任何服务器。',
      primaryButton: {
        value: '知道了',
        action: (): void => {}
      },
      secondaryButton: {
        value: '再次授权',
        fontColor: $r('app.color.ts_brand_primary'),
        action: (): void => {
          // 用户选择重新授权，重复请求流程
          this.reRequestPermission();
        }
      }
    });
  }

  /**
   * T-32：用户点击"再次授权"后重新请求媒体权限。
   */
  private async reRequestPermission(): Promise<void> {
    const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await PermissionManager.getInstance().requestMediaPermission(ctx);
    if (!result.granted) {
      if (result.isPermanentlyDenied) {
        this.showPermissionDeniedDialog(ctx);
      } else {
        promptAction.showToast({ message: '权限未授予，请稍后重试' });
      }
    } else {
      promptAction.showToast({ message: '权限已授予' });
    }
  }

  @Builder
  stepIndicator(): void {
    Row({ space: 6 }) {
      ForEach(IMPORT_STEP_FLOW, (s: WizardStep) => {
        Text(this.stepShortLabel(s))
          .fontSize($r('app.float.ts_font_overline'))
          .fontColor(this.step === s ? $r('app.color.ts_brand_primary') : $r('app.color.ts_text_muted'))
          .fontWeight(this.step === s ? FontWeight.Medium : FontWeight.Regular)
          .padding({ left: 8, right: 8, top: 6, bottom: 6 })
          .backgroundColor(
            this.step === s ? $r('app.color.ts_brand_primary_container') : $r('app.color.ts_surface_container_high')
          )
          .borderRadius(99)
      }, (s: WizardStep): string => `import-step-${s}`)
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }

  @Builder
  scanOverlay(): void {
    Column({ space: 16 }) {
      Text('全屏进度（P-2 骨架）')
        .fontSize($r('app.float.ts_font_headline'))
        .fontColor($r('app.color.ts_import_bar_on_bg'))
        .fontWeight(FontWeight.Medium)
      Text(`扫描中… ${this.scanProgress}%`)
        .fontColor($r('app.color.ts_import_bar_on_bg_secondary'))
      Progress({ value: this.scanProgress, total: 100, type: ProgressType.Linear })
        .width('90%')
        .color($r('app.color.ts_import_progress'))
        .backgroundColor($r('app.color.ts_import_bar_bg'))
      Text(
        this.scanCancelling
          ? '正在取消…（应用层 cancelRequest 协作中）'
          : '取消将二次确认（IM-09），再触发 cancelRequest'
      )
        .fontSize($r('app.float.ts_font_caption'))
        .fontColor($r('app.color.ts_import_bar_on_bg_secondary'))
        .width('90%')
      Button('取消扫描')
        .enabled(!this.scanCancelling)
        .fontColor($r('app.color.ts_import_bar_on_bg'))
        .backgroundColor($r('app.color.ts_import_bar_bg'))
        .onClick((): void => {
          this.onCancelScanConfirmed();
        })
      if (BuildProfile.DEBUG) {
        Text(this.debugB2WrongCancelBanner.length > 0 ? this.debugB2WrongCancelBanner : '【E2E】B2 wrong-id：未触发')
          .fontSize($r('app.float.ts_font_overline'))
          .fontColor($r('app.color.ts_import_hint'))
          .width('90%')
        Button('【DEBUG】错误 ID 触发 cancelRequest（B2 负例）')
          .fontSize($r('app.float.ts_font_overline'))
          .fontColor($r('app.color.ts_import_bar_on_bg'))
          .backgroundColor($r('app.color.ts_import_bar_bg'))
          .onClick((): void => {
            const badId = this.scanRequestId + 999;
            const ok = getImportService().cancelRequest(badId);
            if (!ok) {
              this.debugB2WrongCancelBanner = '【E2E】cancelRequest：未生效（requestId 不匹配）';
              promptAction.showToast({ message: '取消未生效（requestId 不匹配）' });
            } else {
              this.debugB2WrongCancelBanner = '【E2E】意外：取消竟返回成功';
            }
          })
      }
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.ts_import_overlay_scrim'))
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 8 }) {
            Row() {
              Text('导入向导')
                .fontSize($r('app.float.ts_font_title'))
                .fontColor($r('app.color.ts_text_primary'))
                .fontWeight(FontWeight.Bold)
                .layoutWeight(1)
              Button('返回')
                .height(36)
                .fontSize($r('app.float.ts_font_support'))
                .backgroundColor($r('app.color.ts_surface_container_high'))
                .fontColor($r('app.color.ts_text_secondary'))
                .onClick((): void => {
                  router.back();
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            Text(this.contextLabel())
              .fontSize($r('app.float.ts_font_support'))
              .fontColor(this.ownerId > 0 ? $r('app.color.ts_text_secondary') : $r('app.color.ts_color_warning'))
              .width('100%')

            Row({ space: 8 }) {
              Text(`步骤 ${this.step}`)
                .fontSize($r('app.float.ts_font_caption'))
                .fontColor($r('app.color.ts_text_tertiary'))
              Text('·')
                .fontSize($r('app.float.ts_font_caption'))
                .fontColor($r('app.color.ts_outline'))
              Text(`已选图 ${this.pickedUris.length}`)
                .fontSize($r('app.float.ts_font_caption'))
                .fontColor($r('app.color.ts_text_tertiary'))
            }
            .width('100%')

            this.stepIndicator()
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 12 })
          .backgroundColor($r('app.color.ts_surface_container'))
          .borderRadius(12)
          .border({ width: 1, color: $r('app.color.ts_outline') })

          if (this.ownerId <= 0) {
            Column({ space: 10 }) {
              Text('请从「人物详情」或「故事详情」点击导入入口进入。')
                .fontSize($r('app.float.ts_font_body'))
                .fontColor($r('app.color.ts_text_secondary'))
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })
          } else if (this.step === 'pick') {
            Column({ space: 14 }) {
              Text('从相册选择要处理的照片（单次最多 9 张）。')
                .fontSize($r('app.float.ts_font_support'))
                .fontColor($r('app.color.ts_text_tertiary'))
                .width('100%')
              Button('选图开始（相册）')
                .width('100%')
                .height(48)
                .fontSize($r('app.float.ts_font_body'))
                .fontWeight(FontWeight.Medium)
                .backgroundColor($r('app.color.ts_brand_primary'))
                .fontColor($r('app.color.ts_import_bar_on_bg'))
                .onClick((): void => {
                  this.pickPhotos();
                })
              if (BuildProfile.DEBUG) {
                Button('【DEBUG】跳过选图进入条件（Hypium E2E）')
                  .fontSize($r('app.float.ts_font_overline'))
                  .width('100%')
                  .height(40)
                  .backgroundColor($r('app.color.ts_surface_container_high'))
                  .fontColor($r('app.color.ts_text_secondary'))
                  .onClick((): void => {
                    this.pickedUris = ['file://e2e/placeholder-1'];
                    this.step = 'conditions';
                  })
                Button('【DEBUG】跳过选图 PH-01 双占位（同 URI×2）')
                  .fontSize($r('app.float.ts_font_overline'))
                  .width('100%')
                  .height(40)
                  .backgroundColor($r('app.color.ts_surface_container_high'))
                  .fontColor($r('app.color.ts_text_secondary'))
                  .onClick((): void => {
                    this.pickedUris = ['file://e2e/ph01-dup', 'file://e2e/ph01-dup'];
                    this.step = 'conditions';
                  })
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })
          } else if (this.step === 'prepare') {
            Column({ space: 14 }) {
              Text('导入准备：已锁定相册 URI 列表，可返回上一步重新选图。')
                .fontSize($r('app.float.ts_font_support'))
                .fontColor($r('app.color.ts_text_secondary'))
                .width('100%')
              Text(`共 ${this.pickedUris.length} 条 URI（会话内引用，不写原文件）`)
                .fontSize($r('app.float.ts_font_caption'))
                .fontColor($r('app.color.ts_text_tertiary'))
                .width('100%')
              Row({ space: 10 }) {
                Button('上一步（重选）')
                  .layoutWeight(1)
                  .height(44)
                  .backgroundColor($r('app.color.ts_surface_container_high'))
                  .fontColor($r('app.color.ts_text_secondary'))
                  .onClick((): void => {
                    this.step = 'pick';
                    this.pickedUris = [];
                  })
                Button('下一步：条件')
                  .layoutWeight(1)
                  .height(44)
                  .fontWeight(FontWeight.Medium)
                  .backgroundColor($r('app.color.ts_brand_primary'))
                  .fontColor($r('app.color.ts_import_bar_on_bg'))
                  .onClick((): void => {
                    this.step = 'conditions';
                  })
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })
          } else if (this.step === 'conditions') {
            Column({ space: 12 }) {
              Text('导入条件 · 4.5 步骤 B')
                .fontSize($r('app.float.ts_font_label'))
                .fontColor($r('app.color.ts_text_primary'))
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Text('时间 / 地点 / 人脸三块结构；与 v1.2 像素级一致留待后续迭代，本轮为可测占位。')
                .fontSize($r('app.float.ts_font_overline'))
                .fontColor($r('app.color.ts_text_tertiary'))
                .width('100%')

              Text('时间条件')
                .fontSize($r('app.float.ts_font_support'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.ts_text_secondary'))
                .margin({ top: 8 })
                .width('100%')
              Row() {
                Text('仅处理带拍摄时间戳的照片（IM 占位）')
                  .layoutWeight(1)
                  .fontSize($r('app.float.ts_font_support'))
                  .fontColor($r('app.color.ts_text_primary'))
                Toggle({ type: ToggleType.Switch, isOn: this.condRequireCaptureTime })
                  .onChange((v: boolean): void => {
                    this.condRequireCaptureTime = v;
                  })
              }
              .width('100%')

              Text('地点条件')
                .fontSize($r('app.float.ts_font_support'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.ts_text_secondary'))
                .margin({ top: 8 })
                .width('100%')
              Row() {
                Text('仅处理带地点标签的照片（IM 占位）')
                  .layoutWeight(1)
                  .fontSize($r('app.float.ts_font_support'))
                  .fontColor($r('app.color.ts_text_primary'))
                Toggle({ type: ToggleType.Switch, isOn: this.condRequireLocationTag })
                  .onChange((v: boolean): void => {
                    this.condRequireLocationTag = v;
                  })
              }
              .width('100%')

              Text('人脸条件')
                .fontSize($r('app.float.ts_font_support'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.ts_text_secondary'))
                .margin({ top: 8 })
                .width('100%')
              Row() {
                Text('启用人脸相关筛选（IM-04～07 / IM-10 占位）')
                  .layoutWeight(1)
                  .fontSize($r('app.float.ts_font_support'))
                  .fontColor($r('app.color.ts_text_primary'))
                Toggle({ type: ToggleType.Switch, isOn: this.condRequireFaceMatch })
                  .onChange((v: boolean): void => {
                    const wasOn = this.condRequireFaceMatch;
                    this.condRequireFaceMatch = v;
                    if (v && !wasOn) {
                      this.faceClauseHintVisible = true;
                    }
                  })
              }
              .width('100%')
              if (this.faceClauseHintVisible && this.condRequireFaceMatch) {
                Text(
                  '说明（占位）：开启后将在后续版本按 IM-04～IM-07 / IM-10 收敛规则；当前导入链为内存骨架，不在本步阻断写入，仅作可测展示。'
                )
                  .fontSize($r('app.float.ts_font_overline'))
                  .fontColor($r('app.color.ts_color_info'))
                  .width('100%')
                  .padding(10)
                  .backgroundColor($r('app.color.ts_color_info_container'))
                  .borderRadius(8)
              }

              Divider().margin({ top: 8, bottom: 8 }).color($r('app.color.ts_outline'))
              Text('格式与去重')
                .fontSize($r('app.float.ts_font_label'))
                .fontColor($r('app.color.ts_text_primary'))
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Row() {
                Text('允许 HEIC（示意）')
                  .layoutWeight(1)
                  .fontSize($r('app.float.ts_font_support'))
                  .fontColor($r('app.color.ts_text_primary'))
                Toggle({ type: ToggleType.Switch, isOn: this.condAllowHeic })
                  .onChange((v: boolean): void => {
                    this.condAllowHeic = v;
                  })
              }
              .width('100%')
              Row() {
                Text('写入时跳过重复 URI（PH-01）')
                  .layoutWeight(1)
                  .fontSize($r('app.float.ts_font_support'))
                  .fontColor($r('app.color.ts_text_primary'))
                Toggle({ type: ToggleType.Switch, isOn: this.condSkipDuplicates })
                  .onChange((v: boolean): void => {
                    this.condSkipDuplicates = v;
                  })
              }
              .width('100%')
              Row({ space: 10 }) {
                Button('上一步')
                  .layoutWeight(1)
                  .height(44)
                  .backgroundColor($r('app.color.ts_surface_container_high'))
                  .fontColor($r('app.color.ts_text_secondary'))
                  .onClick((): void => {
                    this.step = 'prepare';
                  })
                Button('开始扫描')
                  .layoutWeight(1)
                  .height(44)
                  .fontWeight(FontWeight.Medium)
                  .backgroundColor($r('app.color.ts_brand_primary'))
                  .fontColor($r('app.color.ts_import_bar_on_bg'))
                  .onClick((): void => {
                    this.runScanLoop();
                  })
              }
              .margin({ top: 8 })
              .width('100%')

              // CR-01: 权限测试临时 DEBUG 入口——见 runPermissionTest() 注释
              if (BuildProfile.DEBUG) {
                Divider().margin({ top: 8, bottom: 4 }).color($r('app.color.ts_outline'))
                Text('【ER-02 权限测试】')
                  .fontSize($r('app.float.ts_font_overline'))
                  .fontColor($r('app.color.ts_color_warning'))
                  .width('100%')
                Button('权限链条测试（ER-02）')
                  .fontSize($r('app.float.ts_font_overline'))
                  .width('100%')
                  .height(36)
                  .backgroundColor($r('app.color.ts_surface_container_high'))
                  .fontColor($r('app.color.ts_text_secondary'))
                  .onClick((): void => {
                    this.runPermissionTest();
                  })
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })
          } else if (this.step === 'scan') {
            Column({ space: 8 }) {
              Text('扫描进行中（见全屏遮罩与进度条）')
                .fontSize($r('app.float.ts_font_support'))
                .fontColor($r('app.color.ts_text_tertiary'))
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })
          } else if (this.step === 'confirm') {
            Column({ space: 12 }) {
              Text('候选确认（IM-08）· 4.5 步骤 D')
                .fontSize($r('app.float.ts_font_label'))
                .fontColor($r('app.color.ts_text_primary'))
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Text('勾选要导入的项；支持全选 / 反选；底部主按钮执行写入。')
                .fontSize($r('app.float.ts_font_overline'))
                .fontColor($r('app.color.ts_text_tertiary'))
                .width('100%')
              if (this.pickedUris.length === 0) {
                Text('无候选')
                  .fontColor($r('app.color.ts_text_caption'))
                  .fontSize($r('app.float.ts_font_support'))
              } else {
                Row({ space: 8 }) {
                  Button('全选')
                    .height(36)
                    .fontSize($r('app.float.ts_font_support'))
                    .backgroundColor($r('app.color.ts_surface_container_high'))
                    .fontColor($r('app.color.ts_text_secondary'))
                    .onClick((): void => {
                      this.selectAllCandidates(true);
                    })
                  Button('全不选')
                    .height(36)
                    .fontSize($r('app.float.ts_font_support'))
                    .backgroundColor($r('app.color.ts_surface_container_high'))
                    .fontColor($r('app.color.ts_text_secondary'))
                    .onClick((): void => {
                      this.selectAllCandidates(false);
                    })
                  Button('反选')
                    .height(36)
                    .fontSize($r('app.float.ts_font_support'))
                    .backgroundColor($r('app.color.ts_surface_container_high'))
                    .fontColor($r('app.color.ts_text_secondary'))
                    .onClick((): void => {
                      this.invertCandidates();
                    })
                }
                .margin({ top: 4, bottom: 8 })
                .width('100%')

                Grid() {
                  ForEach(this.rangeIndices(this.pickedUris.length), (idx: number) => {
                    GridItem() {
                      Column({ space: 6 }) {
                        Row({ space: 8 }) {
                          Toggle({ type: ToggleType.Switch, isOn: this.candidateSelected[idx] })
                            .onChange((v: boolean): void => {
                              const fixed: boolean[] = [];
                              for (let j = 0; j < this.pickedUris.length; j++) {
                                fixed.push(j === idx ? v : this.candidateSelected[j]);
                              }
                              this.candidateSelected = fixed;
                            })
                          Text(this.uriPreviewLine(idx))
                            .fontSize($r('app.float.ts_font_overline'))
                            .fontColor($r('app.color.ts_text_primary'))
                            .layoutWeight(1)
                        }
                        .width('100%')
                      }
                      .padding(12)
                      .width('100%')
                      .backgroundColor($r('app.color.ts_surface_container_high'))
                      .borderRadius(10)
                      .border({ width: 1, color: $r('app.color.ts_outline') })
                    }
                  }, (idx: number): string => `cand-${idx}`)
                }
                .columnsTemplate('1fr')
                .columnsGap(10)
                .rowsGap(10)
                .width('100%')
                .scrollBar(BarState.Off)
              }
              Row({ space: 10 }) {
                Button('上一步（改条件）')
                  .layoutWeight(1)
                  .height(44)
                  .backgroundColor($r('app.color.ts_surface_container_high'))
                  .fontColor($r('app.color.ts_text_secondary'))
                  .onClick((): void => {
                    this.step = 'conditions';
                  })
                Button('确认导入')
                  .layoutWeight(1)
                  .height(44)
                  .fontWeight(FontWeight.Medium)
                  .backgroundColor($r('app.color.ts_brand_primary'))
                  .fontColor($r('app.color.ts_import_bar_on_bg'))
                  .onClick((): void => {
                    this.commitImport();
                  })
              }
              .width('100%')
              .margin({ top: 8 })
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })
          } else {
            Column({ space: 12 }) {
              Text('已完成')
                .fontSize($r('app.float.ts_font_headline'))
                .fontColor($r('app.color.ts_color_success'))
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Text('导入结果已通过 Toast 提示，可在人物或故事详情中查看照片网格。')
                .fontSize($r('app.float.ts_font_caption'))
                .fontColor($r('app.color.ts_text_tertiary'))
                .lineHeight(18)
                .width('100%')
              Button('返回详情')
                .width('100%')
                .height(48)
                .fontSize($r('app.float.ts_font_body'))
                .fontWeight(FontWeight.Medium)
                .backgroundColor($r('app.color.ts_brand_primary'))
                .fontColor($r('app.color.ts_import_bar_on_bg'))
                .onClick((): void => {
                  router.back();
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })
          }

          if (this.scanOutcome === 'cancelled') {
            Column({ space: 12 }) {
              Divider().color($r('app.color.ts_outline'))
              Text('扫描被中断')
                .fontSize($r('app.float.ts_font_support'))
                .fontColor($r('app.color.ts_color_warning'))
                .fontWeight(FontWeight.Medium)
              Row({ space: 10 }) {
                Button('重试（IM-09）')
                  .layoutWeight(1)
                  .height(44)
                  .backgroundColor($r('app.color.ts_brand_primary'))
                  .fontColor($r('app.color.ts_import_bar_on_bg'))
                  .onClick((): void => {
                    this.retryAfterInterrupt();
                  })
                Button('返回详情')
                  .layoutWeight(1)
                  .height(44)
                  .backgroundColor($r('app.color.ts_surface_container_high'))
                  .fontColor($r('app.color.ts_text_secondary'))
                  .onClick((): void => {
                    router.back();
                  })
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_brand_primary_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 28 })
        .backgroundColor($r('app.color.ts_surface'))
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .opacity(this.scanning ? 0.35 : 1)

      if (this.scanning) {
        this.scanOverlay();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.ts_surface'))
  }
}
