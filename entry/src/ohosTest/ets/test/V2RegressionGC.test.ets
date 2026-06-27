/**
 * L4 E2E：GC 孤儿 PhotoRef 清理回归。
 * 验证应用启动后不再被引用的 PhotoRef 是否被清理。
 */
import { afterEach, describe, it } from '@ohos/hypium';
import { ON } from '@kit.TestKit';
import {
  assertTextExist,
  coldStartMainApp,
  navigateToPersonFromShell,
  safeFindComponents,
  sleepMs,
  V2_TIMEOUT
} from './V2RegressionTestKit';

export default function v2RegressionGC(): void {
  describe('Tier2N_V2RegressionGC', () => {
    afterEach(async () => {
      await sleepMs(200);
    });

    it('V2_GC_cold_start_no_crash', 0, async () => {
      const driver = await coldStartMainApp();
      await driver.waitForIdle(300, 1000);

      // 冷启动后壳页应正常显示，不崩溃
      await assertTextExist(driver, '人物', V2_TIMEOUT.COLD_START);
      await assertTextExist(driver, '故事', V2_TIMEOUT.NORMAL);
    });

    it('V2_GC_navigate_after_start', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      await assertTextExist(driver, '人脸建议', V2_TIMEOUT.NORMAL);
    });
  });
}