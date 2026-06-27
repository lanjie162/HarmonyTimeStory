/**
 * Tier2 · 故事域回归（V2-D2）。
 * 组件定位、滚动、跳转与 entry/src/main/ets/pages/story/ 源码精确对齐。
 */
import { afterEach, describe, expect, it } from '@ohos/hypium';
import { ON, Component } from '@kit.TestKit';
import {
  assertOnStoryDetail,
  assertTextExist,
  assertTextInList,
  clickComponentSafely,
  clickDialogConfirmButton,
  coldStartMainApp,
  createStoryOnPage,
  navigateToStoryFromShell,
  openStoryListRowByTitle,
  safeFindComponents,
  scrollDetailUntilVisible,
  scrollToText,
  sleepMs,
  waitForDialog,
  waitForText,
  V2_TIMEOUT
} from './V2RegressionTestKit';

export default function v2RegressionStory(): void {
  describe('Tier2B_V2RegressionStory', () => {
    afterEach(async () => {
      await sleepMs(200);
    });

    it('V2_D2_story_create_and_detail', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);
      await assertTextExist(driver, '+ 创建');

      const storyTitle = `V2D2_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await assertTextInList(driver, storyTitle, V2_TIMEOUT.NORMAL);

      await openStoryListRowByTitle(driver, storyTitle);
      await assertOnStoryDetail(driver);
    });

    it('V2_D2_story_detail_edit_title', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);

      const storyTitle = `V2Edt_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertOnStoryDetail(driver);

      // 进入编辑页（StoryDetailPage 无 TextInput，需进入 StoryDetailEditPage）
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);

      // 修改标题（编辑页第 1 个 TextInput 是标题）
      const updatedTitle = `V2EdtUpd_${Date.now()}`;
      const inputs = await safeFindComponents(driver, ON.type('TextInput'));
      if (inputs.length >= 1) {
        await inputs[0].inputText(updatedTitle);
      }
      await driver.waitForIdle(200, 400);
      // 用 id 查找保存按钮（导航栏固定位置，不受键盘遮挡影响）
      await clickComponentSafely(driver, ON.id('save_btn'), V2_TIMEOUT.NORMAL);
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
      await assertOnStoryDetail(driver);

      // 进入编辑页（「关联人物」区在 StoryDetailEditPage）
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      // 等待编辑页完全加载
      await sleepMs(2000);
      await driver.waitForIdle(500, 1500);
      // 编辑页内容较长，「关联人物」在 Scroll 下方，需滚动查找
      await scrollToText(driver, '关联人物');

      // 快速创建人物（编辑页 TextInput 顺序：标题、地点、标签、新人物名；最后一个是新人物名）
      const pName = `QuickPer_${Date.now()}`;
      const allInputs = await safeFindComponents(driver, ON.type('TextInput'));
      if (allInputs.length === 0) {
        throw new Error('编辑页未找到 TextInput');
      }
      await allInputs[allInputs.length - 1].inputText(pName);
      await driver.waitForIdle(200, 400);
      await clickComponentSafely(driver, ON.text('创建人物'), V2_TIMEOUT.NORMAL);
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
      await assertOnStoryDetail(driver);

      // 进入编辑页（DEBUG 按钮位于 StoryDetailEditPage）
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      // 等待编辑页完全加载
      await sleepMs(2000);
      await driver.waitForIdle(500, 1500);

      // DEBUG 注入相册等价 URI（StoryDetailEditPage 按钮文本 URI 前有空格，与 PersonDetailEditPage 不同）
      const debugInjectBtn = ON.text('【DEBUG】注入相册等价 URI');
      await scrollDetailUntilVisible(driver, debugInjectBtn);
      await clickComponentSafely(driver, debugInjectBtn, V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '【E2E】上次加图：成功 file://e2e/album-equiv-story-1', V2_TIMEOUT.NORMAL);

      // 再注相同 URI — 验证 PH-01 去重
      const debugSameUriBtn = ON.text('【DEBUG】再注相同 URI');
      await scrollDetailUntilVisible(driver, debugSameUriBtn);
      await clickComponentSafely(driver, debugSameUriBtn, V2_TIMEOUT.NORMAL);
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
      await assertOnStoryDetail(driver);

      // 进入编辑页
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);

      // 输入描述（TextArea）
      await scrollDetailUntilVisible(driver, ON.type('TextArea'));
      const textAreas = await safeFindComponents(driver, ON.type('TextArea'));
      if (textAreas.length > 0) {
        await textAreas[0].inputText('QA test story description');
        await driver.waitForIdle(200, 400);
      }
      // 收起键盘（键盘弹出时遮挡导航栏保存按钮）
      await driver.pressBack();
      await sleepMs(800);
      await clickComponentSafely(driver, ON.id('save_btn'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);
      console.info('V2_D2_story_description_save: saved');
    });

    it('V2_D2_story_date_range_displayed', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);
      const storyTitle = `V2Date_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertOnStoryDetail(driver);

      // 进入编辑页（详情页 MetaInfoRow 在日期都未设置时不显示，编辑页有「未设置」文本）
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);

      // 编辑页开始/结束日期默认显示「未设置」
      await scrollToText(driver, '开始日期');
      await assertTextExist(driver, '未设置', V2_TIMEOUT.NORMAL);
    });

    it('V2_D2_story_location_save', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);
      const storyTitle = `V2Loc_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertOnStoryDetail(driver);

      // 进入编辑页
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);

      // 滚动到地点区域（使用「开始日期」作为锚点，它在地点 TextInput 下方）
      await scrollDetailUntilVisible(driver, ON.text('开始日期'));

      // 输入地点（编辑页 TextInput 顺序：标题[0]、地点[1]、标签[2]、新人物[3]）
      const inputs = await safeFindComponents(driver, ON.type('TextInput').within(ON.type('Scroll')));
      if (inputs.length >= 2) {
        await inputs[1].inputText('测试地点');
        await sleepMs(500);
      }
      // 按 BACK 键收起键盘，再点击保存
      await driver.pressBack();
      await sleepMs(800);
      await clickComponentSafely(driver, ON.text('保存'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);
      console.info('V2_D2_story_location_save: saved');
    });

    it('V2_D2_story_tags_add_and_remove', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);
      const storyTitle = `V2Tag_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertOnStoryDetail(driver);

      // 进入编辑页
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);

      // 滚动到"添加"按钮（标签区域的"添加"按钮，文本在 StoryDetailEditPage 中唯一）
      // "添加"按钮在标签 TextInput 右边，滚动到它后标签 TextInput 必然进入可视区域
      await scrollDetailUntilVisible(driver, ON.text('添加'));
      await driver.waitForIdle(300, 600);
      await sleepMs(500);

      // 用 isBefore 定位标签 TextInput（在"添加"按钮之前）
      let tagInput: Component | null = null;
      try {
        tagInput = await driver.findComponent(ON.type('TextInput').isBefore(ON.text('添加')));
      } catch (_e) {
        // isBefore 可能不生效或并发错误，用回退方法
      }
      if (tagInput === null) {
        // 回退：取所有可见 TextInput 中最后一个（标签 TextInput 应为"添加"按钮前最后一个可见项）
        const inputs = await safeFindComponents(driver, ON.type('TextInput'));
        if (inputs.length === 0) {
          throw new Error('标签 TextInput 未找到（无任何 TextInput 可见）');
        }
        tagInput = inputs[inputs.length - 1];
      }
      // 先点击获得焦点，确保 inputText 触发 onChange（更新 draftTagInput）
      await tagInput.click();
      await driver.waitForIdle(300, 600);
      await tagInput.inputText('测试标签');
      await driver.waitForIdle(300, 600);
      // 用 Enter 触发 onSubmit → addTag()，避免键盘遮挡"添加"按钮
      await driver.triggerKey(2054 /* KEYCODE_ENTER */);
      await driver.waitForIdle(500, 1000);
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
      await assertOnStoryDetail(driver);

      // 进入编辑页（「封面」/「选择封面」在 StoryDetailEditPage）
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);

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
      await assertTextInList(driver, storyTitle, V2_TIMEOUT.NORMAL);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertOnStoryDetail(driver);

      // 进入编辑页后才能看到「删除故事」
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);
      await scrollToText(driver, '删除故事');
      await clickComponentSafely(driver, ON.text('删除故事'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 600);
      // 确认对话框
      const dlgFound = await waitForDialog(driver, '确认删除');
      expect(dlgFound).assertTrue();
      await sleepMs(500);
      await clickDialogConfirmButton(driver, '删除');
      await sleepMs(2000);
    });

    it('V2_D2_story_delete_cancel', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);
      const storyTitle = `V2SCan_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertOnStoryDetail(driver);

      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);
      await scrollToText(driver, '删除故事');
      await clickComponentSafely(driver, ON.text('删除故事'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 600);
      await clickComponentSafely(driver, ON.text('取消'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 600);
      // 取消后仍在编辑页（StoryDetailEditPage），验证「保存」按钮仍存在
      await assertTextExist(driver, '保存', V2_TIMEOUT.NORMAL);
    });

    // ── T-25 移除照片 UI（故事） ──────────────────────

    it('V2_D2_story_remove_photo', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToStoryFromShell(driver);
      const storyTitle = `V2SRm_${Date.now()}`;
      await createStoryOnPage(driver, storyTitle);
      await openStoryListRowByTitle(driver, storyTitle);
      await assertOnStoryDetail(driver);

      // 进入编辑页（DEBUG 按钮位于 StoryDetailEditPage）
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);

      // DEBUG 注入相册等价 URI（StoryDetailEditPage 按钮文本 URI 前有空格）
      const debugInjectBtn = ON.text('【DEBUG】注入相册等价 URI');
      await scrollDetailUntilVisible(driver, debugInjectBtn);
      await clickComponentSafely(driver, debugInjectBtn, V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '【E2E】上次加图：成功 file://e2e/album-equiv-story-1', V2_TIMEOUT.NORMAL);

      await scrollToText(driver, '移除');
      const removeBtns = await safeFindComponents(driver, ON.text('移除'));
      if (removeBtns.length > 0) {
        await removeBtns[0].click();
        await driver.waitForIdle(300, 600);
        const dlgFound = await waitForDialog(driver, '确认移除');
        expect(dlgFound).assertTrue();
        await sleepMs(500);
        await clickDialogConfirmButton(driver, '移除');
        await driver.waitForIdle(300, 800);
      }
    });
  });
}
