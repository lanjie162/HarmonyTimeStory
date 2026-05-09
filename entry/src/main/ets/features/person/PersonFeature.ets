import type { IPersonService } from '../api/Services';
import type { PersonModel, PhotoAddResult, PhotoRefModel, StoryModel } from '../../domain/model/Models';
import { singletonMemoryStore, type LocalMemoryStore } from '../../infrastructure/store/LocalMemoryStore';

export class PersonService implements IPersonService {
  private readonly store: LocalMemoryStore;

  constructor(store?: LocalMemoryStore) {
    this.store = store ?? singletonMemoryStore();
  }

  listPersons(): PersonModel[] {
    return this.store.listPersons();
  }

  createPerson(displayName: string): number {
    return this.store.createPerson(displayName);
  }

  getPerson(id: number): PersonModel | null {
    return this.store.getPerson(id);
  }

  updatePerson(id: number, displayName: string): boolean {
    return this.store.updatePerson(id, displayName);
  }

  listLinkedStories(personId: number): StoryModel[] {
    return this.store.linkedStoriesForPerson(personId);
  }

  linkPersonToStory(personId: number, storyId: number): void {
    this.store.linkPersonStory(personId, storyId);
  }

  unlinkPersonFromStory(personId: number, storyId: number): void {
    this.store.unlinkPersonStory(personId, storyId);
  }

  isLinked(personId: number, storyId: number): boolean {
    return this.store.isPersonStoryLinked(personId, storyId);
  }

  listPersonPhotos(personId: number): PhotoRefModel[] {
    return this.store.photosForPerson(personId);
  }

  addPhotoToPerson(personId: number, uri: string): PhotoAddResult {
    return this.store.addPhotoForPerson(personId, uri);
  }
}

let cached: PersonService | undefined;

/** 应用内单例，供页面与后续 bootstrap 注入对齐。 */
export function getPersonService(): IPersonService {
  if (!cached) {
    cached = new PersonService();
  }
  return cached;
}
