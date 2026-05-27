/** 性别枚举：与 MVP §6.1 / UI 原型 §4.2 对齐。 */
export enum GenderEnum {
  /** 男 */
  MALE = 0,
  /** 女 */
  FEMALE = 1,
  /** 未填 */
  UNSPECIFIED = 2
}

/** 人物类型枚举：与 MVP §6.1 / UI 原型 §4.2 对齐。 */
export enum PersonTypeEnum {
  /** 宝宝 */
  BABY = 0,
  /** 成人 */
  ADULT = 1,
  /** 长辈 */
  ELDER = 2,
  /** 其他（默认） */
  OTHER = 3
}

export interface PersonModel {
  id: number;
  displayName: string;
  /** 头像 BLOB 数据（base64 编码后 JSON 传输用），DB 存原始 BLOB。 */
  avatarBlob: Uint8Array | null;
  /** 生日时间戳（毫秒），null 表示未设置。 */
  birthday: number | null;
  /** 性别枚举值，null 表示未设置。 */
  gender: GenderEnum | null;
  /** 备注文本。 */
  remark: string;
  /** 人物类型枚举。 */
  personType: PersonTypeEnum;
  /** 更新时间戳（毫秒），由 RDB updated_at 列映射。 */
  updatedAt: number;
}

/** 故事主数据：与 MVP §6.1 Story 字段表对齐。 */
export interface StoryModel {
  id: number;
  title: string;
  /** 描述文本（可选，默认空字符串） */
  description: string;
  /** 时间范围：开始时间戳（毫秒），null 表示未设置 */
  timeStart: number | null;
  /** 时间范围：结束时间戳（毫秒），null 表示未设置；单日时 timeStart === timeEnd */
  timeEnd: number | null;
  /** 封面 URI（可选，指向 PhotoRef URI，默认为空字符串） */
  coverUri: string;
  /** 地点（可选，默认空字符串） */
  location: string;
  /** 自定义标签（JSON 数组，序列化为 string[]，默认空数组） */
  tags: string[];
}

/** URI 健康状态枚举：与 photo_ref.ref_status 列对齐。 */
export enum UriHealthStatus {
  /** 初始状态：尚未检测 */
  UNKNOWN = 0,
  /** URI 可正常加载 */
  HEALTHY = 1,
  /** 本地文件已被删除 */
  LOCAL_DELETED = 2,
  /** 云端不可访问 */
  CLOUD_INACCESSIBLE = 3
}

/** 人物挂载的照片引用最小字段（PH-01 去重用 uri）。 */
export interface PhotoRefModel {
  id: number;
  uri: string;
  /** URI 健康状态，默认 UNKNOWN(0)；写入时由 resolveOrCreatePhotoRef 设为 HEALTHY(1)。 */
  refStatus: number;
}

export interface PhotoAddResult {
  success: boolean;
  duplicate: boolean;
}
