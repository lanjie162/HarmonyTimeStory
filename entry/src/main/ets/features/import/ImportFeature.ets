import type { IImportService } from '../api/Services';

/**
 * B2 最小实现：内存中的「当前长任务」槽位 + cancelRequest 语义。
 * 真实扫描/媒体管线可后续替换为系统 B2；此处满足 T-7 可复核与 UI 联动。
 */
export class ImportService implements IImportService {
  private seq = 0;
  private activeId = 0;
  private cancelSignal = false;

  beginLongTask(): number {
    this.seq++;
    this.activeId = this.seq;
    this.cancelSignal = false;
    return this.activeId;
  }

  cancelRequest(requestId: number): boolean {
    if (requestId > 0 && requestId === this.activeId) {
      this.cancelSignal = true;
      return true;
    }
    return false;
  }

  isCancelled(requestId: number): boolean {
    return requestId > 0 && requestId === this.activeId && this.cancelSignal;
  }

  endLongTask(requestId: number): void {
    if (requestId > 0 && requestId === this.activeId) {
      this.activeId = 0;
      this.cancelSignal = false;
    }
  }
}

let importCached: ImportService | undefined;

export function getImportService(): IImportService {
  if (!importCached) {
    importCached = new ImportService();
  }
  return importCached;
}
