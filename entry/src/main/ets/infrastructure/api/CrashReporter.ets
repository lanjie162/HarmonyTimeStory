/**
 * 崩溃上报管理器（Singleton）。
 *
 * 职责：
 * - 注册 ErrorManager 全局错误/未捕获 Promise 拒绝回调
 * - 开关控制（AppStorage 持久化，默认开启）
 * - 可选查询 FaultLogger 历史故障日志
 *
 * 集成方案：D-M2-1 采纳方案 A（系统内置 FaultLogger）。
 * 仅在开关开启时记录崩溃栈（hilog.error），不上传原图、可匿名/去标识化。
 */
import { errorManager } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';
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

  /** 设置上报开关。 */
  setEnabled(enabled: boolean): void {
    AppStorage.SetOrCreate<boolean>(PREF_KEY, enabled);
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
}