/**
 * Tier2 · 故事域回归（V2-D2）。
 * 组件定位、滚动、跳转与 entry/src/main/ets/pages/story/ 源码精确对齐。
 */
import { afterEach, describe, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  assertTextExist,
  clickButtonByText,
  clickDetailDebugInjectAlbum,
  clickDetailDebugSameUriAgain,
  coldStartMainApp,
  createStoryOnPage,
  inputStoryDetailSecondTextInput,
  navigateToStoryFromShell,
  openStoryListRowByTitle,
  safeFindComponents,
  scrollDetailUntilVisible,
  sleepMs,
  V2_TIMEOUT
} from './V2RegressionTestKit';

export default function v2RegressionStory(): void {
  describe('V2RegressionStory', () => {
    afterEach(async () => {
      await sleepMs(200);
    });

    it('V2_D2_story_create_and_detail', 0, async () => {
      const driver = await coldStartMainApp();
      await assertTextExist(driver, '时光故事');
      await navigateToStoryFromShell(driver);
      await assertTextExist(driver, '新建故事');

      const storyTitle = `V2D2_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await assertTextExist(driver, storyTitle, V2_TIMEOUT.NORMAL);

      await openStoryListRowByTitle(driver, storyTitle);
      await assertTextExist(driver, '故事详情');
    });

    it('V2_D2_story_detail_edit_title', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);

      const storyTitle = `V2Edt_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertTextExist(driver, '故事详情');

      // 修改标题
      const updatedTitle = `V2EdtUpd_${Date.now()}`;
      const inputs = await driver.findComponents(ON.type('TextInput'));
      if (inputs !== null && inputs.length >= 1) {
        await inputs[0].inputText(updatedTitle);
      }
      await clickButtonByText(driver, '保存标题');
      await driver.waitForIdle(300, 800);
      // 验证更新后的标题出现在详情页头部
      await assertTextExist(driver, updatedTitle, V2_TIMEOUT.NORMAL);
    });

    it('V2_D2_story_quick_person_link', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);

      const storyTitle = `V2Lnk_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertTextExist(driver, '关联人物');

      // 快速创建人物
      const pName = `QuickPer_${Date.now()}`;
      await inputStoryDetailSecondTextInput(driver, pName);
      await clickButtonByText(driver, '创建人物');
      await driver.waitForIdle(300, 800);

      // 关联刚创建的人物
      await scrollDetailUntilVisible(driver, ON.text('关联'));
      const linkBtns = await safeFindComponents(driver, ON.text('关联'));
      if (linkBtns.length === 0) {
        throw new Error('故事详情未找到「关联」');
      }
      await linkBtns[linkBtns.length - 1].click();
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '解除关联', V2_TIMEOUT.NORMAL);
    });

    it('V2_D2_story_debug_album_ph01', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);

      const storyTitle = `V2Alb_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertTextExist(driver, '故事详情');

      // DEBUG 注入相册等价 URI
      await clickDetailDebugInjectAlbum(driver);
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '【E2E】上次加图：成功 file://e2e/album-equiv-story-1', V2_TIMEOUT.NORMAL);

      // 再注相同 URI — 验证 PH-01 去重
      await clickDetailDebugSameUriAgain(driver);
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '【E2E】上次加图：重复跳过（PH-01）', V2_TIMEOUT.NORMAL);
    });
  });
}