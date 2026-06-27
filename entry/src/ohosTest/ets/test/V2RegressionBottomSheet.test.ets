/**
 * Tier2 · BottomSheet 创建回归（全局组件 §D）。
 * 组件定位与 entry/src/main/ets/pages/person/PersonPage.ets +
 * entry/src/main/ets/pages/story/StoryPage.ets 源码精确对齐。
 *
 * PersonPage: [+ 创建] → bindSheet（新建人物 + TextInput + 创建 按钮）
 * StoryPage:  [+ 创建] → bindSheet（新建故事 + TextInput + 创建 按钮）
 */
import { afterEach, describe, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  assertTextExist,
  assertTextInList,
  clickComponentSafely,
  coldStartMainApp,
  createPersonOnPage,
  createStoryOnPage,
  navigateToPersonFromShell,
  navigateToStoryFromShell,
  sleepMs,
  V2_TIMEOUT
} from './V2RegressionTestKit';

export default function v2RegressionBottomSheet(): void {
  describe('Tier2G_V2RegressionBottomSheet', () => {
    afterEach(async () => {
      await sleepMs(200);
    });

    it('V2_BOTTOMSHEET_open_person', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      await assertTextExist(driver, '人脸建议');

      // 点击「+ 创建」按钮 → bindSheet 弹出
      await clickComponentSafely(driver, ON.text('+ 创建'), V2_TIMEOUT.NORMAL);
      // 验证 bindSheet 弹出：等待「新建人物」标题
      await assertTextExist(driver, '新建人物', V2_TIMEOUT.NORMAL);
      await assertTextExist(driver, '创建', V2_TIMEOUT.NORMAL);

      // 关闭 Sheet（按返回）
      await driver.pressBack();
      await driver.waitForIdle(300, 800);
    });

    it('V2_BOTTOMSHEET_create_person', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      await assertTextExist(driver, '人脸建议');

      // 使用 createPersonOnPage 创建人物
      const personName = `V2BS_${Date.now()}`;
      await createPersonOnPage(driver, personName);

      // 验证列表刷新 — 新人物应出现在列表中
      await assertTextInList(driver, personName, V2_TIMEOUT.NORMAL);
    });

    it('V2_BOTTOMSHEET_open_story', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);
      await assertTextExist(driver, '+ 创建');

      // 点击「+ 创建」按钮 → bindSheet 弹出
      await clickComponentSafely(driver, ON.text('+ 创建'), V2_TIMEOUT.NORMAL);
      // 验证 bindSheet 弹出：等待「新建故事」标题
      await assertTextExist(driver, '新建故事', V2_TIMEOUT.NORMAL);
      await assertTextExist(driver, '创建', V2_TIMEOUT.NORMAL);

      // 关闭 Sheet（按返回）
      await driver.pressBack();
      await driver.waitForIdle(300, 800);
    });

    it('V2_BOTTOMSHEET_create_story', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);
      await assertTextExist(driver, '+ 创建');

      // 使用 createStoryOnPage 创建故事
      const storyTitle = `V2BS_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);

      // 验证列表刷新
      await assertTextInList(driver, storyTitle, V2_TIMEOUT.NORMAL);
    });
  });
}
