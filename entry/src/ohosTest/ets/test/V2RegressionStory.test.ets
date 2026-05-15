/**
 * Tier2 · 故事域回归（V2-D2）。
 * **TR / 验收锚点**：派发任务请填写 `TR-…#C-n` 与下列 `it` 名称对照；无派发时以需求章节与 evidence 索引为准。
 * 权威索引示例：document/evidence/V2/2026-05-10-T9-V2-D1-D4-plan-and-execution-index.md
 */
import { afterEach, describe, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  clickDetailDebugInjectAlbum,
  clickDetailDebugSameUriAgain,
  coldStartMainApp,
  inputStoryDetailSecondTextInput,
  openStoryListRowByTitle,
  safeFindComponents,
  scrollDetailUntilVisible,
  sleepMs
} from './V2RegressionTestKit';

export default function v2RegressionStory(): void {
  describe('V2RegressionStory', () => {
    afterEach(async () => {
      await sleepMs(450);
    });
    it('V2_D2_story_main_create_and_detail', 0, async () => {
      const driver = await coldStartMainApp();
      await driver.assertComponentExist(ON.text('时光故事'));
      const btnStory = await driver.findComponent(ON.text('故事'));
      await btnStory.click();
      await driver.waitForIdle(3000, 6000);
      await driver.assertComponentExist(ON.text('新建故事'));
      const storyTitle = `V2D2_${Date.now()}`;
      const inputTitle = await driver.findComponent(ON.type('TextInput'));
      await inputTitle.inputText(storyTitle);
      const createStory = await driver.findComponent(ON.text('创建故事'));
      await createStory.click();
      await driver.waitForIdle(2000, 5000);
      await driver.assertComponentExist(ON.text(storyTitle));
      await openStoryListRowByTitle(driver, storyTitle);
      await driver.waitForIdle(3000, 6000);
      await driver.assertComponentExist(ON.text('故事详情'));
    });

    it('V2_D2_story_detail_quick_person_link_toggle', 0, async () => {
      const driver = await coldStartMainApp();
      const btnStory = await driver.findComponent(ON.text('故事'));
      await btnStory.click();
      await driver.waitForIdle(3000, 6000);
      const storyTitle = `V2D2lnk_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(storyTitle);
      await (await driver.findComponent(ON.text('创建故事'))).click();
      await driver.waitForIdle(2000, 5000);
      await openStoryListRowByTitle(driver, storyTitle);
      await driver.waitForIdle(3000, 6000);
      await driver.assertComponentExist(ON.text('关联人物'));
      const pName = `QuickPer_${Date.now()}`;
      await inputStoryDetailSecondTextInput(driver, pName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await scrollDetailUntilVisible(driver, ON.text('关联'));
      const linkBtns = await safeFindComponents(driver, ON.text('关联'));
      if (linkBtns.length === 0) {
        throw new Error('故事详情未找到「关联」');
      }
      await linkBtns[linkBtns.length - 1].click();
      await driver.waitForIdle(1500, 4000);
      await driver.assertComponentExist(ON.text('解除关联'));
    });

    it('V2_D2_story_debug_album_equiv_and_ph01', 0, async () => {
      const driver = await coldStartMainApp();
      await (await driver.findComponent(ON.text('故事'))).click();
      await driver.waitForIdle(3000, 6000);
      const storyTitle = `V2albs_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(storyTitle);
      await (await driver.findComponent(ON.text('创建故事'))).click();
      await driver.waitForIdle(2000, 5000);
      await openStoryListRowByTitle(driver, storyTitle);
      await driver.waitForIdle(2500, 6000);
      await clickDetailDebugInjectAlbum(driver);
      await driver.waitForIdle(900, 3000);
      await driver.assertComponentExist(ON.text('【E2E】上次加图：成功 file://e2e/album-equiv-story-1'));
      await clickDetailDebugSameUriAgain(driver);
      await driver.waitForIdle(900, 3000);
      await driver.assertComponentExist(ON.text('【E2E】上次加图：重复跳过（PH-01）'));
    });
  });
}
