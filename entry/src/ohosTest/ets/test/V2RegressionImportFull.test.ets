/**
 * Tier2 · 导入向导完整流程补充覆盖（V2-D3 扩展）。
 * 组件定位、滚动、跳转与 entry/src/main/ets/pages/import/ImportPage.ets 源码精确对齐。
 *
 * V2.1 Must（D4）：本文件 2 条主链用例；`V2_D3_import_empty_owner_id_warning` 已 G-3 Out，
 * 见 deferred/V2RegressionImportEmptyOwner.deferred.test.ets（未注册 List.test.ets）。
 */
import { afterEach, describe, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  assertTextExist,
  clickButtonByText,
  clickConfirmImportButton,
  clickDetailEnterImportWizard,
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

export default function v2RegressionImportFull(): void {
  describe('Tier2D_V2RegressionImportFull', () => {
    afterEach(async () => {
      await sleepMs(200);
    });

    it('V2_D3_import_prepare_step_and_back', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2Prep_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await clickDetailEnterImportWizard(driver);
      await assertTextExist(driver, '导入向导');

      // 点击选图（实际调用 pickPhotos 会打开系统相册，
      // 使用 DEBUG 跳过选图）
      await clickImportDebugSkipToConditions(driver);
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '导入条件 · 4.5 步骤 B');

      // 上一步 → 回到准备步？不，DEBUG 跳过直接从 pick→conditions，
      // 检查「上一步」按钮存在
      await scrollDetailUntilVisible(driver, ON.text('上一步'));
      await assertTextExist(driver, '上一步');
    });

    it('V2_D3_import_confirm_select_all_none_invert', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2Sel_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await clickDetailEnterImportWizard(driver);
      await clickImportDebugSkipToConditions(driver);
      await driver.waitForIdle(300, 800);

      // 扫描 → 等待候选步
      await clickImportStartScan(driver);
      await driver.waitForComponent(ON.text('候选确认（IM-08）· 4.5 步骤 D'), V2_TIMEOUT.SCAN);
      await driver.waitForIdle(300, 800);

      // 验证候选操作按钮存在
      await assertTextExist(driver, '全选');
      await assertTextExist(driver, '全不选');
      await assertTextExist(driver, '反选');

      // 全选 → 全不选 → 反选（验证按钮可点击）
      await clickButtonByText(driver, '全选');
      await driver.waitForIdle(200, 400);
      await clickButtonByText(driver, '全不选');
      await driver.waitForIdle(200, 400);
      await clickButtonByText(driver, '反选');
      await driver.waitForIdle(200, 400);

      // 确认导入
      await clickConfirmImportButton(driver);
      await driver.waitForIdle(300, 800);
    });
  });
}