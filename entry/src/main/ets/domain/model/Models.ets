export interface PersonModel {
  id: number;
  displayName: string;
}

/** 最小故事条目，供人物详情「关联故事」与故事主链对齐。 */
export interface StoryModel {
  id: number;
  title: string;
}

/** 人物挂载的照片引用最小字段（PH-01 去重用 uri）。 */
export interface PhotoRefModel {
  id: number;
  uri: string;
}

export interface PhotoAddResult {
  success: boolean;
  duplicate: boolean;
}
