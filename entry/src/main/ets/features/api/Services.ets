import type { PersonModel, PhotoAddResult, PhotoRefModel, StoryModel } from '../../domain/model/Models';

/** 人物领域服务（内存实现，见 PersonFeature）。 */
export interface IPersonService {
  listPersons(): PersonModel[];
  createPerson(displayName: string): number;
  getPerson(id: number): PersonModel | null;
  updatePerson(id: number, displayName: string): boolean;
  listLinkedStories(personId: number): StoryModel[];
  linkPersonToStory(personId: number, storyId: number): void;
  unlinkPersonFromStory(personId: number, storyId: number): void;
  isLinked(personId: number, storyId: number): boolean;
  listPersonPhotos(personId: number): PhotoRefModel[];
  addPhotoToPerson(personId: number, uri: string): PhotoAddResult;
}

/** 故事主链（内存实现，见 StoryFeature）；人物关联与 PhotoOwnerLink 与 LocalMemoryStore 对齐。 */
export interface IStoryService {
  listStories(): StoryModel[];
  createStory(title: string): number;
  getStory(id: number): StoryModel | null;
  updateStory(id: number, title: string): boolean;
  listLinkedPersons(storyId: number): PersonModel[];
  linkStoryToPerson(storyId: number, personId: number): void;
  unlinkStoryFromPerson(storyId: number, personId: number): void;
  listStoryPhotos(storyId: number): PhotoRefModel[];
  addPhotoToStory(storyId: number, uri: string): PhotoAddResult;
}

/**
 * 导入向导与 B2 可取消长任务（扫描）协调：会话内单例，供 ImportPage 与验收复核 cancelRequest。
 */
export interface IImportService {
  /** 开始一段可取消的扫描类长任务，返回 requestId（供 cancelRequest）。 */
  beginLongTask(): number;
  /** 应用层取消：仅当 requestId 为当前活动任务时生效。 */
  cancelRequest(requestId: number): boolean;
  /** 扫描循环内轮询：是否已对当前 requestId 发起取消。 */
  isCancelled(requestId: number): boolean;
  /** 正常结束或中止后释放活动槽位，避免脏取消串到下一段。 */
  endLongTask(requestId: number): void;
}

export interface ISuggestionService {}
