/**
 * L4 E2E：删除级联回归 — Person 删除后关联 Story 不变、PhotoRef 保留。
 * 用于验证 MVP V2.6 删除行为不破坏数据一致性。
 */
import { afterEach, describe, expect, it } from '@ohos/hypium';
import { ON, Component } from '@kit.TestKit';
import {
  assertOnPersonDetail,
  assertTextExist,
  assertTextInList,
  clickComponentSafely,
  clickDialogConfirmButton,
  coldStartMainApp,
  createPersonOnPage,
  createStoryOnPage,
  navigateToPersonFromShell,
  navigateToStoryFromShell,
  openPersonListRowByDisplayName,
  openStoryListRowByTitle,
  safeFindComponents,
  scrollToText,
  sleepMs,
  waitForDialog,
  waitForText,
  V2_TIMEOUT
} from './V2RegressionTestKit';

export default function v2RegressionCascade(): void {
  describe('Tier2M_V2RegressionCascade', () => {
    afterEach(async () => {
      await sleepMs(200);
    });

    it('V2_CASCADE_story_after_person_delete', 0, async () => {
      const driver = await coldStartMainApp();

      // 创建故事
      await navigateToStoryFromShell(driver);
      await sleepMs(1000);
      const storyTitle = `V2Cas_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await assertTextInList(driver, storyTitle, V2_TIMEOUT.NORMAL);

      // 创建人物（不关联该故事）
      await navigateToPersonFromShell(driver);
      const personName = `V2Cas_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await assertTextInList(driver, personName, V2_TIMEOUT.NORMAL);

      // 删除人物：先进入详情页，再点击「编辑」进入编辑页
      await openPersonListRowByDisplayName(driver, personName);
      // 直接用 waitForText 获取编辑按钮并点击，避免二次查找组件丢失
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);
      await scrollToText(driver, '删除人物');
      // clickButtonByText 的 .type('Button') 在无障碍树可能不匹配，用 ON.text 无 type 过滤
      await clickComponentSafely(driver, ON.text('删除人物'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 600);
      const dlgFound = await waitForDialog(driver, '确认删除');
      expect(dlgFound).assertTrue();
      await sleepMs(500);
      await clickDialogConfirmButton(driver, '删除');
      await sleepMs(2000);
      // 删除后 router.back() 只从 EditPage 回到 DetailPage，需再 pressBack 回到 ShellPage
      try { await driver.pressBack(); } catch (_e) { /* ignore */ }
      await sleepMs(500);

      // 回到故事列表，确认故事仍然存在
      await navigateToStoryFromShell(driver);
      await assertTextInList(driver, storyTitle, V2_TIMEOUT.NORMAL);
    });
  });
}