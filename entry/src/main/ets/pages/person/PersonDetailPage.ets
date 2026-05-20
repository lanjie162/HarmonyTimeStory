import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import { fileIo } from '@kit.CoreFileKit';
import BuildProfile from 'BuildProfile';
import type { GenderEnum, PersonModel, PersonTypeEnum, PhotoRefModel, StoryModel } from '../../domain/model/Models';
import { PersonTypeEnum as PT } from '../../domain/model/Models';
import { GenderEnum as GE } from '../../domain/model/Models';
import { getPersonService } from '../../features/person/PersonFeature';
import { getStoryService } from '../../features/story/StoryFeature';
import { dismissSoftKeyboard } from '../../common/ime/SoftKeyboard';

function parsePersonId(params: Record<string, Object>): number {
  const raw = params['personId'];
  if (typeof raw === 'number') {
    return raw as number;
  }
  if (typeof raw === 'string') {
    const n = Number.parseInt(raw as string, 10);
    return Number.isNaN(n) ? 0 : n;
  }
  return 0;
}

function typeLabel(val: PersonTypeEnum): string {
  if (val === PT.BABY) {
    return '宝宝';
  }
  if (val === PT.ADULT) {
    return '成人';
  }
  if (val === PT.ELDER) {
    return '长辈';
  }
  return '其他';
}

function genderLabel(val: GenderEnum | null): string {
  if (val === null || val === GE.UNSPECIFIED) {
    return '未填';
  }
  if (val === GE.MALE) {
    return '男';
  }
  return '女';
}

