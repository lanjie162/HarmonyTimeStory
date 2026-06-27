import photoAccessHelper from '@ohos.file.photoAccessHelper';

/**
 * 照片元数据辅助工具
 */
export class PhotoMetadataHelper {
  /**
   * 从照片 URI 获取拍摄时间
   * @param uri 照片 URI
   * @returns 拍摄时间（毫秒时间戳），如果无法获取则返回 undefined
   */
  static async getTakenAt(uri: string): Promise<number | undefined> {
    try {
      const context = getContext(this);
      const photoAccessHelperInstance = photoAccessHelper.getPhotoAccessHelper(context);
      
      // 构建查询谓词，根据 URI 查询照片
      const predicates = new photoAccessHelper.PhotoAccessHelperPredicates();
      predicates.equalTo('uri', uri);
      
      // 查询照片
      const fetchOption = {
        fetchColumns: ['date_taken']
      };
      
      const result = await photoAccessHelperInstance.getAssets(predicates, fetchOption);
      
      if (result && result.getCount() > 0) {
        await result.goToFirstRow();
        const dateTaken = result.getLong(result.getColumnIndex('date_taken'));
        if (dateTaken > 0) {
          return dateTaken;
        }
      }
    } catch (e) {
      console.error('PhotoMetadataHelper', `Failed to get takenAt for ${uri}: ${JSON.stringify(e)}`);
    }
    return undefined;
  }

  /**
   * 批量获取照片拍摄时间
   * @param uris 照片 URI 数组
   * @returns Map<URI, takenAt>
   */
  static async getTakenAtBatch(uris: string[]): Promise<Map<string, number | undefined>> {
    const result = new Map<string, number | undefined>();
    for (const uri of uris) {
      const takenAt = await this.getTakenAt(uri);
      result.set(uri, takenAt);
    }
    return result;
  }
}
