import type { IStoryService } from '../api/Services';
import type { PersonModel, PhotoAddResult, PhotoRefModel, StoryModel } from '../../domain/model/Models';
import type { IAppDataStore } from '../../infrastructure/api/AppDataStore';

export class StoryService implements IStoryService {
  private readonly store: IAppDataStore;

  constructor(store: IAppDataStore) {
    this.store = store;
  }

  listStories(): StoryModel[] {
    return this.store.listStories();
  }

  createStory(title: string): number {
    return this.store.createStory(title);
  }

  getStory(id: number): StoryModel | null {
    return this.store.getStory(id);
  }

  updateStory(id: number, title: string): boolean {
    return this.store.updateStory(id, title);
  }

  listLinkedPersons(storyId: number): PersonModel[] {
    return this.store.linkedPersonsForStory(storyId);
  }

  linkStoryToPerson(storyId: number, personId: number): void {
    this.store.linkPersonStory(personId, storyId);
  }

  unlinkStoryFromPerson(storyId: number, personId: number): void {
    this.store.unlinkPersonStory(personId, storyId);
  }

  listStoryPhotos(storyId: number): PhotoRefModel[] {
    return this.store.photosForStory(storyId);
  }

  addPhotoToStory(storyId: number, uri: string): PhotoAddResult {
    return this.store.addPhotoForStory(storyId, uri);
  }
}

let storyCached: StoryService | undefined;

export function resetStoryServiceForStore(store: IAppDataStore): void {
  storyCached = new StoryService(store);
}

export function getStoryService(): IStoryService {
  if (storyCached === undefined) {
    throw new Error('StoryService: call installAppDataStore from EntryAbility after RDB open');
  }
  return storyCached;
}
