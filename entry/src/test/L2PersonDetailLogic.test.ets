/**
 * L2 组件测试 — PersonDetailPage 纯函数逻辑
 *
 * 覆盖：typeLabel / genderLabel / formatBirthday / formatMonthLabel /
 *       parsePersonId / buildMonthGroups / blobToBase64
 */
import { describe, expect, it } from '@ohos/hypium';
import { PersonTypeEnum, GenderEnum } from '../../../main/ets/domain/model/Models';
import type { PhotoRefModel, StoryModel, PhotoMetadata } from '../../../main/ets/domain/model/Models';
import {
  typeLabel, genderLabel, formatBirthday, formatMonthLabel,
  parsePersonId, buildMonthGroups, blobToBase64
} from '../../../main/ets/pages/person/PersonDetailLogic';

export default function l2PersonDetailLogic(): void {
  describe('L2_personDetailLogic', () => {
    // ── parsePersonId ──
    it('L2_personDetail_parsePersonId_number', 0, (): void => {
      expect(parsePersonId({ personId: 42 })).assertEqual(42);
    });
    it('L2_personDetail_parsePersonId_string', 0, (): void => {
      expect(parsePersonId({ personId: '99' })).assertEqual(99);
    });
    it('L2_personDetail_parsePersonId_invalid_string', 0, (): void => {
      expect(parsePersonId({ personId: 'abc' })).assertEqual(0);
    });
    it('L2_personDetail_parsePersonId_missing', 0, (): void => {
      expect(parsePersonId({})).assertEqual(0);
    });

    // ── typeLabel ──
    it('L2_personDetail_typeLabel_baby', 0, (): void => {
      expect(typeLabel(PersonTypeEnum.BABY)).assertEqual('宝宝');
    });
    it('L2_personDetail_typeLabel_adult', 0, (): void => {
      expect(typeLabel(PersonTypeEnum.ADULT)).assertEqual('成人');
    });
    it('L2_personDetail_typeLabel_elder', 0, (): void => {
      expect(typeLabel(PersonTypeEnum.ELDER)).assertEqual('长辈');
    });
    it('L2_personDetail_typeLabel_other', 0, (): void => {
      expect(typeLabel(PersonTypeEnum.OTHER)).assertEqual('其他');
    });

    // ── genderLabel ──
    it('L2_personDetail_genderLabel_null', 0, (): void => {
      expect(genderLabel(null)).assertEqual('未填');
    });
    it('L2_personDetail_genderLabel_unspecified', 0, (): void => {
      expect(genderLabel(GenderEnum.UNSPECIFIED)).assertEqual('未填');
    });
    it('L2_personDetail_genderLabel_male', 0, (): void => {
      expect(genderLabel(GenderEnum.MALE)).assertEqual('男');
    });
    it('L2_personDetail_genderLabel_female', 0, (): void => {
      expect(genderLabel(GenderEnum.FEMALE)).assertEqual('女');
    });

    // ── formatBirthday ──
    it('L2_personDetail_formatBirthday_null', 0, (): void => {
      expect(formatBirthday(null)).assertEqual('未设置');
    });
    it('L2_personDetail_formatBirthday_zero', 0, (): void => {
      expect(formatBirthday(0)).assertEqual('未设置');
    });
    it('L2_personDetail_formatBirthday_valid', 0, (): void => {
      const ts = new Date(1990, 0, 15).getTime();
      expect(formatBirthday(ts)).assertEqual('1990-01-15');
    });
    it('L2_personDetail_formatBirthday_padding', 0, (): void => {
      const ts = new Date(2024, 2, 3).getTime();
      expect(formatBirthday(ts)).assertEqual('2024-03-03');
    });

    // ── formatMonthLabel ──
    it('L2_personDetail_formatMonthLabel_jan', 0, (): void => {
      expect(formatMonthLabel(2026, 0)).assertEqual('2026年1月');
    });
    it('L2_personDetail_formatMonthLabel_dec', 0, (): void => {
      expect(formatMonthLabel(2025, 11)).assertEqual('2025年12月');
    });

    // ── buildMonthGroups ──
    it('L2_personDetail_buildMonthGroups_empty_photos_and_stories', 0, (): void => {
      const groups = buildMonthGroups([], [], () => []);
      expect(groups.length).assertEqual(0);
    });

    it('L2_personDetail_buildMonthGroups_single_photo', 0, (): void => {
      const photo: PhotoRefModel = {
        id: 1, uri: 'file://photo1.jpg', addedAt: 1000,
        refStatus: 1, referenceCount: 1, isReferenced: true,
        metadata: { takenAt: new Date(2026, 5, 15).getTime() }
      };
      const groups = buildMonthGroups([photo], [], () => []);
      expect(groups.length).assertEqual(1);
      expect(groups[0].year).assertEqual(2026);
      expect(groups[0].month).assertEqual(5);
      expect(groups[0].items.length).assertEqual(1);
      expect(groups[0].items[0].kind).assertEqual('photo');
    });

    it('L2_personDetail_buildMonthGroups_single_story', 0, (): void => {
      const story: StoryModel = {
        id: 10, title: 'Trip', description: '', photoCount: 3,
        timeStart: new Date(2026, 5, 10).getTime(), timeEnd: null,
        coverUri: '', location: '', tags: [], createdAt: 0, updatedAt: 0
      };
      const storyPhoto: PhotoRefModel = {
        id: 100, uri: 'file://story-photo.jpg', addedAt: 2000,
        refStatus: 1, referenceCount: 1, isReferenced: true,
        metadata: { takenAt: new Date(2026, 5, 10).getTime() }
      };
      const groups = buildMonthGroups([], [story], (sid: number): PhotoRefModel[] => {
        expect(sid).assertEqual(10);
        return [storyPhoto];
      });
      expect(groups.length).assertEqual(1);
      expect(groups[0].items.length).assertEqual(1);
      expect(groups[0].items[0].kind).assertEqual('story');
      expect(groups[0].items[0].story?.id).assertEqual(10);
      expect(groups[0].items[0].coverPhoto?.id).assertEqual(100);
    });

    it('L2_personDetail_buildMonthGroups_story_no_timeStart_skipped', 0, (): void => {
      const story: StoryModel = {
        id: 10, title: 'NoDate', description: '', photoCount: 0,
        timeStart: null, timeEnd: null, coverUri: '', location: '',
        tags: [], createdAt: 0, updatedAt: 0
      };
      const groups = buildMonthGroups([], [story], () => []);
      expect(groups.length).assertEqual(0);
    });

    it('L2_personDetail_buildMonthGroups_photo_and_story_same_month', 0, (): void => {
      const ts = new Date(2026, 3, 1).getTime();
      const photo: PhotoRefModel = {
        id: 1, uri: 'file://p1.jpg', addedAt: 1000,
        refStatus: 1, referenceCount: 1, isReferenced: true,
        metadata: { takenAt: ts }
      };
      const story: StoryModel = {
        id: 5, title: 'Story', description: '', photoCount: 1,
        timeStart: ts, timeEnd: null, coverUri: '', location: '',
        tags: [], createdAt: 0, updatedAt: 0
      };
      const groups = buildMonthGroups([photo], [story], () => []);
      expect(groups.length).assertEqual(1);
      expect(groups[0].items.length).assertEqual(2);
      expect(groups[0].items[0].kind).assertEqual('story');
      expect(groups[0].items[1].kind).assertEqual('photo');
    });

    it('L2_personDetail_buildMonthGroups_multi_month_descending', 0, (): void => {
      const mayTs = new Date(2026, 4, 1).getTime();
      const aprTs = new Date(2026, 3, 1).getTime();
      const photoMay: PhotoRefModel = {
        id: 1, uri: 'file://may.jpg', addedAt: 1000,
        refStatus: 1, referenceCount: 1, isReferenced: true,
        metadata: { takenAt: mayTs }
      };
      const photoApr: PhotoRefModel = {
        id: 2, uri: 'file://apr.jpg', addedAt: 2000,
        refStatus: 1, referenceCount: 1, isReferenced: true,
        metadata: { takenAt: aprTs }
      };
      const groups = buildMonthGroups([photoMay, photoApr], [], () => []);
      expect(groups.length).assertEqual(2);
      expect(groups[0].month).assertEqual(4); // May first
      expect(groups[1].month).assertEqual(3); // Apr second
    });

    it('L2_personDetail_buildMonthGroups_coverUri_from_photos', 0, (): void => {
      const coverPhoto: PhotoRefModel = {
        id: 99, uri: 'file://cover.jpg', addedAt: 1000,
        refStatus: 1, referenceCount: 1, isReferenced: true,
        metadata: { takenAt: new Date(2026, 6, 1).getTime() }
      };
      const story: StoryModel = {
        id: 5, title: 'CoverTest', description: '', photoCount: 3,
        timeStart: new Date(2026, 6, 1).getTime(), timeEnd: null,
        coverUri: 'file://cover.jpg', location: '', tags: [],
        createdAt: 0, updatedAt: 0
      };
      const groups = buildMonthGroups([coverPhoto], [story], () => []);
      expect(groups.length).assertEqual(1);
      expect(groups[0].items[0].coverPhoto?.id).assertEqual(99);
    });

    // ── blobToBase64 ──
    it('L2_personDetail_blobToBase64_empty', 0, (): void => {
      expect(blobToBase64(new Uint8Array(0))).assertEqual('');
    });
    it('L2_personDetail_blobToBase64_data', 0, (): void => {
      const result = blobToBase64(new Uint8Array([72, 101, 108, 108, 111]));
      expect(result === '').assertFalse();
    });
  });
}