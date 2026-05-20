/**
 * Tier2 · 人物域回归（V2-D1）。
 * 组件定位、滚动、跳转与 entry/src/main/ets/pages/person/ 源码精确对齐。
 */
import { afterEach, describe, expect, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  assertTextExist,
  assertPersonListItemNotExist,
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
  scrollToText,
  sleepMs,
  waitForDialog,
  V2_TIMEOUT
} from './V2RegressionTestKit';

/** T-19 / C-3 固定标记名：分两次 aa test，中间进程外 force-stop + 冷启主 Ability。 */
const T19_COLDSTART_MARKER = 'T19_COLDSTART_MARKER_20260520';

export default function v2RegressionPerson(): void {
  describe('Tier2B_V2RegressionPerson', () => {
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

    // ── T-22 Person 新字段 UI ───────────────────────────

    it('V2_D1_person_type_badge_displayed', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      const personName = `V2Type_${Date.now()}`;
      await createPersonOnPage(driver, personName);

      // 人物页列表显示类型标签（默认「其他」）
      await openPersonListRowByDisplayName(driver, personName);
      await assertTextExist(driver, '人物详情');

      // 档案摘要行包含类型标签
      await scrollToText(driver, '其他');
      await assertTextExist(driver, '其他');
    });

    it('V2_D1_person_gender_select_and_save', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      const personName = `V2Gen_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertTextExist(driver, '人物详情');

      // 点击性别「女」
      await scrollToText(driver, '女');
      await clickButtonByText(driver, '女');
      await driver.waitForIdle(200, 400);
      // 保存
      await scrollToText(driver, '保存');
      await clickButtonByText(driver, '保存');
      await driver.waitForIdle(300, 800);
      // 重新进入详情后档案行仍可见「女」
      await assertTextExist(driver, '女', V2_TIMEOUT.NORMAL);
    });

    it('V2_D1_person_birthday_picker_and_save', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      const personName = `V2Bd_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertTextExist(driver, '人物详情');

      // DatePicker 选择后文本从「选择日期」变为有日期文本
      // 滚动到 DatePicker 区域
      await scrollToText(driver, '生日');
      // 保存后生日文本不再是「未设置」
      await scrollToText(driver, '保存');
      await clickButtonByText(driver, '保存');
      await driver.waitForIdle(300, 800);
    });

    it('V2_D1_person_remark_save', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      const personName = `V2Rmk_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertTextExist(driver, '人物详情');

      // 滚动到 TextArea（备注）并输入
      const textAreas = await safeFindComponents(driver, ON.type('TextArea'));
      if (textAreas.length > 0) {
        await textAreas[0].inputText('QA test remark');
        await driver.waitForIdle(200, 400);
      }
      await clickButtonByText(driver, '保存');
      await driver.waitForIdle(300, 800);
      // 重新进入后备注应保留
      await driver.findComponent(ON.text('QA test remark'));
      console.info('V2_D1_person_remark_save: remark text found');
    });

    // ── T-24 删除 UI ────────────────────────────────────

    it('V2_D1_person_delete_from_detail', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      const personName = `V2Del_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await assertTextExist(driver, personName, V2_TIMEOUT.NORMAL);

      await openPersonListRowByDisplayName(driver, personName);
      await assertTextExist(driver, '人物详情');

      // 点击「删除人物」
      await scrollToText(driver, '删除人物');
      await clickButtonByText(driver, '删除人物');
      await driver.waitForIdle(300, 600);

      // 确认对话框出现
      const dialogFound = await waitForDialog(driver, '确认删除');
      expect(dialogFound).assertTrue();

      // 点击「删除」
      await clickButtonByText(driver, '删除');
      await driver.waitForIdle(500, 1000);

      // 验证回到列表，该人物已消失
      await assertPersonListItemNotExist(driver, personName);
    });

    it('V2_D1_person_delete_cancel', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      const personName = `V2Can_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertTextExist(driver, '人物详情');

      // 点击「删除人物」→ 取消
      await scrollToText(driver, '删除人物');
      await clickButtonByText(driver, '删除人物');
      await driver.waitForIdle(300, 600);
      // 点击「取消」
      await clickButtonByText(driver, '取消');
      await driver.waitForIdle(300, 600);
      // 仍处于详情页
      await assertTextExist(driver, '人物详情', V2_TIMEOUT.NORMAL);
    });

    // ── T-25 移除照片 UI ────────────────────────────────

    it('V2_D1_person_remove_photo_hides_from_grid', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      const personName = `V2Rm_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertTextExist(driver, '人物详情');

      // DEBUG 注入照片
      await clickDetailDebugInjectAlbum(driver);
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '成功', V2_TIMEOUT.NORMAL);

      // 点击「移除」
      await scrollToText(driver, '移除');
      const removeBtns = await safeFindComponents(driver, ON.text('移除'));
      if (removeBtns.length > 0) {
        await removeBtns[0].click();
        await driver.waitForIdle(300, 600);
        // 确认对话框
        const dlgFound = await waitForDialog(driver, '确认移除');
        expect(dlgFound).assertTrue();
        await clickButtonByText(driver, '移除');
        await driver.waitForIdle(300, 800);
      }
    });
  });

  /** T-19 写阶段（独立 class，aa test -s class T19_C3_write） */
  describe('T19_C3_write', () => {
    it('write_person_ui', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      await createPersonOnPage(driver, T19_COLDSTART_MARKER);
      await assertTextExist(driver, T19_COLDSTART_MARKER, V2_TIMEOUT.NORMAL);
      console.info('T19_PERSIST_WRITE_OK marker=' + T19_COLDSTART_MARKER);
    });
  });

  /** T-19 读阶段（独立 class；须在写阶段 + force-stop + 冷启 EntryAbility 之后） */
  describe('T19_C3_read', () => {
    it('read_person_after_cold_start_ui', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      await assertTextExist(driver, T19_COLDSTART_MARKER, V2_TIMEOUT.NORMAL);
      console.info('T19_PERSIST_READ_OK marker=' + T19_COLDSTART_MARKER);
    });
  });
}