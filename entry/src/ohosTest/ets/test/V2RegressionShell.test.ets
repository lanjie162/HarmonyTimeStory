/**
 * Tier2 · Shell 壳页与 Tab 导航回归（V2-D0）。
 * 组件定位与 entry/src/main/ets/pages/shell/ShellPage.ets 源码精确对齐。
 *
 * ShellPage Tabs: 人物(index 0) + 故事(index 1)。
 * PersonPage 为默认 Tab，含「人脸建议」「+ 创建」按钮。
 * StoryPage 含「+ 创建」按钮。
 */
import { afterEach, describe, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  assertTextExist,
  clickComponentSafely,
  coldStartMainApp,
  navigateToPersonFromShell,
  navigateToStoryFromShell,
  safeFindComponents,
  sleepMs,
  V2_TIMEOUT
} from './V2RegressionTestKit';

export default function v2RegressionShell(): void {
  describe('Tier2A_V2RegressionShell', () => {
    afterEach(async () => {
      await sleepMs(200);
    });

    it('V2_D0_shell_main_entries', 0, async () => {
      const driver = await coldStartMainApp();
      // 验证壳页「人物」Tab 可见（当前默认 Tab）
      await assertTextExist(driver, '人物');

      // 切换到人物 Tab → 验证「人脸建议」（人物页独有元素）
      await navigateToPersonFromShell(driver);
      await assertTextExist(driver, '人脸建议', V2_TIMEOUT.NORMAL);

      // 切换到故事 Tab → 验证「+ 创建」（故事页独有元素）
      await navigateToStoryFromShell(driver);
      await assertTextExist(driver, '+ 创建', V2_TIMEOUT.NORMAL);

      // 切回人物 Tab 验证「人脸建议」仍可见
      await navigateToPersonFromShell(driver);
      await assertTextExist(driver, '人脸建议', V2_TIMEOUT.NORMAL);
    });

    it('V2_D0_tab_switch', 0, async () => {
      const driver = await coldStartMainApp();

      // 壳页 → 人物 Tab
      await navigateToPersonFromShell(driver);
      await assertTextExist(driver, '人脸建议');

      // 切换到故事 Tab
      await navigateToStoryFromShell(driver);
      await assertTextExist(driver, '+ 创建', V2_TIMEOUT.NORMAL);

      // 切回人物 Tab
      await navigateToPersonFromShell(driver);
      await assertTextExist(driver, '人脸建议', V2_TIMEOUT.NORMAL);
    });
  });
}
