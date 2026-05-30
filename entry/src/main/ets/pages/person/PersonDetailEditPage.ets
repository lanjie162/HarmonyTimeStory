import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import { fileIo } from '@kit.CoreFileKit';
import BuildProfile from 'BuildProfile';
import type { GenderEnum, PersonModel, PersonTypeEnum, PhotoMetadata, PhotoRefModel, StoryModel } from '../../domain/model/Models';
import { PersonTypeEnum as PT } from '../../domain/model/Models';
import { GenderEnum as GE } from '../../domain/model/Models';
import { getPersonService } from '../../features/person/PersonFeature';
import { getStoryService } from '../../features/story/StoryFeature';
import { getPhotoLibraryService } from '../../features/photolibrary/PhotoLibraryFeature';
import { PhotoGridItem } from '../../common/ui/PhotoGridItem';
import { UriHealthChecker } from '../../infrastructure/media/UriHealthChecker';
import { dismissSoftKeyboard } from '../../common/ime/SoftKeyboard';
import { TextInputWithKeyboard, TextAreaWithKeyboard } from '../../common/ui/KeyboardAwareInput';

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
    return '选择日期';
  }
  const date = new Date(ts);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function buildDatePickerDate(ts: number | null): Date {
  if (ts !== null && ts > 0) {
    return new Date(ts);
  }
  return new Date();
}

const TYPE_OPTIONS: PersonTypeEnum[] = [PT.BABY, PT.ADULT, PT.ELDER, PT.OTHER];

interface GenderOption {
  label: string;
  value: GenderEnum | null;
}

const GENDER_OPTIONS: GenderOption[] = [
  { label: '男', value: GE.MALE },
  { label: '女', value: GE.FEMALE },
  { label: '未填', value: GE.UNSPECIFIED }
];

