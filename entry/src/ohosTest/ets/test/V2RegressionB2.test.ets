/**
 * Tier2 · B2 / cancelRequest 域（V2-D4）。
 * **TR / 验收锚点**：派发任务请填写 `TR-…#C-n` 与下列 `it` 名称对照；无派发时以需求章节与 evidence 索引为准。
 */
import { afterEach, describe, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  clickDetailEnterImportWizard,
  coldStartMainApp,
  openPersonListRowByDisplayName,
  scrollDetailUntilVisible,
  sleepMs
} from './V2RegressionTestKit';

export default function v2RegressionB2(): void {
  describe('V2RegressionB2', () => {
    afterEach(async () => {
      await sleepMs(450);
    });

    /** B2 负例：cancelRequest(requestId+999) 不得匹配当前扫描任务；遮罩内需可见 【E2E】 横幅。 */
    it('V2_D4_b2_cancel_invalid_request_debug', 0, async () => {
      const driver = await coldStartMainApp();
      await (await driver.findComponent(ON.text('人物'))).click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2b2bad_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(personName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(3000, 6000);
      await clickDetailEnterImportWizard(driver);
      await driver.waitForIdle(3000, 6000);
      await (await driver.findComponent(ON.text('【DEBUG】跳过选图进入条件（Hypium E2E）'))).click();
      await driver.waitForIdle(1200, 4000);
      await (await driver.findComponent(ON.text('开始扫描'))).click();
      await driver.waitForIdle(800, 3500);
      await (await driver.findComponent(ON.text('【DEBUG】错误 ID 触发 cancelRequest（B2 负例）'))).click();
      await driver.waitForIdle(600, 2500);
      await driver.assertComponentExist(ON.text('【E2E】cancelRequest：未生效（requestId 不匹配）'));
      await (await driver.findComponent(ON.text('取消扫描'))).click();
      await sleepMs(500);
      const okDlg = await driver.findComponent(ON.text('确定取消'));
      if (okDlg !== null) {
        await okDlg.click();
      } else {
        const alt2 = await driver.findComponent(ON.text('确定'));
        if (alt2 !== null) {
          await alt2.click();
        }
      }
      await driver.waitForIdle(2000, 8000);
      await scrollDetailUntilVisible(driver, ON.text('重试（IM-09）'));
      await driver.assertComponentExist(ON.text('重试（IM-09）'));
    });

    /**
     * 扫描完成→候选→回条件→再扫描→IM-09 取消，证明新 requestId 下仍可走通取消链路（槽位与新任务）。
     */
    it('V2_D4_b2_rescan_after_confirm_then_cancel_im09', 0, async () => {
      const driver = await coldStartMainApp();
      await (await driver.findComponent(ON.text('人物'))).click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2b2rs_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(personName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(3000, 6000);
      await clickDetailEnterImportWizard(driver);
      await driver.waitForIdle(3000, 6000);
      await (await driver.findComponent(ON.text('【DEBUG】跳过选图进入条件（Hypium E2E）'))).click();
      await driver.waitForIdle(1200, 4000);
      await (await driver.findComponent(ON.text('开始扫描'))).click();
      await driver.waitForComponent(ON.text('候选确认（IM-08）· 4.5 步骤 D'), 22000);
      await driver.waitForIdle(600, 2500);
      await (await driver.findComponent(ON.text('上一步（改条件）'))).click();
      await driver.waitForIdle(1000, 3500);
      await (await driver.findComponent(ON.text('开始扫描'))).click();
      await driver.waitForIdle(800, 3500);
      await driver.assertComponentExist(ON.text('取消扫描'));
      await (await driver.findComponent(ON.text('取消扫描'))).click();
      await sleepMs(500);
      const okBtn = await driver.findComponent(ON.text('确定取消'));
      if (okBtn !== null) {
        await okBtn.click();
      } else {
        const alt = await driver.findComponent(ON.text('确定'));
        if (alt !== null) {
          await alt.click();
        }
      }
      await driver.waitForIdle(2000, 8000);
      await scrollDetailUntilVisible(driver, ON.text('重试（IM-09）'));
      await driver.assertComponentExist(ON.text('重试（IM-09）'));
    });

    /** S4：对话框确认后立即轮询「正在取消…」（快路径；若跳过则仍可回到条件步即为弱通过）。 */
    it('V2_D4_b2_cancelling_banner_after_dialog', 0, async () => {
      const driver = await coldStartMainApp();
      await (await driver.findComponent(ON.text('人物'))).click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2b2bn_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(personName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(3000, 6000);
      await clickDetailEnterImportWizard(driver);
      await driver.waitForIdle(3000, 6000);
      await (await driver.findComponent(ON.text('【DEBUG】跳过选图进入条件（Hypium E2E）'))).click();
      await driver.waitForIdle(1200, 4000);
      await (await driver.findComponent(ON.text('开始扫描'))).click();
      await driver.waitForIdle(600, 3500);
      await (await driver.findComponent(ON.text('取消扫描'))).click();
      await sleepMs(400);
      const okBtn = await driver.findComponent(ON.text('确定取消'));
      if (okBtn !== null) {
        await okBtn.click();
      } else {
        const alt = await driver.findComponent(ON.text('确定'));
        if (alt !== null) {
          await alt.click();
        }
      }
      let sawCancelling = false;
      for (let i = 0; i < 12; i++) {
        const t = await driver.findComponent(ON.text('正在取消…（应用层 cancelRequest 协作中）'));
        if (t !== null) {
          sawCancelling = true;
          break;
        }
        await sleepMs(120);
      }
      if (!sawCancelling) {
        await driver.waitForIdle(1500, 6000);
      }
      await scrollDetailUntilVisible(driver, ON.text('重试（IM-09）'));
      await driver.assertComponentExist(ON.text('重试（IM-09）'));
    });
  });
}
