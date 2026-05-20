import type { GenderEnum, PersonModel, PersonTypeEnum, PhotoAddResult, PhotoRefModel, StoryModel } from '../../domain/model/Models';

/** 创建人物时传递的全部可选字段。 */
export interface CreatePersonParams {
  displayName: string;
  avatarBlob?: Uint8Array;
  birthday?: number;
  gender?: GenderEnum;
  remark?: string;
  personType?: PersonTypeEnum;
}

/** 更新人物时可传递的可选字段（全部可选，仅传入需更新的字段）。 */
export interface UpdatePersonParams {
  displayName?: string;
  avatarBlob?: Uint8Array | null;
  birthday?: number | null;
  gender?: GenderEnum | null;
  remark?: string;
  personType?: PersonTypeEnum;
}

/** 更新故事时传递的可选字段（全部可选，仅传入需更新的字段）。 */
export interface UpdateStoryParams {
  title?: string;
  description?: string;
  timeStart?: number | null;
  timeEnd?: number | null;
  coverUri?: string;
  location?: string;
  tags?: string[];
}

/**
 * 人物 / 故事 / 关联 / PhotoOwnerLink 统一数据面（持久化实现见 RepositoryImpl）。
 * features 仅依赖本接口，不依赖 relationalStore。
 */
export interface IAppDataStore {
  listPersons(): PersonModel[];
  createPerson(params: CreatePersonParams): number;
  getPerson(id: number): PersonModel | null;
  updatePerson(id: number, params: UpdatePersonParams): boolean;
  listStories(): StoryModel[];
  createStory(title: string, description?: string, timeStart?: number | null, timeEnd?: number | null, coverUri?: string, location?: string, tags?: string[]): number;
  getStory(id: number): StoryModel | null;
  updateStory(id: number, title: string): boolean;
  updateStoryAll?(id: number, params: UpdateStoryParams): boolean;
  linkedPersonsForStory(storyId: number): PersonModel[];
  linkPersonStory(personId: number, storyId: number): void;
  unlinkPersonStory(personId: number, storyId: number): void;
  linkedStoriesForPerson(personId: number): StoryModel[];
  isPersonStoryLinked(personId: number, storyId: number): boolean;
  photosForPerson(personId: number): PhotoRefModel[];
  addPhotoForPerson(personId: number, uri: string): PhotoAddResult;
  photosForStory(storyId: number): PhotoRefModel[];
  addPhotoForStory(storyId: number, uri: string): PhotoAddResult;
  /** 删除人物：级联清理 person_story + person 侧 photo_owner_link，递减 photo_ref.reference_count（§6.3）。 */
  deletePerson(id: number): boolean;
  /** 删除故事：级联清理 story 侧 photo_owner_link + person_story，递减 photo_ref.reference_count（§6.3）。 */
  deleteStory(id: number): boolean;
}
