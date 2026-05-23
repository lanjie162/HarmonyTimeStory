import type { IAppDataStore } from '../infrastructure/api/AppDataStore';
import { resetPersonServiceForStore } from '../features/person/PersonFeature';
import { resetStoryServiceForStore } from '../features/story/StoryFeature';
import { resetPhotoLibraryServiceForStore } from '../features/photolibrary/PhotoLibraryFeature';

/**
 * RDB 就绪后装配人物/故事领域服务 + 图库服务（共享同一 IAppDataStore 真相）。
 * 须在 `windowStage.loadContent` 之前调用。
 */
export function installAppDataStore(store: IAppDataStore): void {
  resetPersonServiceForStore(store);
  resetStoryServiceForStore(store);
  resetPhotoLibraryServiceForStore(store);
}
