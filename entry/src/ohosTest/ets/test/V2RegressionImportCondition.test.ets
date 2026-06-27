/**
 * Tier2 · 导入条件页 E2E 回归（形态一）。
 * 组件定位与 entry/src/main/ets/pages/import/ImportPage.ets 源码精确对齐。
 */
import { afterEach, describe, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  assertOnPersonDetail,
  assertTextExist,
  clickComponentSafely,
  clickImportDebugSkipToConditions,
  coldStartMainApp,
  navigateToPersonFromShell,
  createPersonOnPage,
  openPersonListRowByDisplayName,
  scrollDetailUntilVisible,
  sleepMs,
  V2_TIMEOUT
} from './V2RegressionTestKit';

export default function v2RegressionImportCondition(): void {
  describe('Tier2I_V2RegressionImportCondition', () => {
    afterEach(async () => {
      await sleepMs(200);
    });

    it('V2_IMPCOND_enter_wizard', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2IC_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);

      // 进入导入向导：点击「导入相册…」入口
      await scrollDetailUntilVisible(driver, ON.text('导入相册…'));
      await clickComponentSafely(driver, ON.text('导入相册…'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '导入向导', V2_TIMEOUT.NORMAL);
    });

    it('V2_IMPCOND_condition_page_visible', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2IC2_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await scrollDetailUntilVisible(driver, ON.text('导入相册…'));
      await clickComponentSafely(driver, ON.text('导入相册…'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);

      // 默认进入 pick 步，点 DEBUG 按钮跳到 conditions 步
      await assertTextExist(driver, '选图开始（相册）', V2_TIMEOUT.NORMAL);
      await clickImportDebugSkipToConditions(driver);
      await driver.waitForIdle(300, 800);

      // 条件页应显示「时间条件」和「开始扫描」
      await assertTextExist(driver, '时间条件', V2_TIMEOUT.NORMAL);
      await assertTextExist(driver, '开始扫描', V2_TIMEOUT.NORMAL);
    });

    it('V2_IMPCOND_scan_button_visible', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2IC3_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await scrollDetailUntilVisible(driver, ON.text('导入相册…'));
      await clickComponentSafely(driver, ON.text('导入相册…'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);
      await clickImportDebugSkipToConditions(driver);
      await driver.waitForIdle(300, 800);

      // 「开始扫描」按钮可见且可点击
      await assertTextExist(driver, '开始扫描', V2_TIMEOUT.NORMAL);
      const scanBtn = await driver.findComponent(ON.text('开始扫描'));
      if (scanBtn !== null) {
        await scanBtn.click();
        await driver.waitForIdle(300, 1000);
      }
    });

    it('V2_IMPCOND_back_from_wizard', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2IC4_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await scrollDetailUntilVisible(driver, ON.text('导入相册…'));
      await clickComponentSafely(driver, ON.text('导入相册…'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);

      // 返回按钮 → 回到人物详情
      await driver.pressBack();
      await driver.waitForIdle(300, 800);
      await assertOnPersonDetail(driver, undefined, V2_TIMEOUT.NORMAL);
    });
  });
}
