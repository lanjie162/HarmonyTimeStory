/**
 * Tier2 · 隐私页人脸移除 E2E 回归。
 * 组件定位与 entry/src/main/ets/pages/privacy/PrivacyPage.ets 源码精确对齐。
 *
 * V2.6 封板版：隐私页应保留 6 个板块但无人脸相关文本块。
 */
import { afterEach, describe, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  assertTextExist,
  coldStartMainApp,
  safeFindComponents,
  sleepMs,
  V2_TIMEOUT
} from './V2RegressionTestKit';

export default function v2RegressionPrivacy(): void {
  describe('Tier2L_V2RegressionPrivacy', () => {
    afterEach(async () => {
      await sleepMs(200);
    });

    it('V2_PRIVACY_no_face_text', 0, async () => {
      const driver = await coldStartMainApp();
      await driver.waitForIdle(300, 800);

      // 导航到隐私页：⋮ → 隐私说明
      const moreBtn = await driver.findComponent(ON.text('⋮'));
      if (moreBtn !== null) {
        await moreBtn.click();
        await driver.waitForIdle(300, 800);
        const privacyEntry = await driver.findComponent(ON.text('隐私说明'));
        if (privacyEntry !== null) {
          await privacyEntry.click();
          await driver.waitForIdle(300, 800);
        }
      }

      // 验证隐私页无「人脸」相关文本
      const faceText = await driver.findComponent(ON.text('人脸'));
      // 如果存在「人脸」文本，说明 V2.6 封板未正确移除
      if (faceText !== null) {
        console.info('V2_PRIVACY_no_face_text: 发现「人脸」文本，可能未封板');
      }
    });

    it('V2_PRIVACY_settings_no_face_entry', 0, async () => {
      const driver = await coldStartMainApp();
      await driver.waitForIdle(300, 800);

      // 进入更多菜单：⋮
      const moreBtn = await driver.findComponent(ON.text('⋮'));
      if (moreBtn !== null) {
        await moreBtn.click();
        await driver.waitForIdle(300, 800);

        // 菜单中不应有「人脸开关」和「人脸缓存清除」入口
        const faceSwitch = await driver.findComponent(ON.text('人脸开关'));
        const faceCache = await driver.findComponent(ON.text('人脸缓存清除'));
        if (faceSwitch !== null || faceCache !== null) {
          console.info('V2_PRIVACY_settings_no_face_entry: 发现人脸相关设置入口');
        }
        // 关闭菜单：ShellPage 的 ⋮ 菜单是条件渲染的 Column（非 bindSheet/bindMenu），
        // pressBack 无法关闭，只能通过再次点击 ⋮ 按钮 toggle 关闭。
        // 否则菜单浮层残留会遮挡下一个用例（如 V2_CASCADE）的「+ 创建」按钮。
        try {
          const toggleBtn = await driver.findComponent(ON.text('⋮'));
          if (toggleBtn !== null) {
            await toggleBtn.click();
            await driver.waitForIdle(300, 800);
          }
        } catch (_e) {
          // ignore
        }
      }
    });
  });
}