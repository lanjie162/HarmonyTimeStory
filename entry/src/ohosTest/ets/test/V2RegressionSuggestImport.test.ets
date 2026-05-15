/**
 * Tier2 · 建议 / 导入向导域（V2-D3）。
 * **TR / 验收锚点**：派发任务请填写 `TR-…#C-n` 与下列 `it` 名称对照；无派发时以需求章节与 evidence 索引为准。
 * T9-ST-D3 等：见 document/evidence/V2 执行索引。
 */
import { afterEach, describe, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  clickConfirmImportButton,
  clickDetailEnterImportWizard,
  coldStartMainApp,
  openPersonListRowByDisplayName,
  scrollDetailUntilVisible,
  sleepMs
} from './V2RegressionTestKit';

export default function v2RegressionSuggestImport(): void {
  describe('V2RegressionSuggestImport', () => {
    afterEach(async () => {
      await sleepMs(450);
    });
    it('V2_D3_suggest_entry_minimal', 0, async () => {
      const driver = await coldStartMainApp();
      const btnPerson = await driver.findComponent(ON.text('人物'));
      await btnPerson.click();
      await driver.waitForIdle(3000, 6000);
      const btnSuggest = await driver.findComponent(ON.text('人脸建议'));
      await btnSuggest.click();
      await driver.waitForIdle(3000, 6000);
      await driver.assertComponentExist(ON.text('建议审阅'));
      await driver.assertComponentExist(ON.text('4.6 形态三 · 顶栏说明（对齐 v1.2 可测骨架）'));
      const back = await driver.findComponent(ON.text('返回'));
      await back.click();
      await driver.waitForIdle(2000, 4000);
      await driver.assertComponentExist(ON.text('人物'));
    });

    it('V2_D3_import_wizard_shell_from_person', 0, async () => {
      const driver = await coldStartMainApp();
      const btnPerson = await driver.findComponent(ON.text('人物'));
      await btnPerson.click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2D3im_${Date.now()}`;
      const inputNew = await driver.findComponent(ON.type('TextInput'));
      await inputNew.inputText(personName);
      const createPerson = await driver.findComponent(ON.text('创建人物'));
      await createPerson.click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(3000, 6000);
      await clickDetailEnterImportWizard(driver);
      await driver.waitForIdle(3000, 6000);
      await driver.assertComponentExist(ON.text('导入向导'));
      await driver.assertComponentExist(ON.text('选图开始（相册）'));
    });

    /**
     * T9-ST-D3：条件步 + 扫描 + IM-09 二次确认 + cancelRequest（BuildProfile.DEBUG 下「跳过选图」入口）。
     */
    it('V2_D3_import_conditions_scan_cancel_im09', 0, async () => {
      const driver = await coldStartMainApp();
      const btnPerson = await driver.findComponent(ON.text('人物'));
      await btnPerson.click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2D3cn_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(personName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(3000, 6000);
      await clickDetailEnterImportWizard(driver);
      await driver.waitForIdle(3000, 6000);
      await driver.assertComponentExist(ON.text('【DEBUG】跳过选图进入条件（Hypium E2E）'));
      await (await driver.findComponent(ON.text('【DEBUG】跳过选图进入条件（Hypium E2E）'))).click();
      await driver.waitForIdle(1500, 4000);
      await driver.assertComponentExist(ON.text('导入条件 · 4.5 步骤 B'));
      await (await driver.findComponent(ON.text('开始扫描'))).click();
      await driver.waitForIdle(800, 3000);
      await driver.assertComponentExist(ON.text('取消扫描'));
      await (await driver.findComponent(ON.text('取消扫描'))).click();
      await sleepMs(600);
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

    /**
     * T9-ST-D3：扫描跑满 → 候选确认 → 确认写入（占位 URI，PH-01 内存链）。
     */
    it('V2_D3_import_scan_confirm_commit', 0, async () => {
      const driver = await coldStartMainApp();
      const btnPerson = await driver.findComponent(ON.text('人物'));
      await btnPerson.click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2D3wr_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(personName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(3000, 6000);
      await clickDetailEnterImportWizard(driver);
      await driver.waitForIdle(3000, 6000);
      await (await driver.findComponent(ON.text('【DEBUG】跳过选图进入条件（Hypium E2E）'))).click();
      await driver.waitForIdle(1500, 4000);
      await (await driver.findComponent(ON.text('开始扫描'))).click();
      await driver.waitForComponent(ON.text('候选确认（IM-08）· 4.5 步骤 D'), 22000);
      await driver.waitForIdle(800, 2500);
      await clickConfirmImportButton(driver);
      await driver.waitForIdle(2000, 6000);
    });

    /**
     * Import commitImport：两条相同 URI → ok=1 dup=1；回到人物详情应有 1 张 ref。
     */
    it('V2_D3_import_ph01_commit_duplicate_uris', 0, async () => {
      const driver = await coldStartMainApp();
      await (await driver.findComponent(ON.text('人物'))).click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2imdup_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(personName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(3000, 6000);
      await clickDetailEnterImportWizard(driver);
      await driver.waitForIdle(2500, 6000);
      await (await driver.findComponent(ON.text('【DEBUG】跳过选图 PH-01 双占位（同 URI×2）'))).click();
      await driver.waitForIdle(1200, 4000);
      await (await driver.findComponent(ON.text('开始扫描'))).click();
      await driver.waitForComponent(ON.text('候选确认（IM-08）· 4.5 步骤 D'), 22000);
      await driver.waitForIdle(600, 2000);
      await clickConfirmImportButton(driver);
      await driver.waitForIdle(2500, 7000);
      await driver.assertComponentExist(ON.text('人物详情'));
      await driver.assertComponentExist(ON.text('【E2E】照片数=1'));
    });
  });
}
