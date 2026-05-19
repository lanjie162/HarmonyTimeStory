/**
 * V2.1 G-3 Out：人物列表空态 / 无 owner 进导入向导（`V2_D3_import_empty_owner_id_warning`）。
 * 未纳入 ohosTest List.test.ets；恢复前须空库或隔离 DB 策略。
 * @see document/meeting/[主持人]2026-05-20-V2.1持久化闸门版结项评审纪要.md G-3
 */
import { afterEach, describe, it } from '@ohos/hypium';
import {
  assertTextExist,
  coldStartMainApp,
  navigateToPersonFromShell,
  sleepMs
} from '../V2RegressionTestKit';

export default function v2RegressionImportEmptyOwnerDeferred(): void {
  describe('Tier2D_V2RegressionImportEmptyOwner_deferred', () => {
    afterEach(async () => {
      await sleepMs(200);
    });

    it('V2_D3_import_empty_owner_id_warning', 0, async () => {
      const driver = await coldStartMainApp();
      await navigateToPersonFromShell(driver);
      await assertTextExist(driver, '还没有人物档案');
    });
  });
}
