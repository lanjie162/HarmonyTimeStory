/**
 * StoryDetailPage 纯函数逻辑层（L2 组件测试目标）。
 * 从 StoryDetailPage.ets 剥离，不依赖 @State / @Component 生命周期。
 */
import type { StoryModel } from '../../domain/model/Models';

export function parseStoryId(params: Record<string, Object>): number {
  const raw = params['storyId'];
  if (typeof raw === 'number') {
    return raw as number;
  }
  if (typeof raw === 'string') {
    const n = Number.parseInt(raw as string, 10);
    return Number.isNaN(n) ? 0 : n;
  }
  return 0;
}

export function formatDate(ts: number | null): string {
  if (ts === null || ts <= 0) {
    return '未设置';
  }
  const d = new Date(ts);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

export function buildDateRangeText(timeStart: number | null, timeEnd: number | null): string {
  const start = formatDate(timeStart);
  const end = formatDate(timeEnd);
  if (start === '未设置' && end === '未设置') {
    return '';
  }
  if (start === end) {
    return start;
  }
  return `${start} ~ ${end}`;
}

export function buildMetaInfoText(dateRange: string, location: string | null | undefined): string {
  const loc = location ?? '';
  if (dateRange && loc) {
    return `${dateRange}  ·  ${loc}`;
  }
  return dateRange || loc;
}

export function getDisplayTags(tags: string[] | null | undefined): string[] {
  if (!tags || tags.length === 0) {
    return [];
  }
  return tags.slice(0, 3);
}

export function getExtraTagCount(tags: string[] | null | undefined): number {
  if (!tags) {
    return 0;
  }
  return Math.max(0, tags.length - 3);
}