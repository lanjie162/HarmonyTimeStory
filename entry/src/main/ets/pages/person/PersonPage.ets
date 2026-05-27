import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type { PersonModel, PersonTypeEnum, GenderEnum } from '../../domain/model/Models';
import { PersonTypeEnum as PT, GenderEnum as GE } from '../../domain/model/Models';
import { getPersonService } from '../../features/person/PersonFeature';
import { dismissSoftKeyboard } from '../../common/ime/SoftKeyboard';
import { TextInputWithKeyboard } from '../../common/ui/KeyboardAwareInput';

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
  if (val === GE.MALE) {
    return '男';
  }
  if (val === GE.FEMALE) {
    return '女';
  }
  return '';
}

function formatRelativeTime(ts: number): string {
  const now = Date.now();
  const diff = now - ts;
  const minutes = Math.floor(diff / 60000);
  if (minutes < 1) {
    return '刚刚';
  }
  if (minutes < 60) {
    return `${minutes} 分钟前`;
  }
  const hours = Math.floor(minutes / 60);
  if (hours < 24) {
    return `${hours} 小时前`;
  }
  const days = Math.floor(hours / 24);
  if (days === 1) {
    return '昨天';
  }
  if (days < 7) {
    return `${days} 天前`;
  }
  const weeks = Math.floor(days / 7);
  if (weeks <= 1) {
    return '1 周前';
  }
  if (weeks < 4) {
    return `${weeks} 周前`;
  }
  const months = Math.floor(days / 30);
  if (months <= 1) {
    return '1 个月前';
  }
  if (months < 12) {
    return `${months} 个月前`;
  }
  const years = Math.floor(months / 12);
  return `${years} 年前`;
}

@CustomDialog
export struct CreatePersonBottomSheet {
  controller: CustomDialogController;
  @State displayName: string = '';
  onCreated?: () => void;

  build() {
    Column({ space: 16 }) {
      Text('新建人物')
        .fontSize($r('app.float.ts_font_title'))
        .fontColor($r('app.color.ts_text_primary'))
        .fontWeight(FontWeight.Bold)
        .width('100%')

      TextInputWithKeyboard({
        placeholder: '显示名（必填）',
        value: this.displayName,
        onChange: (v: string): void => {
          this.displayName = v;
        },
        onSubmit: (): void => {
          this.doCreate();
        }
      })

      Button('创建')
        .width('100%')
        .height(48)
        .fontSize($r('app.float.ts_font_body'))
        .fontWeight(FontWeight.Medium)
        .backgroundColor($r('app.color.ts_brand_primary'))
        .fontColor($r('app.color.ts_import_bar_on_bg'))
        .onClick((): void => {
          this.doCreate();
        })
    }
    .width('100%')
    .padding(24)
    .backgroundColor($r('app.color.ts_surface'))
    .borderRadius({ topLeft: 16, topRight: 16 })
  }

  private doCreate(): void {
    const svc = getPersonService();
    const id = svc.createPerson(this.displayName);
    if (id < 0) {
      promptAction.showToast({ message: '请输入非空显示名' });
      return;
    }
    this.displayName = '';
    promptAction.showToast({ message: `已创建人物 #${id}` });
    this.controller.close();
    this.onCreated?.();
  }
}