@Entry
@Component
export struct PersonDetailEditPage {
  @State personId: number = 0;
  @State person: PersonModel | null = null;
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
  @State debugLastAlbumInject: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    this.personId = parsePersonId(params);
    this.refresh();
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
        this.avatarImageUri = 'data:image/png;base64,' + this.blobToBase64(this.person.avatarBlob);
      } else {
        this.avatarImageUri = '';
      }
      this.hasAvatar = this.person.avatarBlob !== null && this.person.avatarBlob.byteLength > 0;
    }
    this.storiesAll = getStoryService().listStories();
    this.linkedStoryIds = pSvc.listLinkedStories(this.personId).map((s): number => s.id);
    this.photos = pSvc.listPersonPhotos(this.personId);
  }

  private async checkPhotoHealthAndUpdate(photoRefId: number, uri: string): Promise<void> {
    const health = await UriHealthChecker.check(uri);
    if (health > 1) {
      getPhotoLibraryService().markPhotoAsFailed(photoRefId, health);
      this.refresh();
    }
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
    router.back();
  }

  private confirmDeleteCurrentPerson(): void {
    AlertDialog.show({
      title: '确认删除',
      message: `确定要删除"${this.person?.displayName ?? ''}"吗？此操作不可撤销。`,
      primaryButton: {
        value: '取消',
        action: (): void => {
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

  private confirmRemovePhoto(photoRefId: number): void {
    AlertDialog.show({
      title: '确认移除',
      message: `确定移除该照片（ref#${photoRefId}）？仅解除关联，不删系统原图。`,
      primaryButton: {
        value: '取消',
        action: (): void => {
        }
      },
      secondaryButton: {
        value: '移除',
        fontColor: '#CC0000',
        action: (): void => {
          dismissSoftKeyboard();
          const svc = getPersonService();
          const ok = svc.removePhotoFromPerson(this.personId, photoRefId);
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
    }
  }

  private removeAvatar(): void {
    this.draftAvatarBlob = null;
    this.avatarImageUri = '';
    this.hasAvatar = false;
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
      this.debugLastAlbumInject = '【E2E】上次加图：失败（人物不存在或URI为空）';
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
      
      // 添加照片
      for (const uri of uris) {
        const metadata: PhotoMetadata = {};
        // 暂时简化，不获取元数据
        const res = svc.addPhotoToPerson(this.personId, uri, metadata);
        if (res.duplicate) {
          promptAction.showToast({ message: '检测到重复URI，已跳过（PH-01）' });
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
        Button('←')
          .height(36)
          .fontSize(24)
          .backgroundColor(Color.Transparent)
          .fontColor('#FFFFFF')
          .onClick((): void => {
            dismissSoftKeyboard();
            router.back();
          })
        Text('编辑人物')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Button('保存')
          .height(36)
          .fontSize(16)
          .backgroundColor('#67C31F')
          .fontColor('#FFFFFF')
          .onClick((): void => {
            this.savePerson();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor('#333333')
      .alignItems(VerticalAlign.Center)

      if (this.person !== null && this.personId > 0) {
        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 12 }) {
              Text('编辑')
                .fontSize(16)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Medium)
                .width('100%')

              Row({ space: 8 }) {
                Button('更换头像')
                  .height(36)
                  .fontSize(14)
                  .backgroundColor('#1E88E5')
                  .fontColor('#FFFFFF')
                  .onClick((): void => {
                    this.pickAvatar();
                  })
                if (this.hasAvatar) {
                  Button('移除头像')
                    .height(36)
                    .fontSize(14)
                    .backgroundColor('#444444')
                    .fontColor('#FF5555')
                    .onClick((): void => {
                      this.removeAvatar();
                    })
                }
              }
              .width('100%')

              TextInputWithKeyboard({
                placeholder: '显示名',
                value: this.draftName,
                onChange: (v: string): void => { this.draftName = v; }
              })

              Row({ space: 8 }) {
                Text('类型')
                  .fontSize(14)
                  .fontColor('#AAAAAA')
                Text(typeLabel(this.draftType))
                  .fontSize(14)
                  .fontColor('#FFFFFF')
                Row({ space: 4 }) {
                  ForEach(TYPE_OPTIONS, (t: PersonTypeEnum) => {
                    Button(typeLabel(t))
                      .height(32)
                      .fontSize(12)
                      .backgroundColor(this.draftType === t
                        ? '#67C31F'
                        : '#444444')
                      .fontColor(this.draftType === t
                        ? '#FFFFFF'
                        : '#AAAAAA')
                      .onClick((): void => {
                        this.draftType = t;
                      })
                  })
                }
                .layoutWeight(1)
                .justifyContent(FlexAlign.End)
              }
              .width('100%')

              Row({ space: 8 }) {
                Text('性别')
                  .fontSize(14)
                  .fontColor('#AAAAAA')
                Row({ space: 4 }) {
                  ForEach(GENDER_OPTIONS, (opt: GenderOption) => {
                    Button(opt.label)
                      .height(32)
                      .fontSize(12)
                      .backgroundColor(this.draftGender === opt.value
                        ? '#67C31F'
                        : '#444444')
                      .fontColor(this.draftGender === opt.value
                        ? '#FFFFFF'
                        : '#AAAAAA')
                      .onClick((): void => {
                        this.draftGender = opt.value;
                      })
                  })
                }
                .layoutWeight(1)
                .justifyContent(FlexAlign.End)
              }
              .width('100%')

              Row({ space: 8 }) {
                Text('生日')
                  .fontSize(14)
                  .fontColor('#AAAAAA')
                Text(this.draftBirthdayText)
                  .fontSize(14)
                  .fontColor('#FFFFFF')
              }
              .width('100%')
              CalendarPicker({
                hintRadius: 16,
                selected: buildDatePickerDate(this.draftBirthday > 0 ? this.draftBirthday : null)
              })
                .width('100%')
                .onChange((value: Date): void => {
                  this.draftBirthday = value.getTime();
                  this.draftBirthdayText = formatBirthday(this.draftBirthday);
                })

              Column() {
                TextAreaWithKeyboard({
                  placeholder: '备注',
                  value: this.draftRemark,
                  onChange: (v: string): void => { this.draftRemark = v; }
                })
              }
              .width('100%')
              .onClick((): void => {
                dismissSoftKeyboard();
              })
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#222222')
            .borderRadius(12)
            .border({ width: 1, color: '#444444' })

            Column({ space: 10 }) {
              Button('删除人物')
                .width('100%')
                .height(44)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .backgroundColor('#CC0000')
                .fontColor('#FFFFFF')
                .onClick((): void => {
                  this.confirmDeleteCurrentPerson();
                })
              Text('删除后将同时移除该人物的所有关联与照片挂载，不可撤销。')
                .fontSize(12)
                .fontColor('#AAAAAA')
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#222222')
            .borderRadius(12)
            .border({ width: 1, color: '#444444' })

            Column({ space: 12 }) {
              Text('关联故事')
                .fontSize(16)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Text('可新建故事后点「关联/解除关联」写入PersonStory（内存）。')
                .fontSize(12)
                .fontColor('#AAAAAA')
                .width('100%')
              Row({ space: 8 }) {
                TextInputWithKeyboard({
                  placeholder: '新故事标题',
                  value: this.newStoryTitle,
                  onChange: (v: string): void => { this.newStoryTitle = v; },
                  onSubmit: (): void => { this.createStoryQuick(); },
                  layoutWeight: 1
                })
                Button('创建')
                  .height(48)
                  .fontSize(14)
                  .backgroundColor('#1E88E5')
                  .fontColor('#FFFFFF')
                  .onClick((): void => {
                    this.createStoryQuick();
                  })
              }
              .width('100%')

              if (this.storiesAll.length === 0) {
                Text('暂无故事，可先创建或与故事主线并行补充。')
                  .fontSize(12)
                  .fontColor('#AAAAAA')
                  .width('100%')
              }
              Column({ space: 8 }) {
                ForEach(this.storiesAll, (s: StoryModel) => {
                  Row({ space: 8 }) {
                    Text(s.title)
                      .layoutWeight(1)
                      .fontSize(14)
                      .fontColor('#FFFFFF')
                    Button(this.linkedStoryIds.indexOf(s.id) >= 0 ? '解除关联' : '关联')
                      .height(36)
                      .fontSize(12)
                      .backgroundColor('#444444')
                      .fontColor('#67C31F')
                      .onClick((): void => {
                        this.toggleStoryLink(s);
                      })
                  }
                  .padding(12)
                  .width('100%')
                  .backgroundColor('#444444')
                  .borderRadius(10)
                  .border({ width: 1, color: '#555555' })
                }, (s: StoryModel): string => `story-row-${s.id}`)
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#222222')
            .borderRadius(12)
            .border({ width: 1, color: '#444444' })

            Column({ space: 12 }) {
              Text('照片')
                .fontSize(16)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Medium)
                .width('100%')
              Button('从相册选择照片（可多选）')
                .width('100%')
                .height(44)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .backgroundColor('#1E88E5')
                .fontColor('#FFFFFF')
                .onClick((): void => {
                  this.pickPhotosFromAlbum();
                })

              if (BuildProfile.DEBUG) {
                Text(this.debugLastAlbumInject.length > 0 ? this.debugLastAlbumInject : '【E2E】尚未注入mock URI')
                  .fontSize(12)
                  .fontColor('#FFFF00')
                  .width('100%')
                Row({ space: 8 }) {
                  Button('【DEBUG】注入相册等价URI')
                    .fontSize(12)
                    .layoutWeight(1)
                    .height(36)
                    .backgroundColor('#444444')
                    .fontColor('#AAAAAA')
                    .onClick((): void => {
                      this.injectDebugAlbumEquivUri('file://e2e/album-equiv-1');
                    })
                  Button('【DEBUG】再注相同URI')
                    .fontSize(12)
                    .layoutWeight(1)
                    .height(36)
                    .backgroundColor('#444444')
                    .fontColor('#AAAAAA')
                    .onClick((): void => {
                      this.injectDebugAlbumEquivUri('file://e2e/album-equiv-1');
                    })
                }
                .width('100%')
              }

              if (BuildProfile.DEBUG) {
                Text(`【E2E】照片数=${this.photos.length}`)
                  .fontSize(12)
                  .fontColor('#FFFF00')
                  .width('100%')
                Button('【DEBUG】GC孤儿PhotoRef')
                  .fontSize(12)
                  .backgroundColor('#444444')
                  .fontColor('#AAAAAA')
                  .width('100%')
                  .height(36)
                  .onClick((): void => {
                    const n = getPersonService().gcOrphanPhotoRefs();
                    promptAction.showToast({ message: `GC完成：清理 ${n} 个孤儿PhotoRef` });
                    this.refresh();
                  })
              }
              if (this.photos.length === 0) {
                Text('暂无挂载照片')
                  .fontColor('#AAAAAA')
                  .fontSize(12)
                  .width('100%')
              } else {
                Grid() {
                  ForEach(this.photos, (ph: PhotoRefModel) => {
                    GridItem() {
                      PhotoGridItem({
                        ph: ph,
                        onRemove: (photoRefId: number): void => {
                          this.confirmRemovePhoto(photoRefId);
                        },
                        onStatusChanged: (photoRefId: number, status: number): void => {
                          getPhotoLibraryService().markPhotoAsFailed(photoRefId, status);
                          this.checkPhotoHealthAndUpdate(photoRefId, ph.uri);
                        }
                      })
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
            .backgroundColor('#222222')
            .borderRadius(12)
            .border({ width: 1, color: '#444444' })
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
          Text('未找到人物或路由参数缺失（需要personId）。')
            .fontSize(16)
            .fontColor('#FF5555')
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .margin({ left: 16, right: 16 })
        .backgroundColor('#222222')
        .borderRadius(12)
        .border({ width: 1, color: '#444444' })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#111111')
  }
}
