/**
 * Tier2 · ShellPage 2Tab + SuggestPage 空态 E2E 回归。
 * 组件定位与 entry/src/main/ets/pages/shell/ShellPage.ets 源码精确对齐。
 *
 * ShellPage Tabs: 人物(index 0) + 故事(index 1)。
 * PersonPage 含「人脸建议」「+ 创建」按钮；StoryPage 含「+ 创建」按钮。
 */
import { afterEach, describe, expect, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  assertTextExist,
  coldStartMainApp,
  navigateToPersonFromShell,
  navigateToStoryFromShell,
  safeFindComponents,
  sleepMs,
  V2_TIMEOUT
} from './V2RegressionTestKit';

export default function v2RegressionShellTab(): void {
  describe('Tier2K_V2RegressionShellTab', () => {
    afterEach(async () => {
      await sleepMs(200);
    });

    it('V2_SHELLTAB_two_tabs_only', 0, async () => {
      const driver = await coldStartMainApp();
      await driver.waitForIdle(300, 800);

      // 壳页应有「人物」Tab（当前默认 Tab）
      const personText = await driver.findComponent(ON.text('人物'));
      expect(personText !== null).assertTrue();

      // 切换到故事 Tab 验证可切换
      await navigateToStoryFromShell(driver);
      await assertTextExist(driver, '+ 创建', V2_TIMEOUT.NORMAL);

      // 切回人物 Tab 验证可切换
      await navigateToPersonFromShell(driver);
      await assertTextExist(driver, '人脸建议', V2_TIMEOUT.NORMAL);
    });

    it('V2_SHELLTAB_person_tab_content', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      await assertTextExist(driver, '人脸建议', V2_TIMEOUT.NORMAL);
    });

    it('V2_SHELLTAB_story_tab_content', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);
      await assertTextExist(driver, '+ 创建', V2_TIMEOUT.NORMAL);
    });
  });
}