@Component
export struct PersonPage {
  @State private persons: PersonModel[] = [];
  /** 当前正在左滑删除的 person id，用于 SwipeAction builder 回调。 */
  @State private swipedPersonId: number = -1;
  createDialogController: CustomDialogController | null = new CustomDialogController({
    builder: CreatePersonBottomSheet({ onCreated: (): void => this.reload() }),
    alignment: DialogAlignment.Bottom,
    customStyle: true,
    autoCancel: true,
    cornerRadius: { topLeft: 16, topRight: 16 }
  });

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    this.persons = getPersonService().listPersons();
  }

  private openCreateSheet(): void {
    dismissSoftKeyboard();
    this.createDialogController?.open();
  }

  private confirmDeletePerson(p: PersonModel): void {
    AlertDialog.show({
      title: '确认删除',
      message: `确定要删除"${p.displayName}"吗？此操作不可撤销，将同时移除该人物的所有关联与照片挂载。`,
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
          const ok = svc.deletePerson(p.id);
          if (ok) {
            promptAction.showToast({ message: `已删除"${p.displayName}"` });
          } else {
            promptAction.showToast({ message: '删除失败：人物不存在' });
          }
          this.reload();
        }
      }
    });
  }

  @Builder
  swipeDeleteBuilder() {
    Button('删除')
      .height('100%')
      .fontSize($r('app.float.ts_font_body'))
      .fontColor(Color.White)
      .backgroundColor(Color.Red)
      .borderRadius(0)
      .padding({ left: 16, right: 16 })
      .onClick((): void => {
        const p = this.getSwipedPerson();
        if (p !== null) {
          this.confirmDeletePerson(p);
        }
      })
  }

  private getSwipedPerson(): PersonModel | null {
    for (const p of this.persons) {
      if (p.id === this.swipedPersonId) {
        return p;
      }
    }
    return null;
  }

  build() {
    Column({ space: 0 }) {
      Column({ space: 0 }) {
        Row({ space: 10 }) {
          Text('人物')
            .fontSize($r('app.float.ts_font_title'))
            .fontColor($r('app.color.ts_text_primary'))
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)

          Button('人脸建议')
            .fontSize($r('app.float.ts_font_support'))
            .height(36)
            .padding({ left: 14, right: 14 })
            .backgroundColor($r('app.color.ts_color_info_container'))
            .fontColor($r('app.color.ts_color_info'))
            .onClick((): void => {
              dismissSoftKeyboard();
              router.pushUrl({ url: 'pages/suggest/SuggestPage' });
            })

          Button('+ 创建')
            .fontSize($r('app.float.ts_font_support'))
            .height(36)
            .padding({ left: 14, right: 14 })
            .backgroundColor($r('app.color.ts_brand_primary'))
            .fontColor($r('app.color.ts_import_bar_on_bg'))
            .onClick((): void => {
              this.openCreateSheet();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16, top: 12, bottom: 10 })

        Divider().color($r('app.color.ts_outline')).margin({ left: 16, right: 16 })

        if (this.persons.length === 0) {
          Column({ space: 8 }) {
            Text('还没有人物档案')
              .fontSize($r('app.float.ts_font_headline'))
              .fontColor($r('app.color.ts_text_secondary'))
            Text('点击右上角 [+ 创建] 来添加人物；也可从详情页导入相册。')
              .fontSize($r('app.float.ts_font_caption'))
              .fontColor($r('app.color.ts_text_tertiary'))
              .lineHeight(18)
          }
          .width('100%')
          .padding({ top: 32, left: 24, right: 24 })
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        } else {
          List({ space: 10 }) {
            ForEach(this.persons, (p: PersonModel) => {
              ListItem() {
                Row({ space: 12 }) {
                  Stack() {
                    Circle()
                      .width(48)
                      .height(48)
                      .fill($r('app.color.ts_surface_container_high'))
                    Text(p.displayName.charAt(0))
                      .fontSize(18)
                      .fontColor($r('app.color.ts_text_muted'))
                  }
                  .width(48)
                  .height(48)

                  Column({ space: 2 }) {
                    Text(p.displayName)
                      .fontSize(18)
                      .fontColor($r('app.color.ts_text_primary'))
                      .fontWeight(FontWeight.Medium)
                      .lineHeight(26)

                    Text(this.typeGenderSummary(p))
                      .fontSize(13)
                      .fontColor($r('app.color.ts_text_tertiary'))
                      .lineHeight(18)

                    Row({ space: 4 }) {
                      Text(this.photoCountSummary(p))
                        .fontSize(12)
                        .fontColor($r('app.color.ts_text_caption'))
                      Text('更新于 ' + formatRelativeTime(p.updatedAt))
                        .fontSize(12)
                        .fontColor($r('app.color.ts_text_muted'))
                    }
                    .width('100%')
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .onClick((): void => {
                  dismissSoftKeyboard();
                  router.pushUrl({
                    url: 'pages/person/PersonDetailPage',
                    params: { personId: `${p.id}` }
                  });
                })
              }
              .swipeAction({
                end: {
                  builder: (): void => {
                    this.swipeDeleteBuilder();
                  },
                  onAction: (): void => {
                    this.confirmDeletePerson(p);
                  },
                  actionAreaDistance: 56
                },
                edgeEffect: SwipeEdgeEffect.Spring,
                onOffsetChange: (_offset: number): void => {
                  this.swipedPersonId = p.id;
                }
              })
            }, (p: PersonModel): string => `person-${p.id}`)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.ts_surface'))
  }

  private typeGenderSummary(p: PersonModel): string {
    const tl = typeLabel(p.personType);
    const gl = genderLabel(p.gender);
    if (gl !== '') {
      return `${tl} · ${gl}`;
    }
    return tl;
  }

  private photoCountSummary(p: PersonModel): string {
    const svc = getPersonService();
    const photoCount = svc.listPersonPhotos(p.id).length;
    const storyCount = svc.listLinkedStories(p.id).length;
    return `${photoCount} 张 · ${storyCount} 个故事`;
  }
}