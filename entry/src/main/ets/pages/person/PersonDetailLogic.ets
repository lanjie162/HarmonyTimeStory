/**
 * PersonDetailPage 纯函数逻辑层（L2 组件测试目标）。
 * 从 PersonDetailPage.ets 剥离，不依赖 @State / @Component 生命周期。
 */
import type { GenderEnum, PersonModel, PersonTypeEnum, PhotoMetadata, PhotoRefModel, StoryModel } from '../../domain/model/Models';
import { PersonTypeEnum as PT } from '../../domain/model/Models';
import { GenderEnum as GE } from '../../domain/model/Models';

export function parsePersonId(params: Record<string, Object>): number {
  const raw = params['personId'];
  if (typeof raw === 'number') {
    return raw as number;
  }
  if (typeof raw === 'string') {
    const n = Number.parseInt(raw as string, 10);
    return Number.isNaN(n) ? 0 : n;
  }
  return 0;
}

export function typeLabel(val: PersonTypeEnum): string {
  if (val === PT.BABY) {
    return '宝宝';
  }
  if (val === PT.ADULT) {
    return '成人';
  }
  if (val === PT.ELDER) {
    return '长辈';
  }
  return '其他';
}

export function genderLabel(val: GenderEnum | null): string {
  if (val === null || val === GE.UNSPECIFIED) {
    return '未填';
  }
  if (val === GE.MALE) {
    return '男';
  }
  return '女';
}

export function formatBirthday(ts: number | null): string {
  if (ts === null || ts <= 0) {
    return '未设置';
  }
  const date = new Date(ts);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function formatMonthLabel(year: number, month: number): string {
  return `${year}年${month + 1}月`;
}

export type TimelineItemKind = 'photo' | 'story';

export interface TimelineItem {
  kind: TimelineItemKind;
  photo?: PhotoRefModel;
  story?: StoryModel;
  coverPhoto?: PhotoRefModel;
}

export interface StoryStat {
  title: string;
  count: number;
}

export interface MonthGroup {
  year: number;
  month: number;
  items: TimelineItem[];
  storyStats: Map<number, StoryStat>;
}

export type ListStoryPhotosFn = (storyId: number) => PhotoRefModel[];

export function buildMonthGroups(
  photos: PhotoRefModel[],
  linkedStories: StoryModel[],
  listStoryPhotosFn: ListStoryPhotosFn
): MonthGroup[] {
  const groups: MonthGroup[] = [];
  const map = new Map<string, MonthGroup>();

  for (const ph of photos) {
    const ts: number = ph.metadata?.takenAt ?? 0;
    const d = new Date(ts);
    const y = d.getFullYear();
    const m = d.getMonth();
    const key = `${y}-${m}`;
    let g = map.get(key);
    if (!g) {
      g = { year: y, month: m, items: [], storyStats: new Map() };
      map.set(key, g);
      groups.push(g);
    }
    g.items.push({ kind: 'photo', photo: ph });
  }

  for (const s of linkedStories) {
    const ts: number = s.timeStart ?? 0;
    if (ts <= 0) {
      continue;
    }
    const d = new Date(ts);
    const y = d.getFullYear();
    const m = d.getMonth();
    const key = `${y}-${m}`;
    let g = map.get(key);
    if (!g) {
      g = { year: y, month: m, items: [], storyStats: new Map() };
      map.set(key, g);
      groups.push(g);
    }

    let coverPhoto: PhotoRefModel | undefined;

    if (s.coverUri && s.coverUri.length > 0) {
      coverPhoto = photos.find(ph => ph.uri === s.coverUri);
    }

    if (!coverPhoto && s.photoCount > 0) {
      const storyPhotos = listStoryPhotosFn(s.id);
      if (storyPhotos.length > 0) {
        coverPhoto = storyPhotos[0];
      }
    }

    g.items.push({ kind: 'story', story: s, coverPhoto });

    g.storyStats.set(s.id, { title: s.title, count: s.photoCount });
  }

  for (const g of groups) {
    g.items.sort((a, b) => {
      const tsA: number = a.kind === 'photo' ? (a.photo?.metadata?.takenAt ?? 0) : (a.story?.timeStart ?? 0);
      const tsB: number = b.kind === 'photo' ? (b.photo?.metadata?.takenAt ?? 0) : (b.story?.timeStart ?? 0);
      return tsB - tsA;
    });
  }

  groups.sort((a, b) => {
    if (a.year !== b.year) {
      return b.year - a.year;
    }
    return b.month - a.month;
  });

  return groups;
}

export function blobToBase64(blob: Uint8Array): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  let result = '';
  const bytes = blob;
  for (let i = 0; i < bytes.byteLength; i += 3) {
    const b0 = bytes[i];
    const b1 = i + 1 < bytes.byteLength ? bytes[i + 1] : 0;
    const b2 = i + 2 < bytes.byteLength ? bytes[i + 2] : 0;
    result += chars.charAt(b0 >> 2);
    result += chars.charAt(((b0 & 3) << 4) | (b1 >> 4));
    result += i + 1 < bytes.byteLength ? chars.charAt(((b1 & 15) << 2) | (b2 >> 6)) : '=';
    result += i + 2 < bytes.byteLength ? chars.charAt(b2 & 63) : '=';
  }
  return result;
}