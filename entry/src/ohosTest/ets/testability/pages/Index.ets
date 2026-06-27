@Entry
@Component
struct Index {
  build() {
    Row() {
      Column() {
        Text('TestAbility')
          .fontSize(50)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
    }
    .height('100%')
  }
}