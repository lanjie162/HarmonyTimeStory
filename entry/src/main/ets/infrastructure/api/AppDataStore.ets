import type { PersonModel, PhotoAddResult, PhotoRefModel, StoryModel } from '../../domain/model/Models';

/**
 * 人物 / 故事 / 关联 / PhotoOwnerLink 统一数据面（持久化实现见 RepositoryImpl）。
 * features 仅依赖本接口，不依赖 relationalStore。
 */
export interface IAppDataStore {
  listPersons(): PersonModel[];
  createPerson(displayName: string): number;
  getPerson(id: number): PersonModel | null;
  updatePerson(id: number, displayName: string): boolean;
  listStories(): StoryModel[];
  createStory(title: string): number;
  getStory(id: number): StoryModel | null;
  updateStory(id: number, title: string): boolean;
  linkedPersonsForStory(storyId: number): PersonModel[];
  linkPersonStory(personId: number, storyId: number): void;
  unlinkPersonStory(personId: number, storyId: number): void;
  linkedStoriesForPerson(personId: number): StoryModel[];
  isPersonStoryLinked(personId: number, storyId: number): boolean;
  photosForPerson(personId: number): PhotoRefModel[];
  addPhotoForPerson(personId: number, uri: string): PhotoAddResult;
  photosForStory(storyId: number): PhotoRefModel[];
  addPhotoForStory(storyId: number, uri: string): PhotoAddResult;
}
