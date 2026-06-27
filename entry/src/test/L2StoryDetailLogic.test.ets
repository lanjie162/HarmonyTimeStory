/**
 * L2 组件测试 — StoryDetailPage 纯函数逻辑
 *
 * 覆盖：parseStoryId / formatDate / buildDateRangeText /
 *       buildMetaInfoText / getDisplayTags / getExtraTagCount
 */
import { describe, expect, it } from '@ohos/hypium';
import {
  parseStoryId, formatDate, buildDateRangeText,
  buildMetaInfoText, getDisplayTags, getExtraTagCount
} from '../../../main/ets/pages/story/StoryDetailLogic';

export default function l2StoryDetailLogic(): void {
  describe('L2_storyDetailLogic', () => {
    // ── parseStoryId ──
    it('L2_storyDetail_parseStoryId_number', 0, (): void => {
      expect(parseStoryId({ storyId: 42 })).assertEqual(42);
    });
    it('L2_storyDetail_parseStoryId_string', 0, (): void => {
      expect(parseStoryId({ storyId: '99' })).assertEqual(99);
    });
    it('L2_storyDetail_parseStoryId_invalid', 0, (): void => {
      expect(parseStoryId({ storyId: 'xyz' })).assertEqual(0);
    });
    it('L2_storyDetail_parseStoryId_missing', 0, (): void => {
      expect(parseStoryId({})).assertEqual(0);
    });

    // ── formatDate ──
    it('L2_storyDetail_formatDate_null', 0, (): void => {
      expect(formatDate(null)).assertEqual('未设置');
    });
    it('L2_storyDetail_formatDate_zero', 0, (): void => {
      expect(formatDate(0)).assertEqual('未设置');
    });
    it('L2_storyDetail_formatDate_valid', 0, (): void => {
      const ts = new Date(2026, 0, 1).getTime();
      expect(formatDate(ts)).assertEqual('2026-01-01');
    });
    it('L2_storyDetail_formatDate_padding', 0, (): void => {
      const ts = new Date(2024, 11, 5).getTime();
      expect(formatDate(ts)).assertEqual('2024-12-05');
    });

    // ── buildDateRangeText ──
    it('L2_storyDetail_buildDateRangeText_both_null', 0, (): void => {
      expect(buildDateRangeText(null, null)).assertEqual('');
    });
    it('L2_storyDetail_buildDateRangeText_same_day', 0, (): void => {
      const ts = new Date(2026, 5, 15).getTime();
      expect(buildDateRangeText(ts, ts)).assertEqual('2026-06-15');
    });
    it('L2_storyDetail_buildDateRangeText_range', 0, (): void => {
      const start = new Date(2026, 5, 1).getTime();
      const end = new Date(2026, 5, 10).getTime();
      expect(buildDateRangeText(start, end)).assertEqual('2026-06-01 ~ 2026-06-10');
    });
    it('L2_storyDetail_buildDateRangeText_only_start', 0, (): void => {
      const start = new Date(2026, 3, 5).getTime();
      expect(buildDateRangeText(start, null)).assertEqual('2026-04-05 ~ 未设置');
    });

    // ── buildMetaInfoText ──
    it('L2_storyDetail_buildMetaInfoText_date_and_location', 0, (): void => {
      const result = buildMetaInfoText('2026-06-01 ~ 2026-06-10', 'Beijing');
      expect(result).assertEqual('2026-06-01 ~ 2026-06-10  ·  Beijing');
    });
    it('L2_storyDetail_buildMetaInfoText_date_only', 0, (): void => {
      expect(buildMetaInfoText('2026-06-01', '')).assertEqual('2026-06-01');
    });
    it('L2_storyDetail_buildMetaInfoText_location_only', 0, (): void => {
      expect(buildMetaInfoText('', 'Shanghai')).assertEqual('Shanghai');
    });
    it('L2_storyDetail_buildMetaInfoText_neither', 0, (): void => {
      expect(buildMetaInfoText('', '')).assertEqual('');
    });
    it('L2_storyDetail_buildMetaInfoText_with_location_null', 0, (): void => {
      expect(buildMetaInfoText('2026-06-01', null)).assertEqual('2026-06-01');
    });

    // ── getDisplayTags ──
    it('L2_storyDetail_getDisplayTags_null', 0, (): void => {
      expect(getDisplayTags(null).length).assertEqual(0);
    });
    it('L2_storyDetail_getDisplayTags_undefined', 0, (): void => {
      expect(getDisplayTags(undefined).length).assertEqual(0);
    });
    it('L2_storyDetail_getDisplayTags_empty', 0, (): void => {
      expect(getDisplayTags([]).length).assertEqual(0);
    });
    it('L2_storyDetail_getDisplayTags_one', 0, (): void => {
      const tags = getDisplayTags(['travel']);
      expect(tags.length).assertEqual(1);
      expect(tags[0]).assertEqual('travel');
    });
    it('L2_storyDetail_getDisplayTags_three', 0, (): void => {
      const tags = getDisplayTags(['a', 'b', 'c']);
      expect(tags.length).assertEqual(3);
    });
    it('L2_storyDetail_getDisplayTags_extra_sliced', 0, (): void => {
      const tags = getDisplayTags(['a', 'b', 'c', 'd', 'e']);
      expect(tags.length).assertEqual(3);
    });

    // ── getExtraTagCount ──
    it('L2_storyDetail_getExtraTagCount_null', 0, (): void => {
      expect(getExtraTagCount(null)).assertEqual(0);
    });
    it('L2_storyDetail_getExtraTagCount_undefined', 0, (): void => {
      expect(getExtraTagCount(undefined)).assertEqual(0);
    });
    it('L2_storyDetail_getExtraTagCount_two', 0, (): void => {
      expect(getExtraTagCount(['a', 'b'])).assertEqual(0);
    });
    it('L2_storyDetail_getExtraTagCount_exact_three', 0, (): void => {
      expect(getExtraTagCount(['a', 'b', 'c'])).assertEqual(0);
    });
    it('L2_storyDetail_getExtraTagCount_five', 0, (): void => {
      expect(getExtraTagCount(['a', 'b', 'c', 'd', 'e'])).assertEqual(2);
    });
  });
}