/**
 * Tier2 · Shell 壳页与 Tab 导航回归（V2-D0）。
 * 组件定位与 entry/src/main/ets/pages/shell/ShellPage.ets + MainTabBar.ets 源码精确对齐。
 */
import { afterEach, describe, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  assertTextExist,
  clickButtonByText,
  clickComponentSafely,
  coldStartMainApp,
  navigateToPersonFromShell,
  safeFindComponents,
  sleepMs,
  V2_TIMEOUT
} from './V2RegressionTestKit';

export default function v2RegressionShell(): void {
  describe('V2RegressionShell', () => {
    afterEach(async () => {
      await sleepMs(200);
    });

    it('V2_D0_shell_main_entries', 0, async () => {
      const driver = await coldStartMainApp();
      // 验证壳页标题
      await assertTextExist(driver, '时光故事');
      await assertTextExist(driver, '照片留在本机，故事与人物在本地串联。');

      // 点击「人物」入口 → 验证进入人物页
      const personCards = await driver.findComponents(ON.text('人物').type('Column'));
      if (personCards !== null && personCards.length > 0) {
        await personCards[0].click();
      } else {
        await clickComponentSafely(driver, ON.text('人物'));
      }
      await assertTextExist(driver, '新建人物', V2_TIMEOUT.NORMAL);

      // 返回壳页（点击「返回」Tab → replaceUrl 到 ShellPage）
      await clickButtonByText(driver, '返回');
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '时光故事', V2_TIMEOUT.NORMAL);
    });

    it('V2_D0_shell_debug_state', 0, async () => {
      const driver = await coldStartMainApp();
      await assertTextExist(driver, '从上方任选入口开始');

      // 点击调试按钮切换状态 → loading
      await clickButtonByText(driver, '调试：切换占位状态');
      await driver.waitForIdle(300, 600);
      await assertTextExist(driver, '正在准备…');

      // 再次点击 → error
      await clickButtonByText(driver, '调试：切换占位状态');
      await driver.waitForIdle(300, 600);
      await assertTextExist(driver, '导航未就绪，可稍后重试');

      // 再次点击 → 回到 empty
      await clickButtonByText(driver, '调试：切换占位状态');
      await driver.waitForIdle(300, 600);
      await assertTextExist(driver, '从上方任选入口开始');
    });

    it('V2_D0_tab_switch', 0, async () => {
      const driver = await coldStartMainApp();

      // 壳页 → 人物
      await navigateToPersonFromShell(driver);
      await assertTextExist(driver, '新建人物');

      // 通过底栏 Tab「故事」切换到故事页（findComponents 定位底栏多个 Tab 文本）
      const allTexts = await safeFindComponents(driver, ON.text('故事'));
      if (allTexts.length > 0) {
        // 在人物页通常有两个「故事」(Tab + no)，但 Tab 在底部。点击第一个「故事」
        await allTexts[allTexts.length - 1].click();
      } else {
        const storyTab = await driver.findComponent(ON.text('故事'));
        if (storyTab !== null) {
          await storyTab.click();
        } else {
          throw new Error('Tab「故事」未找到');
        }
      }
      await driver.waitForIdle(300, 1000);
      await assertTextExist(driver, '新建故事', V2_TIMEOUT.NORMAL);

      // 通过底栏 Tab「人物」切换回人物页
      const allPersonTexts = await safeFindComponents(driver, ON.text('人物'));
      if (allPersonTexts.length > 0) {
        await allPersonTexts[allPersonTexts.length - 1].click();
      } else {
        const personTab = await driver.findComponent(ON.text('人物'));
        if (personTab !== null) {
          await personTab.click();
        } else {
          throw new Error('Tab「人物」未找到');
        }
      }
      await driver.waitForIdle(300, 1000);
      await assertTextExist(driver, '新建人物', V2_TIMEOUT.NORMAL);
    });
  });
}