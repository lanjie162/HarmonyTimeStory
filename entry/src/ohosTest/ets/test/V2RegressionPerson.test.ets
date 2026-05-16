/**
 * Tier2 · 人物域回归（V2-D1）。
 * 组件定位、滚动、跳转与 entry/src/main/ets/pages/person/ 源码精确对齐。
 */
import { afterEach, describe, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  assertTextExist,
  clickButtonByText,
  clickDetailDebugInjectAlbum,
  clickDetailDebugSameUriAgain,
  coldStartMainApp,
  createPersonOnPage,
  inputPersonDetailSecondTextInput,
  navigateToPersonFromShell,
  openPersonListRowByDisplayName,
  safeFindComponents,
  scrollDetailUntilVisible,
  sleepMs,
  V2_TIMEOUT
} from './V2RegressionTestKit';

export default function v2RegressionPerson(): void {
  describe('V2RegressionPerson', () => {
    afterEach(async () => {
      // 快速等待页面稳定，避免影响后续用例
      await sleepMs(200);
    });

    it('V2_D1_person_create_and_detail', 0, async () => {
      const driver = await coldStartMainApp();
      await assertTextExist(driver, '时光故事');
      await navigateToPersonFromShell(driver);
      await assertTextExist(driver, '新建人物');

      const personName = `V2D1_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await assertTextExist(driver, personName, V2_TIMEOUT.NORMAL);

      await openPersonListRowByDisplayName(driver, personName);
      await assertTextExist(driver, '人物详情');
      // 验证详情页底部「导入」入口
      await scrollDetailUntilVisible(driver, ON.text('进入导入向导壳页'));
      await assertTextExist(driver, '进入导入向导壳页');
    });

    it('V2_D1_person_detail_edit_name', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2Edit_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertTextExist(driver, '人物详情');

      // 修改显示名
      const updatedName = `V2EditUpd_${Date.now()}`;
      const inputs = await driver.findComponents(ON.type('TextInput'));
      if (inputs !== null && inputs.length >= 1) {
        await inputs[0].inputText(updatedName);
      }
      await clickButtonByText(driver, '保存显示名');
      await driver.waitForIdle(300, 800);
      // 验证更新后的名称出现在详情页头部
      await assertTextExist(driver, updatedName, V2_TIMEOUT.NORMAL);
    });

    it('V2_D1_person_quick_story_link', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2Lnk_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertTextExist(driver, '关联故事');

      // 快速创建故事
      const stTitle = `QuickSt_${Date.now()}`;
      await inputPersonDetailSecondTextInput(driver, stTitle);
      await clickButtonByText(driver, '创建');
      await driver.waitForIdle(300, 800);

      // 关联刚创建的故事
      await scrollDetailUntilVisible(driver, ON.text('关联'));
      const linkBtns = await safeFindComponents(driver, ON.text('关联'));
      if (linkBtns.length === 0) {
        throw new Error('人物详情未找到「关联」');
      }
      await linkBtns[linkBtns.length - 1].click();
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '解除关联', V2_TIMEOUT.NORMAL);
    });

    it('V2_D1_person_debug_album_ph01', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2Alb_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertTextExist(driver, '人物详情');

      // DEBUG 注入相册等价 URI
      await clickDetailDebugInjectAlbum(driver);
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '【E2E】上次加图：成功 file://e2e/album-equiv-1', V2_TIMEOUT.NORMAL);

      // 再注相同 URI — 验证 PH-01 去重
      await clickDetailDebugSameUriAgain(driver);
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '【E2E】上次加图：重复跳过（PH-01）', V2_TIMEOUT.NORMAL);
    });
  });
}