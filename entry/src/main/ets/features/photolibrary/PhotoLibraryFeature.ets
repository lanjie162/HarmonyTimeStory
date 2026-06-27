import type { IPhotoLibraryService } from '../api/Services';
import type { IAppDataStore } from '../../infrastructure/api/AppDataStore';

export class PhotoLibraryService implements IPhotoLibraryService {
  private readonly store: IAppDataStore;

  constructor(store: IAppDataStore) {
    this.store = store;
  }

  markPhotoAsFailed(photoRefId: number, status: number): void {
    this.store.updatePhotoRefStatus(photoRefId, status);
  }
}

let cached: PhotoLibraryService | undefined;

export function resetPhotoLibraryServiceForStore(store: IAppDataStore): void {
  cached = new PhotoLibraryService(store);
}

export function getPhotoLibraryService(): IPhotoLibraryService {
  if (cached === undefined) {
    throw new Error('PhotoLibraryService: call installAppDataStore from EntryAbility after RDB open');
  }
  return cached;
}