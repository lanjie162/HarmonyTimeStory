/**
 * Tier2 · 人物域回归（V2-D1）。
 * **TR / 验收锚点**：派发任务请填写 `TR-…#C-n` 与下列 `it` 名称对照；无派发时以需求章节与 evidence 索引为准。
 * 权威索引示例：document/evidence/V2/2026-05-10-T9-V2-D1-D4-plan-and-execution-index.md
 */
import { afterEach, describe, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  clickDetailDebugInjectAlbum,
  clickDetailDebugSameUriAgain,
  coldStartMainApp,
  inputPersonDetailSecondTextInput,
  openPersonListRowByDisplayName,
  safeFindComponents,
  scrollDetailUntilVisible,
  sleepMs
} from './V2RegressionTestKit';

export default function v2RegressionPerson(): void {
  describe('V2RegressionPerson', () => {
    afterEach(async () => {
      await sleepMs(450);
    });
    it('V2_D1_person_main_create_and_detail', 0, async () => {
      const driver = await coldStartMainApp();
      await driver.assertComponentExist(ON.text('时光故事'));
      const btnPerson = await driver.findComponent(ON.text('人物'));
      await btnPerson.click();
      await driver.waitForIdle(3000, 6000);
      await driver.assertComponentExist(ON.text('新建人物'));
      const personName = `V2D1_${Date.now()}`;
      const inputNew = await driver.findComponent(ON.type('TextInput'));
      await inputNew.inputText(personName);
      const createPerson = await driver.findComponent(ON.text('创建人物'));
      await createPerson.click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(3000, 6000);
      await driver.assertComponentExist(ON.text('人物详情'));
      await scrollDetailUntilVisible(driver, ON.text('进入导入向导壳页'));
      await driver.assertComponentExist(ON.text('进入导入向导壳页'));
    });

    it('V2_D1_person_detail_quick_story_link_toggle', 0, async () => {
      const driver = await coldStartMainApp();
      const btnPerson = await driver.findComponent(ON.text('人物'));
      await btnPerson.click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2D1lnk_${Date.now()}`;
      const inputNew = await driver.findComponent(ON.type('TextInput'));
      await inputNew.inputText(personName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(3000, 6000);
      await driver.assertComponentExist(ON.text('关联故事'));
      const stTitle = `QuickSt_${Date.now()}`;
      await inputPersonDetailSecondTextInput(driver, stTitle);
      const createSt = await driver.findComponent(ON.text('创建'));
      await createSt.click();
      await driver.waitForIdle(2000, 5000);
      await scrollDetailUntilVisible(driver, ON.text('关联'));
      const linkBtns = await safeFindComponents(driver, ON.text('关联'));
      if (linkBtns.length === 0) {
        throw new Error('人物详情未找到「关联」');
      }
      await linkBtns[linkBtns.length - 1].click();
      await driver.waitForIdle(1500, 4000);
      await driver.assertComponentExist(ON.text('解除关联'));
    });

    /** mock URI 等价于相册回调后 addPhotoToPerson（不打开 PhotoViewPicker）。 */
    it('V2_D1_person_debug_album_equiv_inject', 0, async () => {
      const driver = await coldStartMainApp();
      await (await driver.findComponent(ON.text('人物'))).click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2alb_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(personName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(2500, 6000);
      await clickDetailDebugInjectAlbum(driver);
      await driver.waitForIdle(1200, 4000);
      await driver.assertComponentExist(ON.text('【E2E】上次加图：成功 file://e2e/album-equiv-1'));
    });

    it('V2_D1_person_debug_ph01_duplicate_second_inject', 0, async () => {
      const driver = await coldStartMainApp();
      await (await driver.findComponent(ON.text('人物'))).click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2ph1p_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(personName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(2500, 6000);
      await clickDetailDebugInjectAlbum(driver);
      await driver.waitForIdle(900, 3000);
      await clickDetailDebugSameUriAgain(driver);
      await driver.waitForIdle(900, 3000);
      await driver.assertComponentExist(ON.text('【E2E】上次加图：重复跳过（PH-01）'));
    });
  });
}
