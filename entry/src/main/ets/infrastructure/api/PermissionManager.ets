import { abilityAccessCtrl, common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import bundleManager from '@ohos.bundle.bundleManager';
import hilog from '@ohos.hilog';

export interface PermissionResult {
  granted: boolean;
  /** 用户选择了"不再询问"（永久拒绝），需要引导去系统设置 */
  isPermanentlyDenied: boolean;
}

const PERM_READ_IMAGEVIDEO = 'ohos.permission.READ_IMAGEVIDEO';
const DOMAIN = 0x0000;

/**
 * 权限管理工具类（Singleton）。
 *
 * 职责：媒体库权限（READ_IMAGEVIDEO）的检查、请求、拒绝检测、引导跳转。
 * 放 infrastructure/api 层，跨特性可复用（T-31 后台扫描也需要）。
 *
 * 注意：当前 module.json5 中未声明 ohos.permission.READ_IMAGEVIDEO
 * （受控权限需 AGC ACL 审批），因此 hasMediaPermission() 始终返回 false，
 * requestMediaPermission() 会抛异常并在 catch 后返回拒绝态。
 * PermissionManager 的完整功能需在 T-31 后台扫描上线 + AGC 批准 ACL 后启用。
 */
export class PermissionManager {
  private static instance: PermissionManager;
  private atManager: abilityAccessCtrl.AtManager;

  private constructor() {
    this.atManager = abilityAccessCtrl.createAtManager();
  }

  static getInstance(): PermissionManager {
    if (PermissionManager.instance === undefined) {
      PermissionManager.instance = new PermissionManager();
    }
    return PermissionManager.instance;
  }

  /** 同步检查 READ_IMAGEVIDEO 是否已授予。 */
  hasMediaPermission(context: common.UIAbilityContext): boolean {
    try {
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      const tokenID = bundleInfo.appInfo.accessTokenId;
      const status = this.atManager.checkAccessTokenSync(tokenID, PERM_READ_IMAGEVIDEO);
      return status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (e) {
      hilog.error(DOMAIN, 'PermissionManager', 'checkAccessToken failed: %{public}s', (e as BusinessError).message);
      return false;
    }
  }

  /** 请求 READ_IMAGEVIDEO 权限，返回授权结果及是否永久拒绝。 */
  async requestMediaPermission(context: common.UIAbilityContext): Promise<PermissionResult> {
    try {
      const data = await this.atManager.requestPermissionsFromUser(context, [PERM_READ_IMAGEVIDEO]);
      const authResult = data.authResults[0];
      // dialogShownResults: true=有弹窗, false=无弹窗（用户此前已选"不再询问"）
      const dialogShown = data.dialogShownResults !== undefined ? data.dialogShownResults[0] : true;
      const granted = authResult === 0;
      // 未授权 且 未弹窗 = 用户之前选过"不再询问"（永久拒绝）
      const isPermanentlyDenied = !granted && dialogShown === false;
      return { granted, isPermanentlyDenied };
    } catch (e) {
      hilog.error(DOMAIN, 'PermissionManager', 'requestPermission failed: %{public}s', (e as BusinessError).message);
      return { granted: false, isPermanentlyDenied: false };
    }
  }

  /**
   * 跳转系统设置的应用权限页。
   * 通过 startAbility 打开系统 Settings 的 application_info 页。
   * 若跳转失败，fallback 提示用户手动前往。
   */
  openAppPermissionSettings(context: common.UIAbilityContext): void {
    try {
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT
      );
      const want: Want = {
        bundleName: 'com.huawei.hmos.settings',
        abilityName: 'com.huawei.hmos.settings.MainAbility',
        uri: 'application_info_entry',
        parameters: {
          pushParams: bundleInfo.name
        }
      };
      context.startAbility(want);
      hilog.info(DOMAIN, 'PermissionManager', 'openSettings want sent: %{public}s', bundleInfo.name);
    } catch (e) {
      hilog.error(DOMAIN, 'PermissionManager', 'openSettings failed: %{public}s', (e as BusinessError).message);
      // fallback: 提示用户手动前往
    }
  }
}