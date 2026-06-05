import { afterAll, beforeAll, describe, expect, it } from '@ohos/hypium';
import type { IPersonService } from '../../../main/ets/features/api/Services';
import type { IStoryService } from '../../../main/ets/features/api/Services';
import { PersonService } from '../../../main/ets/features/person/PersonFeature';
import { StoryService } from '../../../main/ets/features/story/StoryFeature';
import { ServiceTestContext } from './utils/ServiceTestContext';
import { TestDataFactory } from './utils/TestDataFactory';
import { relationalStore } from '@kit.ArkData';

class LinkPhotoTestContext {
  personCtx: ServiceTestContext<IPersonService>;
  storyCtx: ServiceTestContext<IStoryService>;

  constructor() {
    this.personCtx = new ServiceTestContext<IPersonService>((repo) => new PersonService(repo));
    this.storyCtx = new ServiceTestContext<IStoryService>((repo) => new StoryService(repo));
  }

  async setup(): Promise<void> {
    await this.personCtx.setup();
    await this.storyCtx.setup();
  }

  async teardown(): Promise<void> {
    await this.storyCtx.teardown();
    await this.personCtx.teardown();
  }
}

export default function l3LinkPhotoService(): void {
  describe('L3_linkPhoto', () => {
    const ctx = new LinkPhotoTestContext();

    beforeAll(async () => {
      await ctx.setup();
    });

    afterAll(async () => {
      await ctx.teardown();
    });

    it('L3_linkPhoto_link_unlink_lifecycle', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const ss = ctx.storyCtx.getService();
      const pid = ps.createPerson(TestDataFactory.uniqueName('LifeP'));
      const sid = ss.createStory(TestDataFactory.createStoryTitle());
      expect(ps.isLinked(pid, sid)).assertFalse();
      ps.linkPersonToStory(pid, sid);
      expect(ps.isLinked(pid, sid)).assertTrue();
      ps.unlinkPersonFromStory(pid, sid);
      expect(ps.isLinked(pid, sid)).assertFalse();
    });

    it('L3_linkPhoto_link_idempotent', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const ss = ctx.storyCtx.getService();
      const pid = ps.createPerson(TestDataFactory.uniqueName('IdemP'));
      const sid = ss.createStory(TestDataFactory.createStoryTitle());
      ps.linkPersonToStory(pid, sid);
      ps.linkPersonToStory(pid, sid);
      expect(ps.listLinkedStories(pid).length).assertEqual(1);
    });

    it('L3_linkPhoto_link_nonexistent_person_silent', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const ss = ctx.storyCtx.getService();
      const sid = ss.createStory(TestDataFactory.createStoryTitle());
      ps.linkPersonToStory(999999999, sid);
      expect(ps.isLinked(999999999, sid)).assertFalse();
      const pid = ps.createPerson(TestDataFactory.uniqueName('ExistP'));
      ps.linkPersonToStory(pid, 999999999);
      expect(ps.isLinked(pid, 999999999)).assertFalse();
    });

    it('L3_linkPhoto_unlink_nonexistent_silent', 0, (): void => {
      const ps = ctx.personCtx.getService();
      ps.unlinkPersonFromStory(999999999, 999999999);
    });

    it('L3_linkPhoto_shared_photoRef_two_persons', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const p1 = ps.createPerson(TestDataFactory.uniqueName('Share1'));
      const p2 = ps.createPerson(TestDataFactory.uniqueName('Share2'));
      const uri = TestDataFactory.createPhotoUri();
      expect(ps.addPhotoToPerson(p1, uri).success).assertTrue();
      expect(ps.addPhotoToPerson(p2, uri).success).assertTrue();
      const ph1 = ps.listPersonPhotos(p1);
      const ph2 = ps.listPersonPhotos(p2);
      expect(ph1.length).assertEqual(1);
      expect(ph2.length).assertEqual(1);
      expect(ph1[0].id).assertEqual(ph2[0].id);
    });

    it('L3_linkPhoto_shared_photoRef_person_and_story', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const ss = ctx.storyCtx.getService();
      const pid = ps.createPerson(TestDataFactory.uniqueName('CrossP'));
      const sid = ss.createStory(TestDataFactory.createStoryTitle());
      const uri = TestDataFactory.createPhotoUri();
      expect(ps.addPhotoToPerson(pid, uri).success).assertTrue();
      expect(ss.addPhotoToStory(sid, uri).success).assertTrue();
      expect(ps.listPersonPhotos(pid).length).assertEqual(1);
      expect(ss.listStoryPhotos(sid).length).assertEqual(1);
    });

    it('L3_linkPhoto_addPhoto_with_metadata_takenAt', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const ss = ctx.storyCtx.getService();
      const pid = ps.createPerson(TestDataFactory.uniqueName('MetaP'));
      const sid = ss.createStory(TestDataFactory.createStoryTitle());
      const uri = TestDataFactory.createPhotoUri();
      const takenAt = 1700000000000;
      expect(ps.addPhotoToPerson(pid, uri, { takenAt }).success).assertTrue();
      const personPhotos = ps.listPersonPhotos(pid);
      expect(personPhotos[0].metadata !== undefined).assertTrue();
      expect(personPhotos[0].metadata!.takenAt).assertEqual(takenAt);
      const uri2 = TestDataFactory.createPhotoUri();
      expect(ss.addPhotoToStory(sid, uri2, { takenAt: takenAt + 1000 }).success).assertTrue();
      const storyPhotos = ss.listStoryPhotos(sid);
      expect(storyPhotos[0].metadata !== undefined).assertTrue();
      expect(storyPhotos[0].metadata!.takenAt).assertEqual(takenAt + 1000);
    });

    it('L3_linkPhoto_addPhoto_blank_uri_fails', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const ss = ctx.storyCtx.getService();
      const pid = ps.createPerson(TestDataFactory.uniqueName('BlankUri'));
      const sid = ss.createStory(TestDataFactory.createStoryTitle());
      expect(ps.addPhotoToPerson(pid, '  \t').success).assertFalse();
      expect(ss.addPhotoToStory(sid, '').success).assertFalse();
    });

    it('L3_linkPhoto_addPhoto_nonexistent_owner_fails', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const ss = ctx.storyCtx.getService();
      expect(ps.addPhotoToPerson(999999999, TestDataFactory.createPhotoUri()).success).assertFalse();
      expect(ss.addPhotoToStory(999999999, TestDataFactory.createPhotoUri()).success).assertFalse();
    });

    it('L3_linkPhoto_removePhoto_success', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const ss = ctx.storyCtx.getService();
      const pid = ps.createPerson(TestDataFactory.uniqueName('RmP'));
      const sid = ss.createStory(TestDataFactory.createStoryTitle());
      const uri1 = TestDataFactory.createPhotoUri();
      const uri2 = TestDataFactory.createPhotoUri();
      ps.addPhotoToPerson(pid, uri1);
      ss.addPhotoToStory(sid, uri2);
      const pPhotos = ps.listPersonPhotos(pid);
      const sPhotos = ss.listStoryPhotos(sid);
      expect(ps.removePhotoFromPerson(pid, pPhotos[0].id)).assertTrue();
      expect(ss.removePhotoFromStory(sid, sPhotos[0].id)).assertTrue();
      expect(ps.listPersonPhotos(pid).length).assertEqual(0);
      expect(ss.listStoryPhotos(sid).length).assertEqual(0);
    });

    it('L3_linkPhoto_removePhoto_nonexistent_returns_false', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const ss = ctx.storyCtx.getService();
      const pid = ps.createPerson(TestDataFactory.uniqueName('NoRmP'));
      const sid = ss.createStory(TestDataFactory.createStoryTitle());
      expect(ps.removePhotoFromPerson(pid, 999999999)).assertFalse();
      expect(ss.removePhotoFromStory(sid, 999999999)).assertFalse();
    });

    it('L3_linkPhoto_removePhoto_shared_other_owner_unaffected', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const ss = ctx.storyCtx.getService();
      const pid = ps.createPerson(TestDataFactory.uniqueName('CrossRmP'));
      const sid = ss.createStory(TestDataFactory.createStoryTitle());
      const uri = TestDataFactory.createPhotoUri();
      ps.addPhotoToPerson(pid, uri);
      ss.addPhotoToStory(sid, uri);
      const pPhotos = ps.listPersonPhotos(pid);
      ps.removePhotoFromPerson(pid, pPhotos[0].id);
      expect(ps.listPersonPhotos(pid).length).assertEqual(0);
      expect(ss.listStoryPhotos(sid).length).assertEqual(1);
    });

    it('L3_linkPhoto_deletePerson_shared_photo_survives', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const p1 = ps.createPerson(TestDataFactory.uniqueName('DelP1'));
      const p2 = ps.createPerson(TestDataFactory.uniqueName('DelP2'));
      const uri = TestDataFactory.createPhotoUri();
      ps.addPhotoToPerson(p1, uri);
      ps.addPhotoToPerson(p2, uri);
      ps.deletePerson(p1);
      expect(ps.listPersonPhotos(p2).length).assertEqual(1);
    });

    it('L3_linkPhoto_deleteStory_shared_photo_survives', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const ss = ctx.storyCtx.getService();
      const pid = ps.createPerson(TestDataFactory.uniqueName('StoryDelP'));
      const sid = ss.createStory(TestDataFactory.createStoryTitle());
      const uri = TestDataFactory.createPhotoUri();
      ps.addPhotoToPerson(pid, uri);
      ss.addPhotoToStory(sid, uri);
      ss.deleteStory(sid);
      expect(ps.listPersonPhotos(pid).length).assertEqual(1);
    });

    it('L3_linkPhoto_gcOrphan_cleans_unreferenced', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const pid = ps.createPerson(TestDataFactory.uniqueName('OrphanP'));
      const uri = TestDataFactory.createPhotoUri();
      ps.addPhotoToPerson(pid, uri);
      const photos = ps.listPersonPhotos(pid);
      ps.removePhotoFromPerson(pid, photos[0].id);
      const n = ps.gcOrphanPhotoRefs();
      expect(n >= 1).assertTrue();
    });

    it('L3_linkPhoto_gcOrphan_skips_referenced', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const pid = ps.createPerson(TestDataFactory.uniqueName('RefP'));
      ps.addPhotoToPerson(pid, TestDataFactory.createPhotoUri());
      expect(ps.gcOrphanPhotoRefs()).assertEqual(0);
    });

    it('L3_linkPhoto_gcOrphan_no_orphans_return_0', 0, (): void => {
      const ps = ctx.personCtx.getService();
      expect(ps.gcOrphanPhotoRefs()).assertEqual(0);
    });

    it('L3_linkPhoto_story_cap_1000', 0, (): void => {
      const ss = ctx.storyCtx.getService();
      const sid = ss.createStory(TestDataFactory.createStoryTitle());
      const store = ctx.storyCtx.getStore();
      for (let i = 0; i < 1000; i++) {
        const uri = `file://test/cap2-batch-${i}`;
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
      const res = ss.addPhotoToStory(sid, 'file://test/cap2-1001');
      expect(res.success).assertFalse();
      expect(res.duplicate).assertFalse();
    });

    it('L3_linkPhoto_person_no_cap', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const pid = ps.createPerson(TestDataFactory.uniqueName('NoCapP'));
      for (let i = 0; i < 5; i++) {
        const res = ps.addPhotoToPerson(pid, TestDataFactory.createPhotoUri(i));
        expect(res.success).assertTrue();
      }
      expect(ps.listPersonPhotos(pid).length).assertEqual(5);
    });

    it('L3_linkPhoto_photo_count_sync_on_add', 0, (): void => {
      const ss = ctx.storyCtx.getService();
      const sid = ss.createStory(TestDataFactory.createStoryTitle());
      expect(ss.getStory(sid)!.photoCount).assertEqual(0);
      ss.addPhotoToStory(sid, TestDataFactory.createPhotoUri());
      expect(ss.getStory(sid)!.photoCount).assertEqual(1);
      ss.addPhotoToStory(sid, TestDataFactory.createPhotoUri());
      expect(ss.getStory(sid)!.photoCount).assertEqual(2);
    });

    it('L3_linkPhoto_photo_count_sync_on_remove', 0, (): void => {
      const ss = ctx.storyCtx.getService();
      const sid = ss.createStory(TestDataFactory.createStoryTitle());
      ss.addPhotoToStory(sid, TestDataFactory.createPhotoUri());
      ss.addPhotoToStory(sid, TestDataFactory.createPhotoUri());
      expect(ss.getStory(sid)!.photoCount).assertEqual(2);
      const photos = ss.listStoryPhotos(sid);
      ss.removePhotoFromStory(sid, photos[0].id);
      expect(ss.getStory(sid)!.photoCount).assertEqual(1);
    });

    it('L3_linkPhoto_reference_count_shared_increment', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const p1 = ps.createPerson(TestDataFactory.uniqueName('RefCnt1'));
      const p2 = ps.createPerson(TestDataFactory.uniqueName('RefCnt2'));
      const uri = TestDataFactory.createPhotoUri();
      ps.addPhotoToPerson(p1, uri);
      ps.addPhotoToPerson(p2, uri);
      const store = ctx.personCtx.getStore();
      const rs = store.querySqlSync('SELECT reference_count FROM photo_ref WHERE uri = ?;', [uri]);
      let refCount = 0;
      if (rs.goToFirstRow()) {
        refCount = Number(rs.getLong(rs.getColumnIndex('reference_count')));
      }
      rs.close();
      expect(refCount).assertEqual(2);
    });

    it('L3_linkPhoto_reference_count_delete_decrement', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const p1 = ps.createPerson(TestDataFactory.uniqueName('RefDec1'));
      const p2 = ps.createPerson(TestDataFactory.uniqueName('RefDec2'));
      const uri = TestDataFactory.createPhotoUri();
      ps.addPhotoToPerson(p1, uri);
      ps.addPhotoToPerson(p2, uri);
      ps.deletePerson(p1);
      const store = ctx.personCtx.getStore();
      const rs = store.querySqlSync('SELECT reference_count FROM photo_ref WHERE uri = ?;', [uri]);
      let refCount = 0;
      if (rs.goToFirstRow()) {
        refCount = Number(rs.getLong(rs.getColumnIndex('reference_count')));
      }
      rs.close();
      expect(refCount).assertEqual(1);
    });

    it('L3_linkPhoto_removePhoto_keeps_photoRef', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const pid = ps.createPerson(TestDataFactory.uniqueName('KeepRefP'));
      const uri = TestDataFactory.createPhotoUri();
      ps.addPhotoToPerson(pid, uri);
      const photos = ps.listPersonPhotos(pid);
      ps.removePhotoFromPerson(pid, photos[0].id);
      const store = ctx.personCtx.getStore();
      const rs = store.querySqlSync('SELECT id FROM photo_ref WHERE uri = ?;', [uri]);
      const exists = rs.goToFirstRow();
      rs.close();
      expect(exists).assertTrue();
    });

    it('L3_linkPhoto_cross_link_multiple_persons_stories', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const ss = ctx.storyCtx.getService();
      const p1 = ps.createPerson(TestDataFactory.uniqueName('CrossP1'));
      const p2 = ps.createPerson(TestDataFactory.uniqueName('CrossP2'));
      const s1 = ss.createStory(TestDataFactory.createStoryTitle());
      const s2 = ss.createStory(TestDataFactory.createStoryTitle());
      ps.linkPersonToStory(p1, s1);
      ps.linkPersonToStory(p1, s2);
      ps.linkPersonToStory(p2, s1);
      expect(ps.listLinkedStories(p1).length).assertEqual(2);
      expect(ps.listLinkedStories(p2).length).assertEqual(1);
      expect(ss.listLinkedPersons(s1).length).assertEqual(2);
      expect(ss.listLinkedPersons(s2).length).assertEqual(1);
    });

    it('L3_linkPhoto_cross_photo_multiple_owners', 0, (): void => {
      const ps = ctx.personCtx.getService();
      const ss = ctx.storyCtx.getService();
      const pid = ps.createPerson(TestDataFactory.uniqueName('MultiOwnerP'));
      const sid = ss.createStory(TestDataFactory.createStoryTitle());
      const uri = TestDataFactory.createPhotoUri();
      ps.addPhotoToPerson(pid, uri);
      ss.addPhotoToStory(sid, uri);
      expect(ps.listPersonPhotos(pid).length).assertEqual(1);
      expect(ss.listStoryPhotos(sid).length).assertEqual(1);
      const pPhotos = ps.listPersonPhotos(pid);
      ps.removePhotoFromPerson(pid, pPhotos[0].id);
      expect(ss.listStoryPhotos(sid).length).assertEqual(1);
    });
  });
}
