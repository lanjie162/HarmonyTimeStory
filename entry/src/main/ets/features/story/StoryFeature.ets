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

  deleteStory(id: number): boolean {
    return this.store.deleteStory(id);
  }

  updateStory(id: number, title: string): boolean {
    return this.store.updateStory(id, title);
  }

  updateStoryAll(id: number, title: string, description?: string, timeStart?: number | null, timeEnd?: number | null, coverUri?: string, location?: string, tags?: string[]): boolean {
    return this.store.updateStoryAll!(id, {
      title,
      description,
      timeStart,
      timeEnd,
      coverUri,
      location,
      tags
    });
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
