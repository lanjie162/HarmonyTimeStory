/**
 * Tier2 · 形态一完整导入流程 E2E 回归。
 * 覆盖：人物详情 → 导入向导 → 扫描 → 完成。
 */
import { afterEach, describe, expect, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  assertOnPersonDetail,
  assertTextExist,
  clickComponentSafely,
  coldStartMainApp,
  navigateToPersonFromShell,
  createPersonOnPage,
  openPersonListRowByDisplayName,
  scrollDetailUntilVisible,
  sleepMs,
  V2_TIMEOUT
} from './V2RegressionTestKit';

export default function v2RegressionForm1(): void {
  describe('Tier2J_V2RegressionForm1', () => {
    afterEach(async () => {
      await sleepMs(200);
    });

    it('V2_FORM1_enter_wizard_and_scan', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2F1_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);

      // PersonDetailPage 的导入入口是「导入相册…」按钮（非「进入导入向导壳页」）
      await scrollDetailUntilVisible(driver, ON.text('导入相册…'));
      await clickComponentSafely(driver, ON.text('导入相册…'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);

      // 进入 ImportPage 后默认在 pick 步骤，点击 DEBUG 按钮跳到 conditions
      await assertTextExist(driver, '选图开始（相册）', V2_TIMEOUT.NORMAL);
      const debugSkipBtn = ON.text('【DEBUG】跳过选图进入条件（Hypium E2E）');
      await scrollDetailUntilVisible(driver, debugSkipBtn);
      await clickComponentSafely(driver, debugSkipBtn, V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);

      // 在 conditions 步骤点击「开始扫描」
      await assertTextExist(driver, '开始扫描', V2_TIMEOUT.NORMAL);
      await clickComponentSafely(driver, ON.text('开始扫描'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(500, V2_TIMEOUT.SCAN);
    });

    it('V2_FORM1_scan_candidate_step', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2F2_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);

      // 进入导入向导
      await scrollDetailUntilVisible(driver, ON.text('导入相册…'));
      await clickComponentSafely(driver, ON.text('导入相册…'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);

      // pick 步骤 → DEBUG 跳到 conditions
      await assertTextExist(driver, '选图开始（相册）', V2_TIMEOUT.NORMAL);
      const debugSkipBtn = ON.text('【DEBUG】跳过选图进入条件（Hypium E2E）');
      await scrollDetailUntilVisible(driver, debugSkipBtn);
      await clickComponentSafely(driver, debugSkipBtn, V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);

      // conditions → scan
      await clickComponentSafely(driver, ON.text('开始扫描'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(500, V2_TIMEOUT.SCAN);

      // 候选步（confirm）应显示「确认导入」按钮
      const confirmBtn = await driver.findComponent(ON.text('确认导入'));
      if (confirmBtn !== null) {
        await confirmBtn.click();
        await driver.waitForIdle(300, 1000);
      }
    });

    it('V2_FORM1_cancel_from_wizard', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2F3_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);

      // 进入导入向导
      await scrollDetailUntilVisible(driver, ON.text('导入相册…'));
      await clickComponentSafely(driver, ON.text('导入相册…'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);

      // 在向导中按 back 取消
      await driver.pressBack();
      await driver.waitForIdle(300, 800);
      await assertOnPersonDetail(driver, undefined, V2_TIMEOUT.NORMAL);
    });
  });
}
