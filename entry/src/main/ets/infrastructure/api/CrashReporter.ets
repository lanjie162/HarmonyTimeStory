/**
 * 崩溃上报管理器（Singleton）。
 *
 * 职责：
 * - 注册 ErrorManager 全局错误/未捕获 Promise 拒绝回调
 * - 开关控制（AppStorage 持久化，默认开启）
 * - 集成系统 FaultLogger 查询历史故障日志（D-M2-1 采纳方案 A）
 * - 提供崩溃诊断摘要供隐私页展示
 *
 * 集成方案：D-M2-1 采纳方案 A（系统内置 FaultLogger）。
 * 仅在开关开启时记录崩溃栈（hilog.error），不上传原图、可匿名/去标识化。
 */
import { errorManager } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';
import { FaultLogger } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN = 0x0000;
const PREF_KEY = 'ts_crash_report_enabled';

/** 适配 ArkTS implements-only-iface 规则：本地接口，使用时 cast 到 errorManager.ErrorObserver。 */
interface CrashErrorObserver {
  onUnhandledException(errMsg: string): void;
  onException(errObject: Error): void;
}

class CrashErrorObserverImpl implements CrashErrorObserver {
  onUnhandledException(errMsg: string): void {
    if (!CrashReporter.getInstance().isEnabled()) {
      return;
    }
    hilog.error(DOMAIN, 'CrashReporter', 'Unhandled exception: %{public}s', errMsg);
  }

  onException(errObject: Error): void {
    if (!CrashReporter.getInstance().isEnabled()) {
      return;
    }
    hilog.error(DOMAIN, 'CrashReporter', 'Exception name=%{public}s message=%{public}s',
      errObject.name, errObject.message);
    if (typeof errObject.stack === 'string') {
      hilog.error(DOMAIN, 'CrashReporter', 'Exception stack: %{public}s', errObject.stack);
    }
  }
}

/** 崩溃诊断摘要信息。 */
export interface CrashDiagnosisSummary {
  /** 崩溃总数（JS + CPP + FREEZE） */
  totalCount: number;
  /** 最近一次崩溃的简要原因 */
  lastReason: string;
  /** 最近一次崩溃的时间戳（毫秒） */
  lastTimestamp: number;
  /** 是否正在查询中 */
  loading: boolean;
}

export class CrashReporter {
  private static instance: CrashReporter;
  private observerId: number = -1;
  private registered: boolean = false;

  private constructor() {
    // 确保 AppStorage 有默认值
    if (AppStorage.Get<boolean>(PREF_KEY) === undefined) {
      AppStorage.SetOrCreate<boolean>(PREF_KEY, true);
    }
  }

  static getInstance(): CrashReporter {
    if (CrashReporter.instance === undefined) {
      CrashReporter.instance = new CrashReporter();
    }
    return CrashReporter.instance;
  }

  /** 上报开关是否开启。 */
  isEnabled(): boolean {
    const val = AppStorage.Get<boolean>(PREF_KEY);
    return val === undefined ? true : val;
  }

  /** 设置上报开关。开启时自动注册监听，关闭时自动取消注册。 */
  setEnabled(enabled: boolean): void {
    AppStorage.SetOrCreate<boolean>(PREF_KEY, enabled);
    if (enabled) {
      this.register();
    } else {
      this.unregister();
    }
  }

  /** 注册全局错误监听。仅在开关开启时生效。 */
  register(): void {
    if (this.registered) {
      return;
    }
    if (!this.isEnabled()) {
      hilog.info(DOMAIN, 'CrashReporter', 'reporting disabled, skip registration');
      return;
    }

    try {
      this.observerId = errorManager.on('error', new CrashErrorObserverImpl() as errorManager.ErrorObserver);
      this.registered = true;
      hilog.info(DOMAIN, 'CrashReporter', 'registered, observerId=%{public}d', this.observerId);
    } catch (e) {
      hilog.error(DOMAIN, 'CrashReporter', 'register failed: %{public}s', (e as BusinessError).message);
    }
  }

  /** 取消注册全局错误监听。 */
  unregister(): void {
    if (!this.registered || this.observerId < 0) {
      return;
    }
    try {
      errorManager.off('error', this.observerId);
      hilog.info(DOMAIN, 'CrashReporter', 'unregistered');
    } catch (e) {
      hilog.error(DOMAIN, 'CrashReporter', 'unregister failed: %{public}s', (e as BusinessError).message);
    }
    this.registered = false;
    this.observerId = -1;
  }

  /**
   * T-34：查询 FaultLogger 最近崩溃诊断摘要。
   * 查询所有故障类型（JS_CRASH, CPP_CRASH, APP_FREEZE），合并返回摘要。
   * 不上传原图、可匿名/去标识化。
   *
   * @returns 崩溃诊断摘要
   */
  async queryCrashDiagnosisSummary(): Promise<CrashDiagnosisSummary> {
    const summary: CrashDiagnosisSummary = {
      totalCount: 0,
      lastReason: '',
      lastTimestamp: 0,
      loading: false
    };

    if (!this.isEnabled()) {
      return summary;
    }

    const types: FaultLogger.FaultType[] = [
      FaultLogger.FaultType.JS_CRASH,
      FaultLogger.FaultType.CPP_CRASH,
      FaultLogger.FaultType.APP_FREEZE
    ];

    try {
      for (const faultType of types) {
        const logs: FaultLogger.FaultLogInfo[] = await FaultLogger.query(faultType);
        if (logs !== undefined && logs.length > 0) {
          summary.totalCount += logs.length;
          for (const log of logs) {
            if (log.timestamp > summary.lastTimestamp) {
              summary.lastTimestamp = log.timestamp;
              summary.lastReason = log.reason;
            }
          }
        }
      }
    } catch (e) {
      hilog.warn(DOMAIN, 'CrashReporter', 'queryFaultLogger failed: %{public}s',
        (e as BusinessError).message);
    }

    return summary;
  }

  /**
   * 获取崩溃诊断摘要的文案描述（用于隐私页显示）。
   */
  async getCrashDiagnosisText(): Promise<string> {
    const summary = await this.queryCrashDiagnosisSummary();
    if (summary.totalCount === 0) {
      return '截至目前，未检测到应用崩溃记录。崩溃诊断信息仅在本机记录，不上传任何服务器。';
    }
    const lastDate = new Date(summary.lastTimestamp);
    const dateStr = `${lastDate.getFullYear()}-${String(lastDate.getMonth() + 1).padStart(2, '0')}-${String(lastDate.getDate()).padStart(2, '0')}`;
    return `截至目前，共记录 ${summary.totalCount} 条崩溃/故障日志。最近一次于 ${dateStr}，原因：${summary.lastReason}。所有诊断信息仅在本机记录，不上传任何服务器。`;
  }
}