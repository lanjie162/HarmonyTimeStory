/**
 * L3 集成测试：ImportService（导入向导 B2 可取消长任务协调）。
 * 覆盖 beginLongTask / cancelRequest / isCancelled / endLongTask 四条 API。
 * ImportService 是纯内存服务，不依赖 RDB，无需 TestDbHelper。
 */
import { afterEach, describe, expect, it } from '@ohos/hypium';
import { getImportService } from '../../../main/ets/features/import/ImportFeature';
import type { IImportService } from '../../../main/ets/features/api/Services';

export default function l3ImportService(): void {
  describe('L3_importService', () => {
    afterEach((): void => {
      // 清理：确保无残留活动任务
      const svc = getImportService();
      svc.endLongTask(999); // 不存在的 id，无副作用
    });

    it('L3_import_beginLongTask_returns_positive_seq', 0, (): void => {
      const svc: IImportService = getImportService();
      const id1 = svc.beginLongTask();
      expect(id1).assertLarger(0);

      const id2 = svc.beginLongTask();
      expect(id2).assertLarger(0);
      // 单调递增
      expect(id2).assertLarger(id1);

      svc.endLongTask(id2);
    });

    it('L3_import_cancelRequest_active_id_returns_true', 0, (): void => {
      const svc: IImportService = getImportService();
      const id = svc.beginLongTask();
      const ok = svc.cancelRequest(id);
      expect(ok).assertTrue();
      expect(svc.isCancelled(id)).assertTrue();
      svc.endLongTask(id);
    });

    it('L3_import_cancelRequest_wrong_id_returns_false', 0, (): void => {
      const svc: IImportService = getImportService();
      const id = svc.beginLongTask();
      const ok = svc.cancelRequest(id + 999);
      expect(ok).assertFalse();
      expect(svc.isCancelled(id)).assertFalse();
      svc.endLongTask(id);
    });

    it('L3_import_cancelRequest_zero_id_returns_false', 0, (): void => {
      const svc: IImportService = getImportService();
      const ok = svc.cancelRequest(0);
      expect(ok).assertFalse();
    });

    it('L3_import_cancelRequest_negative_id_returns_false', 0, (): void => {
      const svc: IImportService = getImportService();
      const ok = svc.cancelRequest(-1);
      expect(ok).assertFalse();
    });

    it('L3_import_isCancelled_no_cancel_returns_false', 0, (): void => {
      const svc: IImportService = getImportService();
      const id = svc.beginLongTask();
      expect(svc.isCancelled(id)).assertFalse();
      svc.endLongTask(id);
    });

    it('L3_import_isCancelled_zero_id_returns_false', 0, (): void => {
      const svc: IImportService = getImportService();
      expect(svc.isCancelled(0)).assertFalse();
    });

    it('L3_import_endLongTask_clears_active', 0, (): void => {
      const svc: IImportService = getImportService();
      const id = svc.beginLongTask();
      svc.cancelRequest(id);
      svc.endLongTask(id);
      // 结束后 cancelRequest 不再匹配
      expect(svc.cancelRequest(id)).assertFalse();
      expect(svc.isCancelled(id)).assertFalse();
    });

    it('L3_import_endLongTask_wrong_id_no_effect', 0, (): void => {
      const svc: IImportService = getImportService();
      const id = svc.beginLongTask();
      svc.endLongTask(id + 1);
      // 活动任务不受影响
      expect(svc.cancelRequest(id)).assertTrue();
      svc.endLongTask(id);
    });

    it('L3_import_sequence_independent', 0, (): void => {
      const svc: IImportService = getImportService();
      const id1 = svc.beginLongTask();
      svc.cancelRequest(id1);
      svc.endLongTask(id1);

      // 下一段 beginLongTask 应返回新 seq
      const id2 = svc.beginLongTask();
      expect(id2).assertLarger(id1);
      expect(svc.cancelRequest(id2)).assertTrue();
      svc.endLongTask(id2);
    });
  });
}