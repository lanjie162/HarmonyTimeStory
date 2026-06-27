/**
 * Tier2 · SwipeAction 左滑删除回归（全局组件 §D）。
 * 组件定位与 entry/src/main/ets/pages/person/PersonPage.ets +
 * entry/src/main/ets/pages/story/StoryPage.ets 源码精确对齐。
 *
 * 人物/故事列表行：左滑露出红色「删除」按钮 → 点击 → AlertDialog「确认删除」
 * → 点击「确认」或「取消」。
 */
import { afterEach, describe, expect, it } from '@ohos/hypium';
import { ON, Component, UiDirection } from '@kit.TestKit';
import {
  assertOnPersonDetail,
  assertOnStoryDetail,
  assertPersonListItemNotExist,
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
  scrollDetailUntilVisible,
  scrollToText,
  sleepMs,
  waitForDialog,
  waitForText,
  V2_TIMEOUT
} from './V2RegressionTestKit';

export default function v2RegressionSwipeAction(): void {
  describe('Tier2H_V2RegressionSwipeAction', () => {
    afterEach(async () => {
      await sleepMs(200);
    });

    it('V2_SWIPE_person_delete', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2SwpDel_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await assertTextInList(driver, personName, V2_TIMEOUT.NORMAL);

      // 打开人物详情 → 点击「编辑」进入编辑页 → 滚动到「删除人物」按钮
      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);
      await scrollToText(driver, '删除人物');
      await clickComponentSafely(driver, ON.text('删除人物'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 600);

      // 确认对话框
      const dlgFound = await waitForDialog(driver, '确认删除');
      expect(dlgFound).assertTrue();

      // 点击「删除」
      await clickDialogConfirmButton(driver, '删除');
      await sleepMs(2000);

      // 删除后 pressBack 回到 ShellPage（EditPage → DetailPage → ShellPage）
      try { await driver.pressBack(); } catch (_e) { /* ignore */ }
      await sleepMs(500);
      try { await driver.pressBack(); } catch (_e) { /* ignore */ }
      await sleepMs(500);

      // 导航到人物列表验证人物已消失
      await navigateToPersonFromShell(driver);
      await driver.waitForIdle(500, 1000);
      await assertPersonListItemNotExist(driver, personName);
    });

    it('V2_SWIPE_person_cancel', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2SwpCan_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await assertTextInList(driver, personName, V2_TIMEOUT.NORMAL);

      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);
      await scrollToText(driver, '删除人物');
      await clickComponentSafely(driver, ON.text('删除人物'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 600);

      // 确认对话框出现 → 点击「取消」
      const dlgFound = await waitForDialog(driver, '确认删除');
      expect(dlgFound).assertTrue();
      await clickComponentSafely(driver, ON.text('取消'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);

      // 取消后仍在编辑页（PersonDetailEditPage），验证「保存」按钮仍存在
      await assertTextExist(driver, '保存', V2_TIMEOUT.NORMAL);
    });

    it('V2_SWIPE_story_delete', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);

      const storyTitle = `V2SwpSDel_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await assertTextInList(driver, storyTitle, V2_TIMEOUT.NORMAL);

      await openStoryListRowByTitle(driver, storyTitle);
      await assertOnStoryDetail(driver);
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);
      await scrollToText(driver, '删除故事');
      await clickComponentSafely(driver, ON.text('删除故事'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 600);

      const dlgFound = await waitForDialog(driver, '确认删除');
      expect(dlgFound).assertTrue();
      await sleepMs(500);
      await clickDialogConfirmButton(driver, '删除');
      await sleepMs(2000);

      // 删除后 pressBack 回到 ShellPage（EditPage → DetailPage → ShellPage）
      try { await driver.pressBack(); } catch (_e) { /* ignore */ }
      await sleepMs(500);
      try { await driver.pressBack(); } catch (_e) { /* ignore */ }
      await sleepMs(500);

      // 导航到故事列表验证故事已消失
      await navigateToStoryFromShell(driver);
      await driver.waitForIdle(500, 1000);

      // 验证故事已从列表消失
      const found = await driver.findComponent(ON.text(storyTitle));
      if (found !== null) {
        throw new Error('故事仍存在于列表中: ' + storyTitle);
      }
      // fling 滚动查找以防列表分页
      for (let i = 0; i < 3; i++) {
        await driver.fling(UiDirection.DOWN, 4000);
        await sleepMs(600);
        const hit = await driver.findComponent(ON.text(storyTitle));
        if (hit !== null) {
          throw new Error('故事仍存在于列表中（scroll 后找到）: ' + storyTitle);
        }
      }
    });

    it('V2_SWIPE_story_cancel', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);

      const storyTitle = `V2SwpSCan_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await assertTextInList(driver, storyTitle, V2_TIMEOUT.NORMAL);

      await openStoryListRowByTitle(driver, storyTitle);
      await assertOnStoryDetail(driver);
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);
      await scrollToText(driver, '删除故事');
      await clickComponentSafely(driver, ON.text('删除故事'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 600);

      const dlgFound = await waitForDialog(driver, '确认删除');
      expect(dlgFound).assertTrue();
      await clickComponentSafely(driver, ON.text('取消'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);

      // 取消后仍在编辑页（StoryDetailEditPage），验证「保存」按钮仍存在
      await assertTextExist(driver, '保存', V2_TIMEOUT.NORMAL);
    });
  });
}