function formatBirthday(ts: number | null): string {
  if (ts === null || ts <= 0) {
    return '未设置';
  }
  const d = new Date(ts);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function buildDatePickerDate(ts: number | null): Date {
  if (ts !== null && ts > 0) {
    return new Date(ts);
  }
  return new Date(2000, 0, 1);
}

interface GenderOption {
  label: string;
  value: GenderEnum | null;
}

const TYPE_OPTIONS: PersonTypeEnum[] = [PT.BABY, PT.ADULT, PT.ELDER, PT.OTHER];
const GENDER_OPTIONS: GenderOption[] = [
  { label: '男', value: GE.MALE },
  { label: '女', value: GE.FEMALE },
  { label: '未填', value: GE.UNSPECIFIED }
];

@Entry
@Component
export struct PersonDetailPage {
  @State personId: number = 0;
  private person: PersonModel | null = null;
  @State draftName: string = '';
  @State draftType: PersonTypeEnum = PT.OTHER;
  @State draftGender: GenderEnum | null = null;
  @State draftBirthday: number = 0;
  @State draftBirthdayText: string = '选择日期';
  @State draftRemark: string = '';
  private draftAvatarBlob: Uint8Array | null = null;
  @State avatarImageUri: string = '';
  @State hasAvatar: boolean = false;
  @State storiesAll: StoryModel[] = [];
  @State linkedStoryIds: number[] = [];
  @State photos: PhotoRefModel[] = [];
  @State newStoryTitle: string = '';
  /** Hypium：仅 DEBUG 展示，便于断言加图结果（不依赖 Toast）。 */
  @State debugLastAlbumInject: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    this.personId = parsePersonId(params);
    this.refresh();
  }

  onPageShow(): void {
    if (this.personId > 0) {
      this.refresh();
    }
  }

  private refresh(): void {
    const pSvc = getPersonService();
    this.person = pSvc.getPerson(this.personId);
    if (this.person !== null) {
      this.draftName = this.person.displayName;
      this.draftType = this.person.personType;
      this.draftGender = this.person.gender;
      this.draftBirthday = this.person.birthday ?? 0;
      this.draftBirthdayText = formatBirthday(this.person.birthday);
      this.draftRemark = this.person.remark;
      this.draftAvatarBlob = this.person.avatarBlob;
      if (this.person.avatarBlob !== null && this.person.avatarBlob.byteLength > 0) {
        // Reconstruct temp file URI for Image display
        this.avatarImageUri = 'data:image/png;base64,' + this.blobToBase64(this.person.avatarBlob);
      } else {
        this.avatarImageUri = '';
      }
    this.hasAvatar = this.person.avatarBlob !== null && this.person.avatarBlob.byteLength > 0;
    } else {
      this.hasAvatar = false;
    }
    this.storiesAll = getStoryService().listStories();
    this.linkedStoryIds = pSvc.listLinkedStories(this.personId).map((s): number => s.id);
    this.photos = pSvc.listPersonPhotos(this.personId);
  }

  private blobToBase64(blob: Uint8Array): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result = '';
    const bytes = blob;
    for (let i = 0; i < bytes.byteLength; i += 3) {
      const b0 = bytes[i];
      const b1 = i + 1 < bytes.byteLength ? bytes[i + 1] : 0;
      const b2 = i + 2 < bytes.byteLength ? bytes[i + 2] : 0;
      result += chars.charAt(b0 >> 2);
      result += chars.charAt(((b0 & 3) << 4) | (b1 >> 4));
      result += i + 1 < bytes.byteLength ? chars.charAt(((b1 & 15) << 2) | (b2 >> 6)) : '=';
      result += i + 2 < bytes.byteLength ? chars.charAt(b2 & 63) : '=';
    }
    return result;
  }

  private savePerson(): void {
    dismissSoftKeyboard();
    const svc = getPersonService();
    const ok = svc.updatePerson(this.personId, this.draftName,
      this.draftAvatarBlob,
      this.draftBirthday > 0 ? this.draftBirthday : undefined,
      this.draftGender,
      this.draftRemark,
      this.draftType
    );
    if (!ok) {
      promptAction.showToast({ message: '保存失败：人物不存在或名称异常' });
      return;
    }
    promptAction.showToast({ message: '已保存全部字段' });
    this.refresh();
  }

  private confirmDeleteCurrentPerson(): void {
    AlertDialog.show({
      title: '确认删除',
      message: `确定要删除"${this.person?.displayName ?? ''}"吗？此操作不可撤销。`,
      primaryButton: {
        value: '取消',
        action: (): void => {
          // do nothing
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#CC0000',
        action: (): void => {
          dismissSoftKeyboard();
          const svc = getPersonService();
          const ok = svc.deletePerson(this.personId);
          if (ok) {
            promptAction.showToast({ message: '已删除' });
            router.back();
          } else {
            promptAction.showToast({ message: '删除失败：人物不存在' });
          }
        }
      }
    });
  }

  private confirmRemovePhoto(ph: PhotoRefModel): void {
    AlertDialog.show({
      title: '确认移除',
      message: `确定移除该照片（ref#${ph.id}）？仅解除关联，不删系统原图。`,
      primaryButton: {
        value: '取消',
        action: (): void => {
          // do nothing
        }
      },
      secondaryButton: {
        value: '移除',
        fontColor: '#CC0000',
        action: (): void => {
          dismissSoftKeyboard();
          const svc = getPersonService();
          const ok = svc.removePhotoFromPerson(this.personId, ph.id);
          if (ok) {
            promptAction.showToast({ message: '已移除照片' });
          } else {
            promptAction.showToast({ message: '移除失败' });
          }
          this.refresh();
        }
      }
    });
  }

  private async pickAvatar(): Promise<void> {
    dismissSoftKeyboard();
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.maxSelectNumber = 1;
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(options);
      const uris = result.photoUris;
      if (!uris || uris.length === 0) {
        return;
      }
      const uri = uris[0];
      try {
        const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
        const stat = fileIo.statSync(uri);
        const buf = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, buf);
        fileIo.closeSync(file);
        this.draftAvatarBlob = new Uint8Array(buf);
        this.avatarImageUri = 'data:image/png;base64,' + this.blobToBase64(this.draftAvatarBlob);
        this.hasAvatar = true;
      } catch (_e) {
        promptAction.showToast({ message: '读取头像文件失败' });
      }
    } catch (_e) {
      // user cancelled
    }
  }

  private removeAvatar(): void {
    this.draftAvatarBlob = null;
    this.avatarImageUri = '';
    this.hasAvatar = false;
  }

  private onBirthdayChange(year: number, month: number, day: number): void {
    // month from DatePicker is 0-based
    const d = new Date(year, month, day);
    this.draftBirthday = d.getTime();
    this.draftBirthdayText = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
  }

  private createStoryQuick(): void {
    dismissSoftKeyboard();
    const sid = getStoryService().createStory(this.newStoryTitle);
    if (sid < 0) {
      promptAction.showToast({ message: '故事标题不能为空' });
      return;
    }
    this.newStoryTitle = '';
    promptAction.showToast({ message: `已创建故事 #${sid}，可选择「关联」` });
    this.refresh();
  }

  /** 相册等价路径：与 pickPhotosFromAlbum 成功分支同一 Service，不打开系统相册。 */
  private injectDebugAlbumEquivUri(uri: string): void {
    if (this.personId <= 0) {
      this.debugLastAlbumInject = '【E2E】inject skip：无 personId';
      return;
    }
    const res = getPersonService().addPhotoToPerson(this.personId, uri);
    if (res.duplicate) {
      this.debugLastAlbumInject = '【E2E】上次加图：重复跳过（PH-01）';
    } else if (res.success) {
      this.debugLastAlbumInject = '【E2E】上次加图：成功 file://e2e/album-equiv-1';
    } else {
      this.debugLastAlbumInject = '【E2E】上次加图：失败（人物不存在或 URI 为空）';
    }
    this.refresh();
  }

  private async pickPhotosFromAlbum(): Promise<void> {
    dismissSoftKeyboard();
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
      const svc = getPersonService();
      for (const uri of uris) {
        const res = svc.addPhotoToPerson(this.personId, uri);
        if (res.duplicate) {
          promptAction.showToast({ message: '检测到重复 URI，已跳过（PH-01）' });
        }
      }
      promptAction.showToast({ message: '已处理相册选择' });
      this.refresh();
    } catch (_e) {
      promptAction.showToast({ message: '选图取消或不可用，可稍后重试' });
    }
  }

  private toggleStoryLink(s: StoryModel): void {
    dismissSoftKeyboard();
    const svc = getPersonService();
    if (this.linkedStoryIds.indexOf(s.id) >= 0) {
      svc.unlinkPersonFromStory(this.personId, s.id);
    } else {
      svc.linkPersonToStory(this.personId, s.id);
    }
    this.refresh();
  }

  build() {
    Column({ space: 0 }) {
      Row({ space: 10 }) {
        Button('返回列表')
          .height(36)
          .fontSize($r('app.float.ts_font_support'))
          .backgroundColor($r('app.color.ts_surface_container_high'))
          .fontColor($r('app.color.ts_text_secondary'))
          .onClick((): void => {
            dismissSoftKeyboard();
            router.back();
          })
        Text('人物详情')
          .fontSize($r('app.float.ts_font_title'))
          .fontColor($r('app.color.ts_text_primary'))
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .alignItems(VerticalAlign.Center)

      if (this.person !== null && this.personId > 0) {
        Scroll() {
          Column({ space: 14 }) {
            // ====== 头像 + 档案摘要 ======
            Column({ space: 8 }) {
              Row({ space: 12 }) {
                // 头像
                if (this.avatarImageUri.length > 0) {
                  Image(this.avatarImageUri)
                    .width(64).height(64)
                    .borderRadius(32)
                    .objectFit(ImageFit.Cover)
                } else {
                  Circle({ width: 64, height: 64 })
                    .fill($r('app.color.ts_surface_container_high'))
                }
                Column({ space: 4 }) {
                  Text(this.person.displayName)
                    .fontSize($r('app.float.ts_font_headline'))
                    .fontColor($r('app.color.ts_text_primary'))
                    .fontWeight(FontWeight.Medium)
                    .width('100%')
                  Text(`${typeLabel(this.person.personType)} · ${formatBirthday(this.person.birthday)} · ${genderLabel(this.person.gender)}`)
                    .fontSize($r('app.float.ts_font_caption'))
                    .fontColor($r('app.color.ts_text_tertiary'))
                    .width('100%')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })

            // ====== 编辑（全部字段） ======
            Column({ space: 12 }) {
              Text('编辑')
                .fontSize($r('app.float.ts_font_label'))
                .fontColor($r('app.color.ts_text_primary'))
                .fontWeight(FontWeight.Medium)
                .width('100%')

              // 头像操作
              Row({ space: 8 }) {
                Button('更换头像')
                  .height(36)
                  .fontSize($r('app.float.ts_font_overline'))
                  .backgroundColor($r('app.color.ts_color_info_container'))
                  .fontColor($r('app.color.ts_color_info'))
                  .onClick((): void => {
                    this.pickAvatar();
                  })
                if (this.hasAvatar) {
                  Button('移除头像')
                    .height(36)
                    .fontSize($r('app.float.ts_font_overline'))
                    .backgroundColor($r('app.color.ts_surface_container_high'))
                    .fontColor($r('app.color.ts_color_warning'))
                    .onClick((): void => {
                      this.removeAvatar();
                    })
                }
              }
              .width('100%')

              // 显示名
              TextInput({ placeholder: '显示名', text: this.draftName })
                .onChange((v: string): void => {
                  this.draftName = v;
                })
                .width('100%')
                .height(48)
                .backgroundColor($r('app.color.ts_surface_container_high'))
                .borderRadius(10)
                .padding({ left: 12, right: 12 })

              // 类型
              Row({ space: 8 }) {
                Text('类型')
                  .fontSize($r('app.float.ts_font_support'))
                  .fontColor($r('app.color.ts_text_secondary'))
                Text(typeLabel(this.draftType))
                  .fontSize($r('app.float.ts_font_support'))
                  .fontColor($r('app.color.ts_text_primary'))
                Row({ space: 4 }) {
                  ForEach(TYPE_OPTIONS, (t: PersonTypeEnum) => {
                    Button(typeLabel(t))
                      .height(32)
                      .fontSize($r('app.float.ts_font_overline'))
                      .backgroundColor(this.draftType === t
                        ? $r('app.color.ts_brand_primary')
                        : $r('app.color.ts_surface_container_high'))
                      .fontColor(this.draftType === t
                        ? $r('app.color.ts_import_bar_on_bg')
                        : $r('app.color.ts_text_secondary'))
                      .onClick((): void => {
                        this.draftType = t;
                      })
                  })
                }
                .layoutWeight(1)
                .justifyContent(FlexAlign.End)
              }
              .width('100%')

              // 性别
              Row({ space: 8 }) {
                Text('性别')
                  .fontSize($r('app.float.ts_font_support'))
                  .fontColor($r('app.color.ts_text_secondary'))
                Row({ space: 4 }) {
                  ForEach(GENDER_OPTIONS, (opt: GenderOption) => {
                    Button(opt.label)
                      .height(32)
                      .fontSize($r('app.float.ts_font_overline'))
                      .backgroundColor(this.draftGender === opt.value
                        ? $r('app.color.ts_brand_primary')
                        : $r('app.color.ts_surface_container_high'))
                      .fontColor(this.draftGender === opt.value
                        ? $r('app.color.ts_import_bar_on_bg')
                        : $r('app.color.ts_text_secondary'))
                      .onClick((): void => {
                        this.draftGender = opt.value;
                      })
                  })
                }
                .layoutWeight(1)
                .justifyContent(FlexAlign.End)
              }
              .width('100%')

              // 生日 - DatePicker
              Row({ space: 8 }) {
                Text('生日')
                  .fontSize($r('app.float.ts_font_support'))
                  .fontColor($r('app.color.ts_text_secondary'))
                Text(this.draftBirthdayText)
                  .fontSize($r('app.float.ts_font_support'))
                  .fontColor($r('app.color.ts_text_primary'))
              }
              .width('100%')
              DatePicker({
                start: new Date(1900, 0, 1),
                end: new Date(2099, 11, 31),
                selected: buildDatePickerDate(this.draftBirthday > 0 ? this.draftBirthday : null)
              })
                .width('100%')
                .onChange((res: DatePickerResult): void => {
                  const yr = res.year as number;
                  const mo = res.month as number;
                  const dy = res.day as number;
                  this.onBirthdayChange(yr, mo, dy);
                })
                .disappearTextStyle({ color: $r('app.color.ts_text_tertiary') })
                .textStyle({ color: $r('app.color.ts_text_primary') })
                .selectedTextStyle({ color: $r('app.color.ts_brand_primary') })

              // 备注
              TextArea({ placeholder: '备注', text: this.draftRemark })
                .onChange((v: string): void => {
                  this.draftRemark = v;
                })
                .width('100%')
                .height(80)
                .backgroundColor($r('app.color.ts_surface_container_high'))
                .borderRadius(10)
                .padding({ left: 12, right: 12 })

              // 保存按钮
              Button('保存')
                .width('100%')
                .height(44)
                .fontSize($r('app.float.ts_font_support'))
                .fontWeight(FontWeight.Medium)
                .backgroundColor($r('app.color.ts_brand_primary'))
                .fontColor($r('app.color.ts_import_bar_on_bg'))
                .onClick((): void => {
                  this.savePerson();
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })

            // ====== 危险操作：删除人物 ======
            Column({ space: 10 }) {
              Button('删除人物')
                .width('100%')
                .height(44)
                .fontSize($r('app.float.ts_font_support'))
                .fontWeight(FontWeight.Medium)
                .backgroundColor('#CC0000')
                .fontColor($r('app.color.ts_import_bar_on_bg'))
                .onClick((): void => {
                  this.confirmDeleteCurrentPerson();
                })
              Text('删除后将同时移除该人物的所有关联与照片挂载，不可撤销。')
                .fontSize($r('app.float.ts_font_overline'))
                .fontColor($r('app.color.ts_text_caption'))
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })

            // ====== 关联故事（保持原样） ======
            Column({ space: 12 }) {
              Text('关联故事')
                .fontSize($r('app.float.ts_font_label'))
                .fontColor($r('app.color.ts_text_primary'))
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Text('可新建故事后点「关联 / 解除关联」写入 PersonStory（内存）。')
                .fontSize($r('app.float.ts_font_caption'))
                .fontColor($r('app.color.ts_text_tertiary'))
                .width('100%')
              Row({ space: 8 }) {
                TextInput({ placeholder: '新故事标题', text: this.newStoryTitle })
                  .layoutWeight(1)
                  .height(48)
                  .backgroundColor($r('app.color.ts_surface_container_high'))
                  .borderRadius(10)
                  .padding({ left: 12, right: 12 })
                  .onChange((v: string): void => {
                    this.newStoryTitle = v;
                  })
                  .enterKeyType(EnterKeyType.Done)
                  .onSubmit((): void => {
                    this.createStoryQuick();
                  })
                Button('创建')
                  .height(48)
                  .fontSize($r('app.float.ts_font_support'))
                  .backgroundColor($r('app.color.ts_color_info_container'))
                  .fontColor($r('app.color.ts_color_info'))
                  .onClick((): void => {
                    this.createStoryQuick();
                  })
              }
              .width('100%')

              if (this.storiesAll.length === 0) {
                Text('暂无故事，可先创建或与故事主线并行补充。')
                  .fontSize($r('app.float.ts_font_caption'))
                  .fontColor($r('app.color.ts_text_tertiary'))
                  .width('100%')
              }
              Column({ space: 8 }) {
                ForEach(this.storiesAll, (s: StoryModel) => {
                  Row({ space: 8 }) {
                    Text(s.title)
                      .layoutWeight(1)
                      .fontSize($r('app.float.ts_font_support'))
                      .fontColor($r('app.color.ts_text_primary'))
                    Button(this.linkedStoryIds.indexOf(s.id) >= 0 ? '解除关联' : '关联')
                      .height(36)
                      .fontSize($r('app.float.ts_font_overline'))
                      .backgroundColor($r('app.color.ts_surface_container_high'))
                      .fontColor($r('app.color.ts_brand_primary'))
                      .onClick((): void => {
                        this.toggleStoryLink(s);
                      })
                  }
                  .padding(12)
                  .width('100%')
                  .backgroundColor($r('app.color.ts_surface_container_high'))
                  .borderRadius(10)
                  .border({ width: 1, color: $r('app.color.ts_outline') })
                }, (s: StoryModel): string => `story-row-${s.id}`)
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })

            // ====== 照片（保持原样） ======
            Column({ space: 12 }) {
              Text('照片（PhotoOwnerLink）')
                .fontSize($r('app.float.ts_font_label'))
                .fontColor($r('app.color.ts_text_primary'))
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Button('从相册选择照片（可多选）')
                .width('100%')
                .height(44)
                .fontSize($r('app.float.ts_font_support'))
                .fontWeight(FontWeight.Medium)
                .backgroundColor($r('app.color.ts_color_info_container'))
                .fontColor($r('app.color.ts_color_info'))
                .onClick((): void => {
                  this.pickPhotosFromAlbum();
                })

              if (BuildProfile.DEBUG) {
                Text(this.debugLastAlbumInject.length > 0 ? this.debugLastAlbumInject : '【E2E】尚未注入 mock URI')
                  .fontSize($r('app.float.ts_font_overline'))
                  .fontColor($r('app.color.ts_debug_banner'))
                  .width('100%')
                Row({ space: 8 }) {
                  Button('【DEBUG】注入相册等价 URI')
                    .fontSize($r('app.float.ts_font_overline'))
                    .layoutWeight(1)
                    .height(36)
                    .backgroundColor($r('app.color.ts_surface_container_high'))
                    .fontColor($r('app.color.ts_text_secondary'))
                    .onClick((): void => {
                      this.injectDebugAlbumEquivUri('file://e2e/album-equiv-1');
                    })
                  Button('【DEBUG】再注相同 URI')
                    .fontSize($r('app.float.ts_font_overline'))
                    .layoutWeight(1)
                    .height(36)
                    .backgroundColor($r('app.color.ts_surface_container_high'))
                    .fontColor($r('app.color.ts_text_secondary'))
                    .onClick((): void => {
                      this.injectDebugAlbumEquivUri('file://e2e/album-equiv-1');
                    })
                }
                .width('100%')
              }

              if (BuildProfile.DEBUG) {
                Text(`【E2E】照片数=${this.photos.length}`)
                  .fontSize($r('app.float.ts_font_overline'))
                  .fontColor($r('app.color.ts_debug_banner'))
                  .width('100%')
                Button('【DEBUG】GC 孤儿 PhotoRef')
                  .fontSize($r('app.float.ts_font_overline'))
                  .backgroundColor($r('app.color.ts_surface_container_high'))
                  .fontColor($r('app.color.ts_text_secondary'))
                  .width('100%')
                  .height(36)
                  .onClick((): void => {
                    const n = getPersonService().gcOrphanPhotoRefs();
                    promptAction.showToast({ message: `GC 完成：清理 ${n} 个孤儿 PhotoRef` });
                    this.refresh();
                  })
              }
              if (this.photos.length === 0) {
                Text('暂无挂载照片')
                  .fontColor($r('app.color.ts_text_tertiary'))
                  .fontSize($r('app.float.ts_font_caption'))
                  .width('100%')
              } else {
                Grid() {
                  ForEach(this.photos, (ph: PhotoRefModel) => {
                    GridItem() {
                      Column({ space: 4 }) {
                        Image(ph.uri).width('100%').height(96).objectFit(ImageFit.Cover).borderRadius(8)
                        Text(`ref#${ph.id}`)
                          .fontSize($r('app.float.ts_font_overline'))
                          .fontColor($r('app.color.ts_text_caption'))
                        Button('移除')
                          .height(26)
                          .fontSize($r('app.float.ts_font_overline'))
                          .backgroundColor($r('app.color.ts_surface_container_high'))
                          .fontColor('#CC0000')
                          .width('100%')
                          .onClick((): void => {
                            this.confirmRemovePhoto(ph);
                          })
                      }
                    }
                  }, (ph: PhotoRefModel): string => `ph-${ph.id}`)
                }
                .columnsTemplate('1fr 1fr 1fr')
                .columnsGap(8)
                .rowsGap(8)
                .width('100%')
                .scrollBar(BarState.Off)
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_surface_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })

            // ====== 批量导入入口 ======
            Column({ space: 10 }) {
              Text('批量导入')
                .fontSize($r('app.float.ts_font_label'))
                .fontColor($r('app.color.ts_text_primary'))
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Text('走相册向导：选图 → 准备 → 条件 → 扫描 → 确认写入（形态二）。')
                .fontSize($r('app.float.ts_font_caption'))
                .fontColor($r('app.color.ts_text_tertiary'))
                .width('100%')
              Button('进入导入向导壳页')
                .width('100%')
                .height(48)
                .fontSize($r('app.float.ts_font_body'))
                .fontWeight(FontWeight.Medium)
                .backgroundColor($r('app.color.ts_brand_primary'))
                .fontColor($r('app.color.ts_import_bar_on_bg'))
                .onClick((): void => {
                  dismissSoftKeyboard();
                  router.pushUrl({
                    url: 'pages/import/ImportPage',
                    params: { ctx: 'person', ownerId: `${this.personId}` }
                  });
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.ts_brand_primary_container'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.ts_outline') })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 28 })
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.Top)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
      } else {
        Column({ space: 8 }) {
          Text('未找到人物或路由参数缺失（需要 personId）。')
            .fontSize($r('app.float.ts_font_body'))
            .fontColor($r('app.color.ts_color_warning'))
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .margin({ left: 16, right: 16 })
        .backgroundColor($r('app.color.ts_surface_container'))
        .borderRadius(12)
        .border({ width: 1, color: $r('app.color.ts_outline') })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.ts_surface'))
  }
}