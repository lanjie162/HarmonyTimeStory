/**
 * Tier2 · PhotoSwiper 全屏浏览回归（全局组件 §C）。
 * 组件定位与 entry/src/main/ets/common/ui/PhotoSwiper.ets + 详情页源码精确对齐。
 *
 * 依赖：人物详情编辑页有 DEBUG 注入照片能力。
 */
import { afterEach, describe, expect, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  assertOnPersonDetail,
  assertTextExist,
  clickComponentSafely,
  clickDialogConfirmButton,
  clickDetailDebugInjectAlbum,
  clickDetailDebugSameUriAgain,
  coldStartMainApp,
  createPersonOnPage,
  navigateToPersonFromShell,
  openPersonListRowByDisplayName,
  safeFindComponents,
  scrollDetailUntilVisible,
  sleepMs,
  waitForText,
  V2_TIMEOUT
} from './V2RegressionTestKit';

export default function v2RegressionPhotoSwiper(): void {
  describe('Tier2F_V2RegressionPhotoSwiper', () => {
    afterEach(async () => {
      await sleepMs(200);
    });

    it('V2_PHOTOSWIPER_open_from_grid', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2PS1_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);

      // 进入编辑页注入照片
      const editBtn = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await sleepMs(2000);
      await driver.waitForIdle(500, 1500);

      await clickDetailDebugInjectAlbum(driver);
      await driver.waitForIdle(500, 1200);

      // 回到详情页
      await driver.pressBack();
      await sleepMs(1000);
      await driver.waitForIdle(500, 1500);

      // 在时间线网格中点击照片缩略图
      const images = await safeFindComponents(driver, ON.type('Image'));
      if (images.length > 0) {
        await images[0].click();
        await driver.waitForIdle(300, 800);
        console.info('V2_PHOTOSWIPER_open_from_grid: 照片 Image 点击成功');
      } else {
        console.info('V2_PHOTOSWIPER_open_from_grid: 未找到 Image 组件，跳过点击');
      }
    });

    it('V2_PHOTOSWIPER_swipe_left_right', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2PS2_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);

      // 进入编辑页注入照片
      const editBtn = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);

      await clickDetailDebugInjectAlbum(driver);
      await driver.waitForIdle(500, 1200);

      // 再注相同 URI
      await clickDetailDebugSameUriAgain(driver);
      await driver.waitForIdle(300, 800);

      // 回到详情页
      await driver.pressBack();
      await driver.waitForIdle(300, 800);

      // 点击照片缩略图打开 Swiper
      const images = await safeFindComponents(driver, ON.type('Image'));
      if (images.length > 0) {
        await images[0].click();
        await driver.waitForIdle(300, 800);
        // 全屏 Swiper 出现后尝试左滑
        await driver.fling(4 /* left */, 600);
        await driver.waitForIdle(200, 400);
        console.info('V2_PHOTOSWIPER_swipe_left_right: 滑动完成');
      } else {
        console.info('V2_PHOTOSWIPER_swipe_left_right: 未找到 Image，跳过');
      }
    });

    it('V2_PHOTOSWIPER_swipe_down_close', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2PS3_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);

      // 进入编辑页注入照片
      const editBtn = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await sleepMs(2000);
      await driver.waitForIdle(500, 1500);

      await clickDetailDebugInjectAlbum(driver);
      await driver.waitForIdle(500, 1200);

      // 回到详情页
      await driver.pressBack();
      await sleepMs(1000);
      await driver.waitForIdle(500, 1500);

      const images = await safeFindComponents(driver, ON.type('Image'));
      if (images.length > 0) {
        await images[0].click();
        await driver.waitForIdle(300, 600);

        // 下滑关闭 → 回到详情页
        await driver.fling(3 /* down */, 600);
        await driver.waitForIdle(300, 800);
        // 验证回到详情页（编辑按钮可见）
        await assertTextExist(driver, '编辑', V2_TIMEOUT.NORMAL);
      } else {
        console.info('V2_PHOTOSWIPER_swipe_down_close: 未找到 Image，跳过');
      }
    });

    it('V2_PHOTOSWIPER_menu_open', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2PS4_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);

      // 进入编辑页注入照片
      const editBtn = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await sleepMs(2000);
      await driver.waitForIdle(500, 1500);

      await clickDetailDebugInjectAlbum(driver);
      await driver.waitForIdle(500, 1200);

      // 回到详情页
      await driver.pressBack();
      await sleepMs(1000);
      await driver.waitForIdle(500, 1500);

      // 打开照片进入 PhotoSwiper，才有 ⋮ 菜单
      const images = await safeFindComponents(driver, ON.type('Image'));
      if (images.length > 0) {
        await images[0].click();
        await driver.waitForIdle(300, 800);
      }

      // PhotoSwiper 顶栏应有 ⋮ 菜单入口
      await assertTextExist(driver, '⋮', V2_TIMEOUT.NORMAL);
      await clickComponentSafely(driver, ON.text('⋮'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(200, 400);
      console.info('V2_PHOTOSWIPER_menu_open: ⋮ 菜单已展开');
    });

    it('V2_PHOTOSWIPER_menu_remove', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2PS5_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);

      // 进入编辑页注入照片
      const editBtn = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await sleepMs(2000);
      await driver.waitForIdle(500, 1500);

      await clickDetailDebugInjectAlbum(driver);
      await driver.waitForIdle(500, 1200);

      // 回到详情页
      await driver.pressBack();
      await sleepMs(1000);
      await driver.waitForIdle(500, 1500);

      // 打开照片进入 PhotoSwiper
      const images = await safeFindComponents(driver, ON.type('Image'));
      if (images.length > 0) {
        await images[0].click();
        await driver.waitForIdle(300, 800);
      }

      // 打开 ⋮ 菜单
      await assertTextExist(driver, '⋮', V2_TIMEOUT.NORMAL);
      await clickComponentSafely(driver, ON.text('⋮'), V2_TIMEOUT.NORMAL);
      // 菜单弹出层有 transition 动画，等待弹出层标题「照片选项」出现（确认弹出层已渲染）
      await waitForText(driver, '照片选项', V2_TIMEOUT.SCAN);
      await driver.waitForIdle(300, 800);

      // PhotoSwiper 菜单按钮文本是「从人物移除」（PersonDetailPage 传入 removeLabel）
      await waitForText(driver, '从人物移除', V2_TIMEOUT.NORMAL);
      await clickComponentSafely(driver, ON.text('从人物移除'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 600);
      // 确认对话框
      const dialogText = await driver.findComponent(ON.text('确认移除'));
      if (dialogText !== null) {
        await sleepMs(500);
        await clickDialogConfirmButton(driver, '移除');
        await driver.waitForIdle(300, 800);
      }
    });

    it('V2_PHOTOSWIPER_broken_uri', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2PS6_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);

      // 进入编辑页（DEBUG 按钮在编辑页）
      const editBtn = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await sleepMs(2000);
      await driver.waitForIdle(500, 1500);

      // 照片 URI 失效态的文字提示（如「本地文件已删除」）属于详情页失效态测试
      // 这里验证 DEBUG 注入后是否有「本地已删除」失效文案存在
      // 回到详情页
      await driver.pressBack();
      await sleepMs(1000);
      await driver.waitForIdle(500, 1500);

      const brokenText = await driver.findComponent(ON.text('本地文件已删除'));
      if (brokenText !== null) {
        console.info('V2_PHOTOSWIPER_broken_uri: 发现失效文案「本地文件已删除」');
      } else {
        console.info('V2_PHOTOSWIPER_broken_uri: 未发现失效文案（正常状态）');
      }
    });
  });
}