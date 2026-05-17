/**
 * Tier2 · 建议 / 导入向导域（V2-D3）。
 * 组件定位、滚动、跳转与 entry/src/main/ets/pages/import/ + suggest/ 源码精确对齐。
 */
import { afterEach, describe, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  assertTextExist,
  clickButtonByText,
  clickConfirmImportButton,
  clickDetailEnterImportWizard,
  clickImportCancelScan,
  clickImportDebugPh01Duplicate,
  clickImportDebugSkipToConditions,
  clickImportStartScan,
  coldStartMainApp,
  clickConfirmCancelDialog,
  createPersonOnPage,
  navigateToPersonFromShell,
  openPersonListRowByDisplayName,
  scrollDetailUntilVisible,
  sleepMs,
  V2_TIMEOUT
} from './V2RegressionTestKit';

export default function v2RegressionSuggestImport(): void {
  describe('Tier2C_V2RegressionSuggestImport', () => {
    afterEach(async () => {
      await sleepMs(200);
    });

    it('V2_D3_suggest_entry_and_return', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      // 人脸建议入口
      await clickButtonByText(driver, '人脸建议');
      await assertTextExist(driver, '建议审阅');
      await assertTextExist(driver, '4.6 形态三 · 顶栏说明（对齐 v1.2 可测骨架）');
      // 返回人物页
      await clickButtonByText(driver, '返回');
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '人物');
    });

    it('V2_D3_suggest_accept_ignore', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      await clickButtonByText(driver, '人脸建议');
      await assertTextExist(driver, '建议审阅');

      // 接受候选 — 验证状态
      await clickButtonByText(driver, '接受');
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '状态：已接受');

      // 忽略（已接受项不可忽略，验证 Toast 阻断）
      await clickButtonByText(driver, '忽略');
      await driver.waitForIdle(300, 800);
      // 仍显示「已接受」
      await assertTextExist(driver, '状态：已接受');
    });

    it('V2_D3_import_wizard_from_person', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2Imp_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertTextExist(driver, '人物详情');

      // 进入导入向导
      await clickDetailEnterImportWizard(driver);
      await assertTextExist(driver, '导入向导');
      // 验证处于 pick 步
      await assertTextExist(driver, '选图开始（相册）');
    });

    it('V2_D3_import_conditions_scan_cancel', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2Cn_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await clickDetailEnterImportWizard(driver);
      await assertTextExist(driver, '导入向导');

      // DEBUG 跳过选图 → 条件步
      await clickImportDebugSkipToConditions(driver);
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '导入条件 · 4.5 步骤 B');

      // 开始扫描
      await clickImportStartScan(driver);
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '取消扫描');

      // 取消扫描
      await clickImportCancelScan(driver);
      await sleepMs(400);
      await clickConfirmCancelDialog(driver);
      await driver.waitForIdle(300, 800);

      // 验证「重试（IM-09）」出现
      await scrollDetailUntilVisible(driver, ON.text('重试（IM-09）'));
      await assertTextExist(driver, '重试（IM-09）');
    });

    it('V2_D3_import_scan_confirm_commit', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2Wr_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await clickDetailEnterImportWizard(driver);

      // DEBUG 跳过选图 → 扫描 → 等待候选确认步
      await clickImportDebugSkipToConditions(driver);
      await driver.waitForIdle(300, 800);
      await clickImportStartScan(driver);
      await driver.waitForComponent(ON.text('候选确认（IM-08）· 4.5 步骤 D'), V2_TIMEOUT.SCAN);
      await driver.waitForIdle(300, 800);

      // 确认导入
      await clickConfirmImportButton(driver);
      await driver.waitForIdle(300, 800);
    });

    it('V2_D3_import_ph01_duplicate_commit', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2Dup_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await clickDetailEnterImportWizard(driver);

      // DEBUG PH-01 双占位 → 扫描 → 候选 → 确认
      await clickImportDebugPh01Duplicate(driver);
      await driver.waitForIdle(300, 800);
      await clickImportStartScan(driver);
      await driver.waitForComponent(ON.text('候选确认（IM-08）· 4.5 步骤 D'), V2_TIMEOUT.SCAN);
      await driver.waitForIdle(300, 800);

      await clickConfirmImportButton(driver);
      await driver.waitForIdle(300, 800);

      // 回到人物详情，验证照片数=1（PH-01 去重）
      await assertTextExist(driver, '人物详情');
      await assertTextExist(driver, '【E2E】照片数=1');
    });
  });
}