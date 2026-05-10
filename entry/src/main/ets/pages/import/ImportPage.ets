import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import BuildProfile from 'BuildProfile';
import { getImportService } from '../../features/import/ImportFeature';
import { getPersonService } from '../../features/person/PersonFeature';
import { getStoryService } from '../../features/story/StoryFeature';

type ImportCtx = 'person' | 'story';
type WizardStep = 'pick' | 'prepare' | 'conditions' | 'scan' | 'confirm' | 'done';

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

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    this.ctx = parseCtx(params);
    this.ownerId = parseOwnerId(params);
  }

  private contextLabel(): string {
    if (this.ownerId <= 0) {
      return '未携带上下文（需从人物/故事详情进入，带 ownerId）';
    }
    return this.ctx === 'person' ? `形态二 · 人物 #${this.ownerId}` : `形态一 · 故事 #${this.ownerId}`;
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
      promptAction.showToast({ message: `已选 ${this.pickedUris.length} 张（单次≤9，ST-07）` });
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
    if (this.selectedCount() > 9) {
      promptAction.showToast({ message: '勾选超过 9 张：超过单次导入上限（ST-07），请减少勾选' });
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
          { text: '返回', color: '#666666' },
          { text: '确定取消', color: '#C62828' }
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

  @Builder
  scanOverlay(): void {
    Column({ space: 16 }) {
      Text('全屏进度（P-2 骨架）')
        .fontSize(18)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Medium)
      Text(`扫描中… ${this.scanProgress}%`)
        .fontColor('#E0E0E0')
      Progress({ value: this.scanProgress, total: 100, type: ProgressType.Linear })
        .width('90%')
        .color('#4FC3F7')
        .backgroundColor('#37474F')
      Text(
        this.scanCancelling
          ? '正在取消…（应用层 cancelRequest 协作中）'
          : '取消将二次确认（IM-09），再触发 cancelRequest'
      )
        .fontSize(12)
        .fontColor('#B0BEC5')
        .width('90%')
      Button('取消扫描')
        .enabled(!this.scanCancelling)
        .onClick((): void => {
          this.onCancelScanConfirmed();
        })
      if (BuildProfile.DEBUG) {
        Text(this.debugB2WrongCancelBanner.length > 0 ? this.debugB2WrongCancelBanner : '【E2E】B2 wrong-id：未触发')
          .fontSize(11)
          .fontColor('#FFECB3')
          .width('90%')
        Button('【DEBUG】错误 ID 触发 cancelRequest（B2 负例）')
          .fontSize(11)
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
    .backgroundColor('#CC263238')
  }

  build() {
    Stack() {
      // 候选步 Grid + 文案较长时，原 Column 无滚动，底部「确认导入」会被裁出屏外；Scroll 保证可滚到主操作。
      Scroll() {
        Column({ space: 12 }) {
        Text('导入向导')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        Text(this.contextLabel())
          .fontSize(13)
          .fontColor(this.ownerId > 0 ? '#555555' : '#BF360C')
          .width('100%')

        Text(`步骤：${this.step}  ·  已选图 ${this.pickedUris.length}`)
          .fontSize(12)
          .fontColor('#666666')

        Row({ space: 8 }) {
          Button('返回')
            .onClick((): void => {
              router.back();
            })
        }

        if (this.ownerId <= 0) {
          Text('请从「人物详情」或「故事详情」点击导入入口进入。').width('100%')
        } else if (this.step === 'pick') {
          Text('① 选图 → ② 导入准备 → ③ 条件 → ④ 扫描 → ⑤ 候选确认 → ⑥ 确认写入').fontSize(12)
          Button('选图开始（相册）')
            .width('100%')
            .onClick((): void => {
              this.pickPhotos();
            })
          if (BuildProfile.DEBUG) {
            Button('【DEBUG】跳过选图进入条件（Hypium E2E）')
              .fontSize(11)
              .width('100%')
              .onClick((): void => {
                this.pickedUris = ['file://e2e/placeholder-1'];
                this.step = 'conditions';
              })
            Button('【DEBUG】跳过选图 PH-01 双占位（同 URI×2）')
              .fontSize(11)
              .width('100%')
              .onClick((): void => {
                this.pickedUris = ['file://e2e/ph01-dup', 'file://e2e/ph01-dup'];
                this.step = 'conditions';
              })
          }
        } else if (this.step === 'prepare') {
          Text('导入准备：已锁定相册 URI 列表，可返回上一步重新选图。').width('100%')
          Text(`共 ${this.pickedUris.length} 条 URI（会话内引用，不写原文件）`).fontSize(12)
          Row({ space: 8 }) {
            Button('上一步（重选）').onClick((): void => {
              this.step = 'pick';
              this.pickedUris = [];
            })
            Button('下一步：条件').onClick((): void => {
              this.step = 'conditions';
            })
          }
        } else if (this.step === 'conditions') {
          Text('导入条件 · §4.5 步骤 B（三块骨架 + 可测占位）').fontWeight(FontWeight.Medium)
          Text('以下为时间 / 地点 / 人脸三块结构；与 v1.2 像素级一致留待后续迭代，本轮可测占位与显式降级说明。')
            .fontSize(11)
            .fontColor('#666666')
            .width('100%')

          Text('时间条件').fontSize(13).fontWeight(FontWeight.Medium).margin({ top: 8 })
          Row() {
            Text('仅处理带拍摄时间戳的照片（IM 占位）').layoutWeight(1).fontSize(13)
            Toggle({ type: ToggleType.Switch, isOn: this.condRequireCaptureTime })
              .onChange((v: boolean): void => {
                this.condRequireCaptureTime = v;
              })
          }
          .width('100%')

          Text('地点条件').fontSize(13).fontWeight(FontWeight.Medium).margin({ top: 8 })
          Row() {
            Text('仅处理带地点标签的照片（IM 占位）').layoutWeight(1).fontSize(13)
            Toggle({ type: ToggleType.Switch, isOn: this.condRequireLocationTag })
              .onChange((v: boolean): void => {
                this.condRequireLocationTag = v;
              })
          }
          .width('100%')

          Text('人脸条件').fontSize(13).fontWeight(FontWeight.Medium).margin({ top: 8 })
          Row() {
            Text('启用人脸相关筛选（IM-04～07 / IM-10 占位）').layoutWeight(1).fontSize(13)
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
              .fontSize(11)
              .fontColor('#1565C0')
              .width('100%')
          }

          Divider().margin({ top: 8, bottom: 8 })
          Text('格式与去重').fontWeight(FontWeight.Medium)
          Row() {
            Text('允许 HEIC（示意）').layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.condAllowHeic })
              .onChange((v: boolean): void => {
                this.condAllowHeic = v;
              })
          }
          .width('100%')
          Row() {
            Text('写入时跳过重复 URI（PH-01）').layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.condSkipDuplicates })
              .onChange((v: boolean): void => {
                this.condSkipDuplicates = v;
              })
          }
          .width('100%')
          Row({ space: 8 }) {
            Button('上一步').onClick((): void => {
              this.step = 'prepare';
            })
            Button('开始扫描').onClick((): void => {
              this.runScanLoop();
            })
          }
        } else if (this.step === 'scan') {
          Text('扫描进行中（见全屏遮罩与进度条）').fontSize(12)
        } else if (this.step === 'confirm') {
          Text('候选确认（IM-08）· §4.5 步骤 D').fontWeight(FontWeight.Medium)
          Text('勾选要导入的项；支持全选/反选；底部主按钮执行写入（避免与按钮文案完全重复以利自动化）。')
            .fontSize(11)
            .fontColor('#666666')
            .width('100%')
          if (this.pickedUris.length === 0) {
            Text('无候选').fontColor('#999999')
          } else {
            Row({ space: 8 }) {
              Button('全选').onClick((): void => {
                this.selectAllCandidates(true);
              })
              Button('全不选').onClick((): void => {
                this.selectAllCandidates(false);
              })
              Button('反选').onClick((): void => {
                this.invertCandidates();
              })
            }
            .margin({ top: 6, bottom: 6 })

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
                        .fontSize(11)
                        .fontColor('#333333')
                        .layoutWeight(1)
                    }
                    .width('100%')
                  }
                  .padding(8)
                  .width('100%')
                  .backgroundColor('#FAFAFA')
                  .borderRadius(6)
                }
              }, (idx: number): string => `cand-${idx}`)
            }
            .columnsTemplate('1fr')
            .columnsGap(8)
            .rowsGap(8)
            .width('100%')
            // 候选 Grid 嵌套在外层 Scroll 内：关闭自身滚动条避免抢手势
            .scrollBar(BarState.Off)
          }
          Row({ space: 8 }) {
            Button('上一步（改条件）').onClick((): void => {
              this.step = 'conditions';
            })
            Button('确认导入')
              .onClick((): void => {
                this.commitImport();
              })
          }
        } else {
          Text('已完成').fontColor('#2E7D32')
        }

        if (this.scanOutcome === 'cancelled') {
          Divider()
          Text('扫描被中断').fontColor('#BF360C')
          Row({ space: 8 }) {
            Button('重试（IM-09）').onClick((): void => {
              this.retryAfterInterrupt();
            })
            Button('返回详情').onClick((): void => {
              router.back();
            })
          }
        }
      }
      .width('100%')
      .padding({ bottom: 24 })
      }
      .padding(16)
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
  }
}
