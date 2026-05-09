import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

interface SuggestItem {
  id: string;
  title: string;
  subtitle: string;
}

@Entry
@Component
export struct SuggestPage {
  @State private items: SuggestItem[] = [
    { id: 'demo-1', title: '候选示例 · 照片组 A', subtitle: '来源占位：人物相册聚类（可测骨架）' }
  ];
  @State private acceptedIds: string[] = [];
  @State private ignoredIds: string[] = [];

  private isAccepted(id: string): boolean {
    return this.acceptedIds.indexOf(id) >= 0;
  }

  private isIgnored(id: string): boolean {
    return this.ignoredIds.indexOf(id) >= 0;
  }

  private acceptOne(item: SuggestItem): void {
    if (this.isIgnored(item.id)) {
      promptAction.showToast({ message: '已忽略项不可重复接受（可测占位）' });
      return;
    }
    if (this.isAccepted(item.id)) {
      return;
    }
    this.acceptedIds = [...this.acceptedIds, item.id];
    promptAction.showToast({ message: `已接受：${item.title}` });
  }

  private ignoreOne(item: SuggestItem): void {
    if (this.isAccepted(item.id)) {
      promptAction.showToast({ message: '已接受项不可忽略（可测占位）' });
      return;
    }
    if (this.isIgnored(item.id)) {
      return;
    }
    this.ignoredIds = [...this.ignoredIds, item.id];
    promptAction.showToast({ message: `已忽略：${item.title}` });
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        Button('返回')
          .onClick((): void => {
            router.back();
          })
        Text('建议审阅')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')

      Text('§4.6 形态三 · 顶栏说明（对齐 v1.2 可测骨架）')
        .fontSize(12)
        .fontColor('#37474F')
        .fontWeight(FontWeight.Medium)
        .width('100%')
      Text(
        '本页用于「建议审阅」：展示系统根据人物相册聚类等生成的候选分组。你可逐条「接受」写入后续主链，或「忽略」本轮不处理。以下为最小可测列表（单条动作）。'
      )
        .fontSize(12)
        .fontColor('#555555')
        .width('100%')

      Divider()

      Text('候选列表').fontWeight(FontWeight.Medium).width('100%')

      List({ space: 8 }) {
        ForEach(this.items, (item: SuggestItem) => {
          ListItem() {
            Column({ space: 8 }) {
              Text(item.title).fontSize(16).width('100%')
              Text(item.subtitle).fontSize(12).fontColor('#666666').width('100%')
              Row({ space: 8 }) {
                Button('接受')
                  .enabled(!this.isIgnored(item.id) && !this.isAccepted(item.id))
                  .onClick((): void => {
                    this.acceptOne(item);
                  })
                Button('忽略')
                  .enabled(!this.isAccepted(item.id) && !this.isIgnored(item.id))
                  .onClick((): void => {
                    this.ignoreOne(item);
                  })
              }
              if (this.isAccepted(item.id)) {
                Text('状态：已接受').fontColor('#2E7D32').fontSize(12)
              } else if (this.isIgnored(item.id)) {
                Text('状态：已忽略').fontColor('#757575').fontSize(12)
              }
            }
            .padding(12)
            .width('100%')
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
          }
        }, (item: SuggestItem): string => item.id)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .padding(16)
    .width('100%')
    .height('100%')
  }
}
