/**
 * UriHealthChecker — 照片 URI 有效性校验工具（T-31 ER-01）。
 *
 * 职责：
 *  - 通过 photoAccessHelper.getAssets 错误码区分"本地已删除"与"云端不可访问"
 *  - 返回 UriHealthStatus 枚举值，供 UI 展示对应状态文案
 *
 * 使用方式：
 *  const status: number = await UriHealthChecker.check(uri);
 *  // 返回 1=HEALTHY, 2=LOCAL_DELETED, 3=CLOUD_INACCESSIBLE
 *
 * 注意：
 *  - 需要 UIAbilityContext（通过 AppStorage 获取 'uiContext'，或显式传入）
 *  - 应用需已声明 ohos.permission.READ_IMAGEVIDEO（受控权限）
 */
import { common } from '@kit.AbilityKit';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import { dataSharePredicates } from '@kit.ArkData';
import hilog from '@ohos.hilog';

const DOMAIN = 0x0000;

export class UriHealthChecker {
  /**
   * 检查指定 URI 的健康状态。
   * @param uri 照片 URI
   * @param context 可选 UIAbilityContext，不传时从 AppStorage('uiContext') 读取
   * @returns UriHealthStatus 数值：1=HEALTHY, 2=LOCAL_DELETED, 3=CLOUD_INACCESSIBLE
   */
  static async check(uri: string, context?: common.UIAbilityContext): Promise<number> {
    const ctx: common.UIAbilityContext | undefined = context ??
      AppStorage.Get<common.UIAbilityContext>('uiContext');

    if (ctx === undefined) {
      hilog.warn(DOMAIN, 'UriHealthChecker', 'UIAbilityContext unavailable, default to HEALTHY');
      return 1;
    }

    try {
      const helper = photoAccessHelper.getPhotoAccessHelper(ctx);
      const predicates = new dataSharePredicates.DataSharePredicates();
      predicates.equalTo('uri', uri);
      const fetchOptions: photoAccessHelper.FetchOptions = {
        fetchColumns: ['uri'],
        predicates: predicates
      };
      const fetchResult = await helper.getAssets(fetchOptions);
      const count = fetchResult.getCount();
      fetchResult.close();
      if (count > 0) {
        return 1; // UriHealthStatus.HEALTHY
      }
      hilog.warn(DOMAIN, 'UriHealthChecker', 'getAssets returned 0 results, treat CLOUD_INACCESSIBLE uri=%{public}s', uri);
      return 3; // UriHealthStatus.CLOUD_INACCESSIBLE
    } catch (e) {
      // ArkTS 中捕获的错误对象可安全地用 as 转换后再访问属性
      const errCode = (e as Record<string, Object>)['code'] as number ?? -1;
      // 错误码 13900001 = 文件不存在/已删除（本地已删）
      if (errCode === 13900001) {
        hilog.info(DOMAIN, 'UriHealthChecker', 'LOCAL_DELETED uri=%{public}s code=13900001', uri);
        return 2; // UriHealthStatus.LOCAL_DELETED
      }
      // 其余错误视为云端不可访问（网络、鉴权、云存储错误等）
      hilog.warn(DOMAIN, 'UriHealthChecker', 'CLOUD_INACCESSIBLE uri=%{public}s code=%{public}d', uri, errCode);
      return 3; // UriHealthStatus.CLOUD_INACCESSIBLE
    }
  }
}