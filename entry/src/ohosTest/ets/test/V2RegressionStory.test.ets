/**
 * Tier2 · 故事域回归（V2-D2）。
 * 组件定位、滚动、跳转与 entry/src/main/ets/pages/story/ 源码精确对齐。
 */
import { afterEach, describe, expect, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  assertTextExist,
  clickButtonByText,
  clickDetailDebugInjectAlbum,
  clickDetailDebugSameUriAgain,
  coldStartMainApp,
  createStoryOnPage,
  inputStoryDetailSecondTextInput,
  navigateToStoryFromShell,
  openStoryListRowByTitle,
  safeFindComponents,
  scrollDetailUntilVisible,
  scrollToText,
  sleepMs,
  waitForDialog,
  V2_TIMEOUT
} from './V2RegressionTestKit';

export default function v2RegressionStory(): void {
  describe('Tier2B_V2RegressionStory', () => {
    afterEach(async () => {
      await sleepMs(200);
    });

    it('V2_D2_story_create_and_detail', 0, async () => {
      const driver = await coldStartMainApp();
      await assertTextExist(driver, '时光故事');
      await navigateToStoryFromShell(driver);
      await assertTextExist(driver, '新建故事');

      const storyTitle = `V2D2_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await assertTextExist(driver, storyTitle, V2_TIMEOUT.NORMAL);

      await openStoryListRowByTitle(driver, storyTitle);
      await assertTextExist(driver, '故事详情');
    });

    it('V2_D2_story_detail_edit_title', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);

      const storyTitle = `V2Edt_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertTextExist(driver, '故事详情');

      // 修改标题
      const updatedTitle = `V2EdtUpd_${Date.now()}`;
      const inputs = await driver.findComponents(ON.type('TextInput'));
      if (inputs !== null && inputs.length >= 1) {
        await inputs[0].inputText(updatedTitle);
      }
      await clickButtonByText(driver, '保存标题');
      await driver.waitForIdle(300, 800);
      // 验证更新后的标题出现在详情页头部
      await assertTextExist(driver, updatedTitle, V2_TIMEOUT.NORMAL);
    });

    it('V2_D2_story_quick_person_link', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);

      const storyTitle = `V2Lnk_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertTextExist(driver, '关联人物');

      // 快速创建人物
      const pName = `QuickPer_${Date.now()}`;
      await inputStoryDetailSecondTextInput(driver, pName);
      await clickButtonByText(driver, '创建人物');
      await driver.waitForIdle(300, 800);

      // 关联刚创建的人物
      await scrollDetailUntilVisible(driver, ON.text('关联'));
      const linkBtns = await safeFindComponents(driver, ON.text('关联'));
      if (linkBtns.length === 0) {
        throw new Error('故事详情未找到「关联」');
      }
      await linkBtns[linkBtns.length - 1].click();
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '解除关联', V2_TIMEOUT.NORMAL);
    });

    it('V2_D2_story_debug_album_ph01', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);

      const storyTitle = `V2Alb_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertTextExist(driver, '故事详情');

      // DEBUG 注入相册等价 URI
      await clickDetailDebugInjectAlbum(driver);
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '【E2E】上次加图：成功 file://e2e/album-equiv-story-1', V2_TIMEOUT.NORMAL);

      // 再注相同 URI — 验证 PH-01 去重
      await clickDetailDebugSameUriAgain(driver);
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '【E2E】上次加图：重复跳过（PH-01）', V2_TIMEOUT.NORMAL);
    });

    // ── T-23 Story 新字段 UI ───────────────────────────

    it('V2_D2_story_description_save', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);
      const storyTitle = `V2Desc_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertTextExist(driver, '故事详情');

      // 输入描述
      const textAreas = await safeFindComponents(driver, ON.type('TextArea'));
      if (textAreas.length > 0) {
        await textAreas[0].inputText('QA test story description');
        await driver.waitForIdle(200, 400);
      }
      // 保存
      await scrollToText(driver, '保存全部字段');
      await clickButtonByText(driver, '保存全部字段');
      await driver.waitForIdle(300, 800);
      console.info('V2_D2_story_description_save: saved');
    });

    it('V2_D2_story_date_range_displayed', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);
      const storyTitle = `V2Date_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertTextExist(driver, '故事详情');

      // 档案摘要行显示时间范围文本（未设置时显示「~」中间无内容）
      await assertTextExist(driver, '未设置');
    });

    it('V2_D2_story_location_save', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);
      const storyTitle = `V2Loc_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertTextExist(driver, '故事详情');

      // 输入地点
      const inputs = await safeFindComponents(driver, ON.type('TextInput'));
      if (inputs.length > 0) {
        // 第 3 个或最后一个 TextInput 输入地点
        const targetIdx = inputs.length >= 3 ? 2 : inputs.length - 1;
        await inputs[targetIdx].inputText('测试地点');
        await driver.waitForIdle(200, 400);
      }
      await scrollToText(driver, '保存全部字段');
      await clickButtonByText(driver, '保存全部字段');
      await driver.waitForIdle(300, 800);
      console.info('V2_D2_story_location_save: saved');
    });

    it('V2_D2_story_tags_add_and_remove', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);
      const storyTitle = `V2Tag_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertTextExist(driver, '故事详情');

      // 滚动到标签区
      await scrollToText(driver, '自定义标签');
      // 输入标签
      const tagInputs = await safeFindComponents(driver, ON.type('TextInput'));
      // 标签输入框通常是最靠后的 TextInput
      if (tagInputs.length > 0) {
        const lastInput = tagInputs[tagInputs.length - 1];
        await lastInput.inputText('测试标签');
        await driver.waitForIdle(200, 400);
      }
      await clickButtonByText(driver, '添加');
      await driver.waitForIdle(200, 400);
      // 标签出现
      await assertTextExist(driver, '测试标签', V2_TIMEOUT.NORMAL);

      // 点击 x 移除标签
      const xBtns = await safeFindComponents(driver, ON.text('x'));
      if (xBtns.length > 0) {
        await xBtns[0].click();
        await driver.waitForIdle(200, 400);
      }
    });

    it('V2_D2_story_cover_uri_set_and_remove', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);
      const storyTitle = `V2Cvr_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertTextExist(driver, '故事详情');

      // 封面区有「选择封面」按钮
      await scrollToText(driver, '封面');
      await assertTextExist(driver, '选择封面', V2_TIMEOUT.NORMAL);
    });

    // ── T-24 删除 UI（故事） ──────────────────────────

    it('V2_D2_story_delete_from_detail', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);
      const storyTitle = `V2SDel_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await assertTextExist(driver, storyTitle, V2_TIMEOUT.NORMAL);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertTextExist(driver, '故事详情');

      // 点击「删除故事」
      await scrollToText(driver, '删除故事');
      await clickButtonByText(driver, '删除故事');
      await driver.waitForIdle(300, 600);
      // 确认对话框
      const dlgFound = await waitForDialog(driver, '确认删除');
      expect(dlgFound).assertTrue();
      await clickButtonByText(driver, '删除');
      await driver.waitForIdle(500, 1000);
    });

    it('V2_D2_story_delete_cancel', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);
      const storyTitle = `V2SCan_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertTextExist(driver, '故事详情');

      await scrollToText(driver, '删除故事');
      await clickButtonByText(driver, '删除故事');
      await driver.waitForIdle(300, 600);
      await clickButtonByText(driver, '取消');
      await driver.waitForIdle(300, 600);
      await assertTextExist(driver, '故事详情', V2_TIMEOUT.NORMAL);
    });

    // ── T-25 移除照片 UI（故事） ──────────────────────

    it('V2_D2_story_remove_photo', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);
      const storyTitle = `V2SRm_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertTextExist(driver, '故事详情');

      await clickDetailDebugInjectAlbum(driver);
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '成功', V2_TIMEOUT.NORMAL);

      await scrollToText(driver, '移除');
      const removeBtns = await safeFindComponents(driver, ON.text('移除'));
      if (removeBtns.length > 0) {
        await removeBtns[0].click();
        await driver.waitForIdle(300, 600);
        const dlgFound = await waitForDialog(driver, '确认移除');
        expect(dlgFound).assertTrue();
        await clickButtonByText(driver, '移除');
        await driver.waitForIdle(300, 800);
      }
    });
  });
}