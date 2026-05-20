import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type { PersonModel, PersonTypeEnum } from '../../domain/model/Models';
import { PersonTypeEnum as PT } from '../../domain/model/Models';
import { getPersonService } from '../../features/person/PersonFeature';
import { dismissSoftKeyboard } from '../../common/ime/SoftKeyboard';
import { MainTabBar } from '../../common/ui/MainTabBar';

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

@Entry
@Component
export struct PersonPage {
  @State private persons: PersonModel[] = [];
  @State private newDisplayName: string = '';

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    this.persons = getPersonService().listPersons();
  }

  private createPerson(): void {
    dismissSoftKeyboard();
    const svc = getPersonService();
    const id = svc.createPerson(this.newDisplayName);
    if (id < 0) {
      promptAction.showToast({ message: '请输入非空显示名' });
      return;
    }
    this.newDisplayName = '';
    promptAction.showToast({ message: `已创建人物 #${id}` });
    this.reload();
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

  build() {
    Column({ space: 0 }) {
      Column({ space: 0 }) {
        Row({ space: 10 }) {
          Button('返回')
            .height(36)
            .fontSize($r('app.float.ts_font_support'))
            .backgroundColor($r('app.color.ts_surface_container_high'))
            .fontColor($r('app.color.ts_text_secondary'))
            .onClick((): void => {
              dismissSoftKeyboard();
              router.replaceUrl({ url: 'pages/shell/ShellPage' });
            })
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
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16, top: 12, bottom: 10 })

        Column({ space: 14 }) {
          Text('新建人物')
            .fontSize($r('app.float.ts_font_label'))
            .fontColor($r('app.color.ts_text_secondary'))
            .fontWeight(FontWeight.Medium)
            .width('100%')
          TextInput({ placeholder: '显示名（必填）', text: this.newDisplayName })
            .onChange((v: string): void => {
              this.newDisplayName = v;
            })
            .enterKeyType(EnterKeyType.Done)
            .onSubmit((): void => {
              this.createPerson();
            })
            .width('100%')
            .height(48)
            .backgroundColor($r('app.color.ts_surface_container_high'))
            .borderRadius(10)
            .padding({ left: 12, right: 12 })
          Button('创建人物')
            .width('100%')
            .height(48)
            .fontSize($r('app.float.ts_font_body'))
            .fontWeight(FontWeight.Medium)
            .backgroundColor($r('app.color.ts_brand_primary'))
            .fontColor($r('app.color.ts_import_bar_on_bg'))
            .onClick((): void => {
              this.createPerson();
            })
        }
        .width('100%')
        .padding(16)
        .margin({ left: 16, right: 16, bottom: 12 })
        .backgroundColor($r('app.color.ts_surface_container'))
        .borderRadius(12)
        .border({ width: 1, color: $r('app.color.ts_outline') })

        Divider().color($r('app.color.ts_outline')).margin({ left: 16, right: 16 })

        if (this.persons.length === 0) {
          Column({ space: 8 }) {
            Text('还没有人物档案')
              .fontSize($r('app.float.ts_font_headline'))
              .fontColor($r('app.color.ts_text_secondary'))
            Text('创建后会在下方列表显示；也可从详情页导入相册。')
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
                Column({ space: 6 }) {
                  Row() {
                    Text(p.displayName)
                      .fontSize($r('app.float.ts_font_headline'))
                      .fontColor($r('app.color.ts_text_primary'))
                      .fontWeight(FontWeight.Medium)
                      .layoutWeight(1)
                    Text(typeLabel(p.personType))
                      .fontSize($r('app.float.ts_font_overline'))
                      .fontColor($r('app.color.ts_text_muted'))
                      .backgroundColor($r('app.color.ts_surface_container_high'))
                      .borderRadius(8)
                      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                  }
                  .width('100%')
                  Row({ space: 8 }) {
                    Text('档案、故事与照片')
                      .fontSize($r('app.float.ts_font_overline'))
                      .fontColor($r('app.color.ts_text_tertiary'))
                      .layoutWeight(1)
                    Button('删除')
                      .height(28)
                      .fontSize($r('app.float.ts_font_overline'))
                      .backgroundColor($r('app.color.ts_surface_container_high'))
                      .fontColor('#CC0000')
                      .onClick((): void => {
                        this.confirmDeletePerson(p);
                      })
                  }
                  .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .padding({ left: 16, right: 16, top: 14, bottom: 14 })
                .backgroundColor($r('app.color.ts_surface_container'))
                .borderRadius(12)
                .border({ width: 1, color: $r('app.color.ts_outline') })
                .onClick((): void => {
                  dismissSoftKeyboard();
                  router.pushUrl({
                    url: 'pages/person/PersonDetailPage',
                    params: { personId: `${p.id}` }
                  });
                })
              }
            }, (p: PersonModel): string => `person-${p.id}`)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        }
      }
      .layoutWeight(1)
      .width('100%')

      MainTabBar({ currentTab: 'person' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.ts_surface'))
  }
}
