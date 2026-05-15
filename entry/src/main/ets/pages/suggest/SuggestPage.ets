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
    Column({ space: 0 }) {
      Row({ space: 10 }) {
        Button('返回')
          .height(36)
          .fontSize($r('app.float.ts_font_support'))
          .backgroundColor($r('app.color.ts_surface_container_high'))
          .fontColor($r('app.color.ts_text_secondary'))
          .onClick((): void => {
            router.back();
          })
        Text('建议审阅')
          .fontSize($r('app.float.ts_font_title'))
          .fontColor($r('app.color.ts_text_primary'))
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 8 }) {
            Text('4.6 形态三 · 顶栏说明（对齐 v1.2 可测骨架）')
              .fontSize($r('app.float.ts_font_support'))
              .fontColor($r('app.color.ts_text_secondary'))
              .fontWeight(FontWeight.Medium)
              .width('100%')
            Text(
              '本页用于「建议审阅」：展示系统根据人物相册聚类等生成的候选分组。你可逐条「接受」写入后续主链，或「忽略」本轮不处理。以下为最小可测列表（单条动作）。'
            )
              .fontSize($r('app.float.ts_font_caption'))
              .fontColor($r('app.color.ts_text_tertiary'))
              .lineHeight(18)
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.ts_color_info_container'))
          .borderRadius(12)
          .border({ width: 1, color: $r('app.color.ts_outline') })

          Text('候选列表')
            .fontSize($r('app.float.ts_font_label'))
            .fontColor($r('app.color.ts_text_primary'))
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .padding({ left: 4 })

          List({ space: 10 }) {
            ForEach(this.items, (item: SuggestItem) => {
              ListItem() {
                Column({ space: 10 }) {
                  Text(item.title)
                    .fontSize($r('app.float.ts_font_headline'))
                    .fontColor($r('app.color.ts_text_primary'))
                    .fontWeight(FontWeight.Medium)
                    .width('100%')
                  Text(item.subtitle)
                    .fontSize($r('app.float.ts_font_caption'))
                    .fontColor($r('app.color.ts_text_tertiary'))
                    .width('100%')
                  Row({ space: 10 }) {
                    Button('接受')
                      .layoutWeight(1)
                      .height(40)
                      .fontSize($r('app.float.ts_font_support'))
                      .fontWeight(FontWeight.Medium)
                      .enabled(!this.isIgnored(item.id) && !this.isAccepted(item.id))
                      .backgroundColor($r('app.color.ts_brand_primary'))
                      .fontColor($r('app.color.ts_import_bar_on_bg'))
                      .onClick((): void => {
                        this.acceptOne(item);
                      })
                    Button('忽略')
                      .layoutWeight(1)
                      .height(40)
                      .fontSize($r('app.float.ts_font_support'))
                      .enabled(!this.isAccepted(item.id) && !this.isIgnored(item.id))
                      .backgroundColor($r('app.color.ts_surface_container_high'))
                      .fontColor($r('app.color.ts_text_secondary'))
                      .onClick((): void => {
                        this.ignoreOne(item);
                      })
                  }
                  .width('100%')
                  if (this.isAccepted(item.id)) {
                    Text('状态：已接受')
                      .fontColor($r('app.color.ts_color_success'))
                      .fontSize($r('app.float.ts_font_caption'))
                  } else if (this.isIgnored(item.id)) {
                    Text('状态：已忽略')
                      .fontColor($r('app.color.ts_text_muted'))
                      .fontSize($r('app.float.ts_font_caption'))
                  }
                }
                .padding(16)
                .width('100%')
                .backgroundColor($r('app.color.ts_surface_container'))
                .borderRadius(12)
                .border({ width: 1, color: $r('app.color.ts_outline') })
              }
            }, (item: SuggestItem): string => item.id)
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 24 })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.ts_surface'))
  }
}
