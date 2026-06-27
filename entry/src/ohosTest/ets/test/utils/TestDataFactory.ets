import type { CreatePersonParams } from '../../../../main/ets/infrastructure/api/AppDataStore';
import type { PhotoMetadata } from '../../../../main/ets/domain/model/Models';

export class TestDataFactory {
  private static seq = 0;

  static uniqueName(prefix: string = 'Test'): string {
    return `${prefix}_${Date.now()}_${++TestDataFactory.seq}`;
  }

  static createPersonParams(overrides?: Partial<CreatePersonParams>): CreatePersonParams {
    const result: CreatePersonParams = {
      displayName: overrides?.displayName ?? TestDataFactory.uniqueName('Person')
    };
    if (overrides?.avatarBlob !== undefined) {
      result.avatarBlob = overrides.avatarBlob;
    }
    if (overrides?.birthday !== undefined) {
      result.birthday = overrides.birthday;
    }
    if (overrides?.gender !== undefined) {
      result.gender = overrides.gender;
    }
    if (overrides?.remark !== undefined) {
      result.remark = overrides.remark;
    }
    if (overrides?.personType !== undefined) {
      result.personType = overrides.personType;
    }
    return result;
  }

  static createStoryTitle(overrides?: string): string {
    return overrides ?? TestDataFactory.uniqueName('Story');
  }

  static createPhotoUri(index?: number): string {
    return `file://test/photo_${Date.now()}_${index ?? ++TestDataFactory.seq}`;
  }

  static createPhotoMetadata(overrides?: Partial<PhotoMetadata>): PhotoMetadata {
    const result: PhotoMetadata = {
      takenAt: overrides?.takenAt ?? Date.now()
    };
    if (overrides?.latitude !== undefined) {
      result.latitude = overrides.latitude;
    }
    if (overrides?.longitude !== undefined) {
      result.longitude = overrides.longitude;
    }
    if (overrides?.width !== undefined) {
      result.width = overrides.width;
    }
    if (overrides?.height !== undefined) {
      result.height = overrides.height;
    }
    if (overrides?.fileSize !== undefined) {
      result.fileSize = overrides.fileSize;
    }
    if (overrides?.cameraModel !== undefined) {
      result.cameraModel = overrides.cameraModel;
    }
    return result;
  }

  static resetSeq(): void {
    TestDataFactory.seq = 0;
  }
}
