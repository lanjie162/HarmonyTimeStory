import { afterAll, beforeAll, describe, expect, it } from '@ohos/hypium';
import type { IStoryService } from '../../../main/ets/features/api/Services';
import { StoryService } from '../../../main/ets/features/story/StoryFeature';
import { ServiceTestContext } from './utils/ServiceTestContext';
import { TestDataFactory } from './utils/TestDataFactory';
import { relationalStore } from '@kit.ArkData';

export default function l3StoryService(): void {
  describe('L3_storyService', () => {
    const ctx = new ServiceTestContext<IStoryService>((repo) => new StoryService(repo));

    beforeAll(async () => {
      await ctx.setup();
    });

    afterAll(async () => {
      await ctx.teardown();
    });

    it('L3_storyService_createStory_success', 0, (): void => {
      const svc = ctx.getService();
      const id = svc.createStory(TestDataFactory.createStoryTitle());
      expect(id > 0).assertTrue();
    });

    it('L3_storyService_createStory_rejects_blank', 0, (): void => {
      const svc = ctx.getService();
      expect(svc.createStory('')).assertEqual(-1);
      expect(svc.createStory('  \n')).assertEqual(-1);
    });

    it('L3_storyService_createStory_trims_title', 0, (): void => {
      const svc = ctx.getService();
      const id = svc.createStory('  My Story  ');
      expect(id > 0).assertTrue();
      const s = svc.getStory(id);
      expect(s !== null).assertTrue();
      expect(s!.title).assertEqual('My Story');
    });

    it('L3_storyService_createStory_with_all_fields', 0, (): void => {
      const svc = ctx.getService();
      const repo = ctx.getRepo();
      const now = Date.now();
      const id = repo.createStory(
        TestDataFactory.createStoryTitle(),
        'desc text',
        now,
        now + 86400000,
        'file://cover',
        'Beijing',
        ['tag1', 'tag2']
      );
      expect(id > 0).assertTrue();
      const s = svc.getStory(id);
      expect(s !== null).assertTrue();
      expect(s!.description).assertEqual('desc text');
      expect(s!.timeStart).assertEqual(now);
      expect(s!.timeEnd).assertEqual(now + 86400000);
      expect(s!.coverUri).assertEqual('file://cover');
      expect(s!.location).assertEqual('Beijing');
      expect(s!.tags.length).assertEqual(2);
      expect(s!.tags[0]).assertEqual('tag1');
      expect(s!.tags[1]).assertEqual('tag2');
    });

    it('L3_storyService_createStory_defaults', 0, (): void => {
      const svc = ctx.getService();
      const id = svc.createStory(TestDataFactory.createStoryTitle());
      expect(id > 0).assertTrue();
      const s = svc.getStory(id);
      expect(s !== null).assertTrue();
      expect(s!.description).assertEqual('');
      expect(s!.timeStart === null).assertTrue();
      expect(s!.timeEnd === null).assertTrue();
      expect(s!.coverUri).assertEqual('');
      expect(s!.location).assertEqual('');
      expect(s!.tags.length).assertEqual(0);
      expect(s!.photoCount).assertEqual(0);
    });

    it('L3_storyService_getStory_exists', 0, (): void => {
      const svc = ctx.getService();
      const title = TestDataFactory.createStoryTitle();
      const id = svc.createStory(title);
      const s = svc.getStory(id);
      expect(s !== null).assertTrue();
      expect(s!.id).assertEqual(id);
      expect(s!.title).assertEqual(title);
    });

    it('L3_storyService_getStory_missing', 0, (): void => {
      const svc = ctx.getService();
      expect(svc.getStory(999999999) === null).assertTrue();
    });

    it('L3_storyService_listStories_newest_first', 0, async (): Promise<void> => {
      const svc = ctx.getService();
      const idA = svc.createStory(TestDataFactory.createStoryTitle());
      await new Promise<void>((r) => setTimeout(r, 15));
      const idB = svc.createStory(TestDataFactory.createStoryTitle());
      expect(idA > 0 && idB > 0).assertTrue();
      const list = svc.listStories();
      const found = list.filter((s) => s.id === idA || s.id === idB);
      expect(found.length >= 2).assertTrue();
      expect(found[0].id).assertEqual(idB);
    });

    it('L3_storyService_listStories_empty', 0, (): void => {
      const svc = ctx.getService();
      const list = svc.listStories();
      expect(Array.isArray(list)).assertTrue();
    });

    it('L3_storyService_updateStory_success', 0, (): void => {
      const svc = ctx.getService();
      const id = svc.createStory(TestDataFactory.createStoryTitle());
      const newTitle = TestDataFactory.createStoryTitle();
      expect(svc.updateStory(id, newTitle)).assertTrue();
      expect(svc.getStory(id)!.title).assertEqual(newTitle);
    });

    it('L3_storyService_updateStory_rejects_blank', 0, (): void => {
      const svc = ctx.getService();
      const id = svc.createStory(TestDataFactory.createStoryTitle());
      expect(svc.updateStory(id, '  ')).assertFalse();
    });

    it('L3_storyService_updateStoryAll_full_fields', 0, (): void => {
      const svc = ctx.getService();
      const id = svc.createStory(TestDataFactory.createStoryTitle());
      const now = Date.now();
      const newTitle = TestDataFactory.createStoryTitle();
      expect(svc.updateStoryAll!(id, newTitle, 'new desc', now, now + 3600000, 'file://new-cover', 'Shanghai', ['travel', '2026'])).assertTrue();
      const s = svc.getStory(id);
      expect(s!.title).assertEqual(newTitle);
      expect(s!.description).assertEqual('new desc');
      expect(s!.timeStart).assertEqual(now);
      expect(s!.location).assertEqual('Shanghai');
      expect(s!.tags.length).assertEqual(2);
    });

    it('L3_storyService_updateStoryAll_tags_roundtrip', 0, (): void => {
      const svc = ctx.getService();
      const id = svc.createStory(TestDataFactory.createStoryTitle());
      expect(svc.updateStoryAll!(id, TestDataFactory.createStoryTitle(), '', null, null, '', '', ['a', 'b', 'c'])).assertTrue();
      let s = svc.getStory(id);
      expect(s!.tags.length).assertEqual(3);
      expect(svc.updateStoryAll!(id, TestDataFactory.createStoryTitle(), '', null, null, '', '', ['x', 'y'])).assertTrue();
      s = svc.getStory(id);
      expect(s!.tags.length).assertEqual(2);
      expect(svc.updateStoryAll!(id, TestDataFactory.createStoryTitle(), '', null, null, '', '', [])).assertTrue();
      s = svc.getStory(id);
      expect(s!.tags.length).assertEqual(0);
    });

    it('L3_storyService_updateStoryAll_partial_update', 0, (): void => {
      const svc = ctx.getService();
      const id = svc.createStory(TestDataFactory.createStoryTitle());
      const title = svc.getStory(id)!.title;
      expect(svc.updateStoryAll!(id, title, 'partial desc')).assertTrue();
      const s = svc.getStory(id);
      expect(s!.description).assertEqual('partial desc');
      expect(s!.title).assertEqual(title);
    });

    it('L3_storyService_updateStory_nonexistent_id', 0, (): void => {
      const svc = ctx.getService();
      const result = svc.updateStory(999999999, 'Ghost');
      expect(result).assertFalse();
    });

    it('L3_storyService_deleteStory_success', 0, (): void => {
      const svc = ctx.getService();
      const id = svc.createStory(TestDataFactory.createStoryTitle());
      expect(id > 0).assertTrue();
      expect(svc.deleteStory(id)).assertTrue();
      expect(svc.getStory(id) === null).assertTrue();
    });

    it('L3_storyService_deleteStory_cascade', 0, (): void => {
      const svc = ctx.getService();
      const repo = ctx.getRepo();
      const pid = repo.createPerson(TestDataFactory.createPersonParams());
      const sid = svc.createStory(TestDataFactory.createStoryTitle());
      svc.linkStoryToPerson(sid, pid);
      svc.addPhotoToStory(sid, TestDataFactory.createPhotoUri());
      expect(svc.deleteStory(sid)).assertTrue();
      expect(svc.getStory(sid) === null).assertTrue();
      expect(svc.listLinkedPersons(sid).length).assertEqual(0);
      expect(svc.listStoryPhotos(sid).length).assertEqual(0);
    });

    it('L3_storyService_deleteStory_nonexistent', 0, (): void => {
      const svc = ctx.getService();
      expect(svc.deleteStory(999999999)).assertFalse();
    });

    it('L3_storyService_linkStoryToPerson', 0, (): void => {
      const svc = ctx.getService();
      const repo = ctx.getRepo();
      const pid = repo.createPerson(TestDataFactory.createPersonParams());
      const sid = svc.createStory(TestDataFactory.createStoryTitle());
      svc.linkStoryToPerson(sid, pid);
      const persons = svc.listLinkedPersons(sid);
      expect(persons.length).assertEqual(1);
      expect(persons[0].id).assertEqual(pid);
    });

    it('L3_storyService_unlinkStoryFromPerson', 0, (): void => {
      const svc = ctx.getService();
      const repo = ctx.getRepo();
      const pid = repo.createPerson(TestDataFactory.createPersonParams());
      const sid = svc.createStory(TestDataFactory.createStoryTitle());
      svc.linkStoryToPerson(sid, pid);
      svc.unlinkStoryFromPerson(sid, pid);
      expect(svc.listLinkedPersons(sid).length).assertEqual(0);
    });

    it('L3_storyService_listLinkedPersons', 0, (): void => {
      const svc = ctx.getService();
      const repo = ctx.getRepo();
      const sid = svc.createStory(TestDataFactory.createStoryTitle());
      const p1 = repo.createPerson(TestDataFactory.createPersonParams());
      const p2 = repo.createPerson(TestDataFactory.createPersonParams());
      svc.linkStoryToPerson(sid, p1);
      svc.linkStoryToPerson(sid, p2);
      expect(svc.listLinkedPersons(sid).length).assertEqual(2);
    });

    it('L3_storyService_addPhotoToStory_success', 0, (): void => {
      const svc = ctx.getService();
      const sid = svc.createStory(TestDataFactory.createStoryTitle());
      const uri = TestDataFactory.createPhotoUri();
      const res = svc.addPhotoToStory(sid, uri);
      expect(res.success).assertTrue();
      expect(res.duplicate).assertFalse();
      const photos = svc.listStoryPhotos(sid);
      expect(photos.length).assertEqual(1);
      expect(photos[0].uri).assertEqual(uri);
    });

    it('L3_storyService_addPhotoToStory_duplicate', 0, (): void => {
      const svc = ctx.getService();
      const sid = svc.createStory(TestDataFactory.createStoryTitle());
      const uri = TestDataFactory.createPhotoUri();
      expect(svc.addPhotoToStory(sid, uri).success).assertTrue();
      const dup = svc.addPhotoToStory(sid, uri);
      expect(dup.success).assertFalse();
      expect(dup.duplicate).assertTrue();
    });

    it('L3_storyService_addPhotoToStory_with_metadata', 0, (): void => {
      const svc = ctx.getService();
      const sid = svc.createStory(TestDataFactory.createStoryTitle());
      const uri = TestDataFactory.createPhotoUri();
      const takenAt = 1700000000000;
      expect(svc.addPhotoToStory(sid, uri, { takenAt }).success).assertTrue();
      const photos = svc.listStoryPhotos(sid);
      expect(photos.length).assertEqual(1);
      expect(photos[0].metadata !== undefined).assertTrue();
      expect(photos[0].metadata!.takenAt).assertEqual(takenAt);
    });

    it('L3_storyService_addPhotoToStory_cap_1000', 0, (): void => {
      const svc = ctx.getService();
      const sid = svc.createStory(TestDataFactory.createStoryTitle());
      expect(sid > 0).assertTrue();
      const store = ctx.getStore();
      for (let i = 0; i < 1000; i++) {
        const uri = `file://test/cap-batch-${i}`;
        const prVb: relationalStore.ValuesBucket = {
          uri: uri,
          added_at: Date.now(),
          ref_status: 1,
          reference_count: 1,
          is_referenced: 1
        };
        const prId = store.insertSync('photo_ref', prVb, relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
        if (prId > 0) {
          const linkVb: relationalStore.ValuesBucket = {
            owner_kind: 1,
            owner_id: sid,
            photo_ref_id: prId,
            linked_at: Date.now() + i,
            sort_key: Date.now() + i
          };
          store.insertSync('photo_owner_link', linkVb, relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
        }
      }
      const res = svc.addPhotoToStory(sid, 'file://test/cap-1001');
      expect(res.success).assertFalse();
      expect(res.duplicate).assertFalse();
    });

    it('L3_storyService_removePhotoFromStory', 0, (): void => {
      const svc = ctx.getService();
      const sid = svc.createStory(TestDataFactory.createStoryTitle());
      const uri = TestDataFactory.createPhotoUri();
      svc.addPhotoToStory(sid, uri);
      const photos = svc.listStoryPhotos(sid);
      expect(photos.length).assertEqual(1);
      expect(svc.removePhotoFromStory(sid, photos[0].id)).assertTrue();
      expect(svc.listStoryPhotos(sid).length).assertEqual(0);
    });

    it('L3_storyService_gcOrphanPhotoRefs', 0, (): void => {
      const svc = ctx.getService();
      const sid = svc.createStory(TestDataFactory.createStoryTitle());
      const uri = TestDataFactory.createPhotoUri();
      svc.addPhotoToStory(sid, uri);
      const photos = svc.listStoryPhotos(sid);
      svc.removePhotoFromStory(sid, photos[0].id);
      const n = svc.gcOrphanPhotoRefs();
      expect(n >= 1).assertTrue();
    });
  });
}
