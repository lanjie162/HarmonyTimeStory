import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
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
  @State scanning: boolean = false;
  @State scanProgress: number = 0;
  @State scanRequestId: number = 0;
  @State scanOutcome: '' | 'ok' | 'cancelled' | 'failed' = '';
  @State uiLocked: boolean = false;

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

  private commitImport(): void {
    if (this.ownerId <= 0 || this.pickedUris.length === 0) {
      promptAction.showToast({ message: '无可写入数据' });
      return;
    }
    let ok = 0;
    let dup = 0;
    for (const uri of this.pickedUris) {
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
      message: `确认写入：成功 ${ok}，重复跳过 ${dup}（PH-01）；返回详情可看网格`
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
        promptAction.showToast({ message: '扫描已取消（cancelRequest）' });
        return;
      }
      this.scanProgress = p;
      await sleepMs(280);
    }
    imp.endLongTask(this.scanRequestId);
    this.scanning = false;
    this.uiLocked = false;
    this.scanOutcome = 'ok';
    this.step = 'confirm';
    promptAction.showToast({ message: '扫描完成，请确认候选' });
  }

  private onCancelScan(): void {
    const ok = getImportService().cancelRequest(this.scanRequestId);
    if (!ok) {
      promptAction.showToast({ message: '取消未生效（requestId 不匹配）' });
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
      Text('取消将触发 cancelRequest，长任务内控件已锁定')
        .fontSize(12)
        .fontColor('#B0BEC5')
        .width('90%')
      Button('取消扫描')
        .enabled(!this.uiLocked || this.scanning)
        .onClick((): void => {
          this.onCancelScan();
        })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .backgroundColor('#CC263238')
  }

  build() {
    Stack() {
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
          Text('导入条件（骨架）').fontWeight(FontWeight.Medium)
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
          Text('候选确认：将以下 URI 写入当前上下文（人物或故事）').fontWeight(FontWeight.Medium)
          if (this.pickedUris.length === 0) {
            Text('无候选').fontColor('#999999')
          } else {
            Column({ space: 4 }) {
              ForEach(this.rangeIndices(this.pickedUris.length), (idx: number) => {
                Text(this.uriPreviewLine(idx))
                  .fontSize(11)
                  .fontColor('#444444')
              }, (idx: number): string => `uri-row-${idx}`)
            }
            .width('100%')
          }
          Row({ space: 8 }) {
            Button('上一步（改条件）').onClick((): void => {
              this.step = 'conditions';
            })
            Button('确认写入').onClick((): void => {
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
      .padding(16)
      .width('100%')
      .height('100%')
      .opacity(this.scanning ? 0.35 : 1)

      if (this.scanning) {
        this.scanOverlay();
      }
    }
    .width('100%')
    .height('100%')
  }
}
