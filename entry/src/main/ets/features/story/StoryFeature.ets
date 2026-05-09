import type { IStoryService } from '../api/Services';
import type { PersonModel, PhotoAddResult, PhotoRefModel, StoryModel } from '../../domain/model/Models';
import { singletonMemoryStore, type LocalMemoryStore } from '../../infrastructure/store/LocalMemoryStore';

export class StoryService implements IStoryService {
  private readonly store: LocalMemoryStore;

  constructor(store?: LocalMemoryStore) {
    this.store = store ?? singletonMemoryStore();
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

export function getStoryService(): IStoryService {
  if (!storyCached) {
    storyCached = new StoryService();
  }
  return storyCached;
}
