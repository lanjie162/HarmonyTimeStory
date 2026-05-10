import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type { StoryModel } from '../../domain/model/Models';
import { getStoryService } from '../../features/story/StoryFeature';
import { dismissSoftKeyboard } from '../../common/ime/SoftKeyboard';

@Entry
@Component
export struct StoryPage {
  @State private stories: StoryModel[] = [];
  @State private newTitle: string = '';

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    this.stories = getStoryService().listStories();
  }

  private createStory(): void {
    // 提交前先收键盘，避免遮挡 toast / 列表底部新行
    dismissSoftKeyboard();
    const svc = getStoryService();
    const id = svc.createStory(this.newTitle);
    if (id < 0) {
      promptAction.showToast({ message: '请输入非空标题' });
      return;
    }
    this.newTitle = '';
    promptAction.showToast({ message: `已创建故事 #${id}` });
    this.reload();
  }

  build() {
    Column({ space: 12 }) {
      Text('故事')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .width('100%')

      Row({ space: 8 }) {
        Button('返回主壳')
          .onClick((): void => {
            dismissSoftKeyboard();
            router.back();
          })
        Button('人物 Tab')
          .onClick((): void => {
            dismissSoftKeyboard();
            router.pushUrl({ url: 'pages/person/PersonPage' });
          })
      }

      Text('新建故事').fontWeight(FontWeight.Medium).width('100%')
      TextInput({ placeholder: '标题（必填）', text: this.newTitle })
        .onChange((v: string): void => {
          this.newTitle = v;
        })
        .enterKeyType(EnterKeyType.Done)
        .onSubmit((): void => {
          this.createStory();
        })
        .width('100%')
      Button('创建故事').onClick((): void => {
        this.createStory();
      })

      Divider()

      if (this.stories.length === 0) {
        Text('还没有故事。创建后将在下列显示。')
          .fontColor('#666666')
          .width('100%')
      } else {
        List({ space: 0 }) {
          ForEach(this.stories, (s: StoryModel) => {
            ListItem() {
              Row() {
                Text(s.title).fontSize(18).layoutWeight(1)
                Text(`#${s.id}`).fontColor('#888888')
              }
              .width('100%')
              .padding(12)
              .onClick((): void => {
                dismissSoftKeyboard();
                router.pushUrl({
                  url: 'pages/story/StoryDetailPage',
                  params: { storyId: `${s.id}` }
                });
              })
            }
          }, (s: StoryModel): string => `story-${s.id}`)
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .padding(16)
    .width('100%')
    .height('100%')
  }
}
