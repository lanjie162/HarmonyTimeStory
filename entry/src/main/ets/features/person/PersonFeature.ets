import type { IPersonService } from '../api/Services';
import type { PersonModel, PhotoAddResult, PhotoRefModel, StoryModel } from '../../domain/model/Models';
import type { IAppDataStore } from '../../infrastructure/api/AppDataStore';

export class PersonService implements IPersonService {
  private readonly store: IAppDataStore;

  constructor(store: IAppDataStore) {
    this.store = store;
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

/** 由 bootstrap 在 RDB 就绪后注入；未注入前勿调用 getPersonService。 */
export function resetPersonServiceForStore(store: IAppDataStore): void {
  cached = new PersonService(store);
}

/** 应用内单例，供页面使用（依赖 installAppDataStore）。 */
export function getPersonService(): IPersonService {
  if (cached === undefined) {
    throw new Error('PersonService: call installAppDataStore from EntryAbility after RDB open');
  }
  return cached;
}
