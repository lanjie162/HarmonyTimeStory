import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type { PersonModel } from '../../domain/model/Models';
import { getPersonService } from '../../features/person/PersonFeature';

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

  build() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Text('人物')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Button('建议')
          .fontSize(13)
          .height(32)
          .padding({ left: 12, right: 12 })
          .backgroundColor('#E3F2FD')
          .fontColor('#1565C0')
          .onClick((): void => {
            router.pushUrl({ url: 'pages/suggest/SuggestPage' });
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        Button('返回主壳')
          .onClick((): void => {
            router.back();
          })
        Button('故事 Tab')
          .onClick((): void => {
            router.pushUrl({ url: 'pages/story/StoryPage' });
          })
      }

      if (this.persons.length === 0) {
        Text('还没有人物档案。下方输入显示名并创建。')
          .fontColor('#666666')
          .width('100%')
      } else {
        List({ space: 0 }) {
          ForEach(this.persons, (p: PersonModel) => {
            ListItem() {
              Row() {
                Text(p.displayName).fontSize(18).layoutWeight(1)
                Text(`#${p.id}`).fontColor('#888888')
              }
              .width('100%')
              .padding(12)
              .onClick((): void => {
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
      }

      Divider()

      Text('新建人物').fontWeight(FontWeight.Medium).width('100%')
      TextInput({ placeholder: '显示名（必填）', text: this.newDisplayName })
        .onChange((v: string): void => {
          this.newDisplayName = v;
        })
        .width('100%')
      Button('创建人物').onClick((): void => {
        this.createPerson();
      })
    }
    .padding(16)
    .width('100%')
    .height('100%')
  }
}
