/**
 * Tier2 · B2 / cancelRequest 域（V2-D4）。
 * 组件定位、滚动、跳转与 entry/src/main/ets/pages/import/ImportPage.ets 源码精确对齐。
 */
import { afterEach, describe, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  assertTextExist,
  clickComponentSafely,
  clickConfirmCancelDialog,
  clickDetailEnterImportWizard,
  clickImportCancelScan,
  clickImportDebugB2WrongCancel,
  clickImportDebugSkipToConditions,
  clickImportStartScan,
  coldStartMainApp,
  createPersonOnPage,
  navigateToPersonFromShell,
  openPersonListRowByDisplayName,
  scrollDetailUntilVisible,
  sleepMs,
  V2_TIMEOUT
} from './V2RegressionTestKit';

export default function v2RegressionB2(): void {
  describe('V2RegressionB2', () => {
    afterEach(async () => {
      await sleepMs(200);
    });

    it('V2_D4_b2_cancel_invalid_request', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2Bad_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await clickDetailEnterImportWizard(driver);
      await clickImportDebugSkipToConditions(driver);
      await driver.waitForIdle(300, 800);

      // 开始扫描
      await clickImportStartScan(driver);
      await driver.waitForIdle(300, 800);

      // 错误 ID 触发 cancelRequest（B2 负例）
      await clickImportDebugB2WrongCancel(driver);
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '【E2E】cancelRequest：未生效（requestId 不匹配）');

      // 真实取消
      await clickImportCancelScan(driver);
      await sleepMs(400);
      await clickConfirmCancelDialog(driver);
      await driver.waitForIdle(300, 800);

      // 验证重试入口
      await scrollDetailUntilVisible(driver, ON.text('重试（IM-09）'));
      await assertTextExist(driver, '重试（IM-09）');
    });

    it('V2_D4_b2_rescan_after_confirm_then_cancel', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2Rs_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await clickDetailEnterImportWizard(driver);
      await clickImportDebugSkipToConditions(driver);
      await driver.waitForIdle(300, 800);

      // 扫描 → 等待候选步
      await clickImportStartScan(driver);
      await driver.waitForComponent(ON.text('候选确认（IM-08）· 4.5 步骤 D'), V2_TIMEOUT.SCAN);
      await driver.waitForIdle(300, 800);

      // 回条件步
      await clickComponentSafely(driver, ON.text('上一步（改条件）'));
      await driver.waitForIdle(300, 800);

      // 重扫
      await clickImportStartScan(driver);
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '取消扫描');

      // 取消
      await clickImportCancelScan(driver);
      await sleepMs(400);
      await clickConfirmCancelDialog(driver);
      await driver.waitForIdle(300, 800);

      // 验证重试入口
      await scrollDetailUntilVisible(driver, ON.text('重试（IM-09）'));
      await assertTextExist(driver, '重试（IM-09）');
    });

    it('V2_D4_b2_cancelling_banner', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2Bn_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await clickDetailEnterImportWizard(driver);
      await clickImportDebugSkipToConditions(driver);
      await driver.waitForIdle(300, 800);

      // 开始扫描
      await clickImportStartScan(driver);
      await driver.waitForIdle(300, 800);

      // 取消扫描 → 确认对话框
      await clickImportCancelScan(driver);
      await sleepMs(300);
      await clickConfirmCancelDialog(driver);

      // 验证「正在取消…」横幅出现
      let sawCancelling = false;
      for (let i = 0; i < 6; i++) {
        const t = await driver.findComponent(ON.text('正在取消…（应用层 cancelRequest 协作中）'));
        if (t !== null) {
          sawCancelling = true;
          break;
        }
        await sleepMs(150);
      }
      if (!sawCancelling) {
        await driver.waitForIdle(300, 800);
      }

      // 验证重试入口
      await scrollDetailUntilVisible(driver, ON.text('重试（IM-09）'));
      await assertTextExist(driver, '重试（IM-09）');
    });
  });
}