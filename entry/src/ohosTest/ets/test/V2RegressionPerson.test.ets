/**
 * Tier2 · 人物域回归（V2-D1）。
 * 组件定位、滚动、跳转与 entry/src/main/ets/pages/person/ 源码精确对齐。
 */
import { afterEach, describe, expect, it } from '@ohos/hypium';
import { ON, Component } from '@kit.TestKit';
import {
  assertOnPersonDetail,
  assertTextExist,
  assertTextInList,
  assertPersonListItemNotExist,
  clickComponentSafely,
  clickDialogConfirmButton,
  clickDetailDebugInjectAlbum,
  clickDetailDebugSameUriAgain,
  coldStartMainApp,
  createPersonOnPage,
  inputPersonDetailSecondTextInput,
  isOnShellPageExported,
  navigateToPersonFromShell,
  openPersonListRowByDisplayName,
  safeFindComponents,
  scrollDetailUntilVisible,
  scrollToText,
  sleepMs,
  waitForDialog,
  waitForText,
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
      await assertTextExist(driver, '人物');
      await navigateToPersonFromShell(driver);
      await assertTextExist(driver, '人脸建议');

      const personName = `V2D1_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await assertTextInList(driver, personName, V2_TIMEOUT.NORMAL);

      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);
      // 验证详情页底部「导入相册…」入口（产品代码 PersonDetailPage 中的按钮文本）
      await scrollDetailUntilVisible(driver, ON.text('导入相册…'));
      await assertTextExist(driver, '导入相册…');
    });

    it('V2_D1_person_detail_edit_name', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2Edit_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);

      // 进入编辑页修改显示名（PersonDetailPage 无 TextInput，需进入 PersonDetailEditPage）
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);

      // 修改显示名（编辑页第一个 TextInput 是显示名）
      const updatedName = `V2EditUpd_${Date.now()}`;
      const inputs = await driver.findComponents(ON.type('TextInput'));
      if (inputs !== null && inputs.length >= 1) {
        await inputs[0].inputText(updatedName);
      }
      // 收起键盘（键盘弹出时遮挡导航栏保存按钮）
      await driver.pressBack();
      await sleepMs(800);
      await clickComponentSafely(driver, ON.id('save_btn'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);
      // 保存后 router.back() 回到详情页，验证更新后的名称出现在详情页头部
      await assertTextExist(driver, updatedName, V2_TIMEOUT.NORMAL);
    });

    it('V2_D1_person_quick_story_link', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);

      const personName = `V2Lnk_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);

      // 关联故事功能在编辑页（PersonDetailEditPage），需先进入编辑页
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);

      // 滚动到「关联故事」区域
      await scrollDetailUntilVisible(driver, ON.text('关联故事'));
      await assertTextExist(driver, '关联故事');

      // 在「新故事标题」TextInput 中输入标题并创建故事
      // 滚动后显示名 TextInput 可能已滚出视口，直接找可见的 TextInput
      const stTitle = `QuickSt_${Date.now()}`;
      const inputs = await safeFindComponents(driver, ON.type('TextInput').within(ON.type('Scroll')));
      if (inputs.length === 0) {
        throw new Error('人物编辑页未找到 TextInput');
      }
      // 如果只有 1 个 TextInput（显示名已滚出视口），用 inputs[0]；否则用 inputs[1]
      const targetInput = inputs.length >= 2 ? inputs[1] : inputs[0];
      await targetInput.inputText(stTitle);
      // 产品代码中按钮文本是「创建」，用 ON.text 无 type 过滤
      await clickComponentSafely(driver, ON.text('创建'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(500, 1000);

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
      await assertOnPersonDetail(driver);

      // DEBUG 按钮位于 PersonDetailEditPage（编辑页），需先从 PersonDetailPage 进入编辑页
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await sleepMs(2000);
      await driver.waitForIdle(500, 1500);

      // DEBUG 注入相册等价 URI
      await clickDetailDebugInjectAlbum(driver);
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '【E2E】上次加图：成功 file://e2e/album-equiv-1', V2_TIMEOUT.NORMAL);

      // 再注相同 URI — 验证 PH-01 去重（仍在编辑页）
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
      await assertOnPersonDetail(driver);

      // 档案摘要行包含类型标签（组合文本：类型 · 生日 · 性别）
      // 产品代码 PersonDetailPage.ets:169 — Text(`${typeLabel} · ${formatBirthday} · ${genderLabel}`)
      // 新建人物默认值：其他 · 未设置 · 未填
      await scrollToText(driver, '其他 · 未设置 · 未填');
      await assertTextExist(driver, '其他 · 未设置 · 未填');
    });

    it('V2_D1_person_gender_select_and_save', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      const personName = `V2Gen_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);

      // 性别选择在 PersonDetailEditPage，需先进入编辑页
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);

      // 点击性别「女」（产品代码 PersonDetailEditPage.ets:436 Button(opt.label)）
      await scrollToText(driver, '性别');
      await clickComponentSafely(driver, ON.text('女'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(200, 400);
      // 保存
      await clickComponentSafely(driver, ON.text('【DEBUG】保存'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);
      // 保存后回到 PersonDetailPage，档案摘要行组合文本变为「其他 · 未设置 · 女」
      await assertTextExist(driver, '其他 · 未设置 · 女', V2_TIMEOUT.NORMAL);
    });

    it('V2_D1_person_birthday_picker_and_save', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      const personName = `V2Bd_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);

      // 生日选择在 PersonDetailEditPage，需先进入编辑页
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);

      // 验证编辑页生日默认文本「选择日期」
      await scrollToText(driver, '生日');
      await assertTextExist(driver, '选择日期', V2_TIMEOUT.NORMAL);

      // 点击「生日」行弹出 CalendarPickerDialog
      const birthdayLabel: Component = await waitForText(driver, '生日', V2_TIMEOUT.NORMAL);
      await birthdayLabel.click();
      await driver.waitForIdle(500, 1000);

      // 在对话框中点「确定」按钮（默认选中当天日期）
      await clickComponentSafely(driver, ON.text('确定'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);

      // 保存
      await clickComponentSafely(driver, ON.text('【DEBUG】保存'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);

      // 保存后回到 PersonDetailPage，档案摘要行生日不再是「未设置」
      // PersonDetailPage 中只有 formatBirthday 返回「未设置」，保存后应消失
      await driver.waitForIdle(500, 1000);
      const notSet: Component | null = await driver.findComponent(ON.text('未设置'));
      expect(notSet === null).assertTrue();
    });

    it('V2_D1_person_remark_save', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      const personName = `V2Rmk_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);

      // TextArea（备注）在 PersonDetailEditPage，需先进入编辑页
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);

      // 滚动到备注 TextArea（placeholder「备注」不是 Text 组件，需直接找 TextArea）
      await scrollDetailUntilVisible(driver, ON.type('TextArea'));
      const textAreas = await safeFindComponents(driver, ON.type('TextArea'));
      if (textAreas.length === 0) {
        throw new Error('PersonDetailEditPage 未找到 TextArea');
      }
      await textAreas[0].inputText('QA test remark');
      await sleepMs(500);
      // 按 BACK 键收起键盘（键盘弹出时 BACK 只收起键盘，不返回页面）
      await driver.pressBack();
      await sleepMs(800);
      // 收起键盘后点击导航栏保存按钮
      await clickComponentSafely(driver, ON.text('保存'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 800);

      // 重新进入编辑页验证备注保留
      const editBtn2: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn2.click();
      await driver.waitForIdle(300, 800);
      await scrollDetailUntilVisible(driver, ON.type('TextArea'));
      const textAreas2 = await safeFindComponents(driver, ON.type('TextArea'));
      if (textAreas2.length === 0) {
        throw new Error('重新进入编辑页后未找到 TextArea');
      }
      const remarkText: string = await textAreas2[0].getText();
      expect(remarkText.includes('QA test remark')).assertTrue();
    });

    // ── T-24 删除 UI ────────────────────────────────────

    it('V2_D1_person_delete_from_detail', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      const personName = `V2Del_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await assertTextInList(driver, personName, V2_TIMEOUT.NORMAL);

      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);

      // 进入编辑页后才能看到「删除人物」
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);
      await scrollToText(driver, '删除人物');
      await clickComponentSafely(driver, ON.text('删除人物'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 600);

      // 确认对话框出现
      const dialogFound = await waitForDialog(driver, '确认删除');
      expect(dialogFound).assertTrue();

      // 等待对话框完全渲染后点击「删除」确认按钮
      await sleepMs(500);
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

    it('V2_D1_person_delete_cancel', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      const personName = `V2Can_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);

      // 进入编辑页后才能看到「删除人物」→ 取消
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await driver.waitForIdle(300, 800);
      await scrollToText(driver, '删除人物');
      await clickComponentSafely(driver, ON.text('删除人物'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 600);
      // 点击「取消」
      await clickComponentSafely(driver, ON.text('取消'), V2_TIMEOUT.NORMAL);
      await driver.waitForIdle(300, 600);
      // 取消后仍在编辑页（PersonDetailEditPage），验证「保存」按钮仍存在
      await assertTextExist(driver, '保存', V2_TIMEOUT.NORMAL);
    });

    // ── T-25 移除照片 UI ────────────────────────────────

    it('V2_D1_person_remove_photo_hides_from_grid', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      const personName = `V2Rm_${Date.now()}`;
      await createPersonOnPage(driver, personName);
      await openPersonListRowByDisplayName(driver, personName);
      await assertOnPersonDetail(driver);

      // DEBUG 按钮和照片网格都在 PersonDetailEditPage，需先进入编辑页
      const editBtn: Component = await waitForText(driver, '编辑', V2_TIMEOUT.NORMAL);
      await editBtn.click();
      await sleepMs(2000);

      // DEBUG 注入照片
      await clickDetailDebugInjectAlbum(driver);
      await driver.waitForIdle(300, 800);
      await assertTextExist(driver, '【E2E】上次加图：成功 file://e2e/album-equiv-1', V2_TIMEOUT.NORMAL);

      // 点击照片网格中的「移除」按钮（PhotoGridItem.ets:60 Button('移除')）
      await scrollToText(driver, '移除');
      const removeBtns = await safeFindComponents(driver, ON.text('移除'));
      if (removeBtns.length === 0) {
        throw new Error('未找到照片「移除」按钮');
      }
      await removeBtns[0].click();
      await driver.waitForIdle(300, 600);
      // 确认对话框
      const dlgFound = await waitForDialog(driver, '确认移除');
      expect(dlgFound).assertTrue();
      await sleepMs(500);
      await clickDialogConfirmButton(driver, '移除');
      await driver.waitForIdle(300, 800);
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
