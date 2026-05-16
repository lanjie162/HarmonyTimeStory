/**
 * Tier1：RepositoryImpl + 真实 RDB（独立库文件 + ensureSchemaV1）。
 * 依赖 Hypium 宿主提供的 Application Context（abilityDelegator.getAppContext），无 UI Driver。
 * 已从 src/test/ 迁入 ohosTest，因需要 abilityDelegatorRegistry。
 */
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { relationalStore } from '@kit.ArkData';
import { afterAll, beforeAll, describe, expect, it } from '@ohos/hypium';
import { ensureSchemaV1 } from '../../../main/ets/infrastructure/data/RdbSchema';
import { RepositoryImpl } from '../../../main/ets/infrastructure/repository/RepositoryImpl';

function sleepMs(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void): void => {
    setTimeout((): void => {
      resolve();
    }, ms);
  });
}

export default function tier1RepositoryRdb(): void {
  describe('tier1_repository_rdb_integration', () => {
    let store: relationalStore.RdbStore | undefined = undefined;
    let repo: RepositoryImpl | undefined = undefined;
    const dbName = `TimestoreTier1_${Date.now()}.db`;

    beforeAll(async () => {
      try {
        const delegator = abilityDelegatorRegistry.getAbilityDelegator();
        const ctx = delegator.getAppContext();
        console.info('Tier1Rdb: got app context, creating RDB: ' + dbName);
        const cfg: relationalStore.StoreConfig = {
          name: dbName,
          securityLevel: relationalStore.SecurityLevel.S1
        };
        const s = await relationalStore.getRdbStore(ctx, cfg);
        console.info('Tier1Rdb: RDB created, applying schema');
        ensureSchemaV1(s);
        console.info('Tier1Rdb: schema applied, attaching repo');
        const r = new RepositoryImpl();
        r.attachRdb(s);
        store = s;
        repo = r;
        console.info('Tier1Rdb: beforeAll complete');
      } catch (e) {
        console.error('Tier1Rdb: beforeAll FAILED: ' + JSON.stringify(e));
        throw new Error(typeof e === 'string' ? e : JSON.stringify(e));
      }
    });

    afterAll(() => {
      if (store !== undefined) {
        try {
          store.close();
          console.info('Tier1Rdb: store closed');
        } catch (_e) {
          // ignore
        }
      }
      store = undefined;
      repo = undefined;
    });

    it('rdb_createPerson_rejects_blank', 0, (): void => {
      const r = repo as RepositoryImpl;
      expect(r.createPerson('   ')).assertEqual(-1);
      expect(r.createPerson('\t\n')).assertEqual(-1);
    });

    it('rdb_createPerson_trims_and_reads', 0, (): void => {
      const r = repo as RepositoryImpl;
      const id = r.createPerson('  Alice  ');
      expect(id > 0).assertTrue();
      expect((r.getPerson(id)?.displayName ?? '')).assertEqual('Alice');
    });

    it('rdb_createStory_rejects_blank', 0, (): void => {
      const r = repo as RepositoryImpl;
      expect(r.createStory('')).assertEqual(-1);
      expect(r.createStory('  \n')).assertEqual(-1);
    });

    it('rdb_updateStory_rejects_blank', 0, (): void => {
      const r = repo as RepositoryImpl;
      const sid = r.createStory('SKeep');
      expect(sid > 0).assertTrue();
      expect(r.updateStory(sid, '  ')).assertFalse();
      expect((r.getStory(sid)?.title ?? '')).assertEqual('SKeep');
    });

    it('rdb_getStory_missing', 0, (): void => {
      const r = repo as RepositoryImpl;
      expect(r.getStory(999999999) === null).assertTrue();
    });

    it('rdb_updatePerson_rejects_blank', 0, (): void => {
      const r = repo as RepositoryImpl;
      const id = r.createPerson('Bob');
      expect(id > 0).assertTrue();
      expect(r.updatePerson(id, '  ')).assertFalse();
      expect((r.getPerson(id)?.displayName ?? '')).assertEqual('Bob');
    });

    it('rdb_listPersons_newest_first', 0, async (): Promise<void> => {
      const r = repo as RepositoryImpl;
      const idA = r.createPerson('ListA');
      await sleepMs(15);
      const idB = r.createPerson('ListB');
      expect(idA > 0 && idB > 0).assertTrue();
      const list = r.listPersons();
      expect(list.length >= 2).assertTrue();
      expect(list[0].displayName).assertEqual('ListB');
    });

    it('rdb_getPerson_missing', 0, (): void => {
      const r = repo as RepositoryImpl;
      expect(r.getPerson(999999999) === null).assertTrue();
    });

    it('rdb_updatePerson_no_row', 0, (): void => {
      const r = repo as RepositoryImpl;
      expect(r.updatePerson(999999999, 'Ghost')).assertFalse();
    });

    it('rdb_link_unlink_and_query', 0, (): void => {
      const r = repo as RepositoryImpl;
      const pid = r.createPerson('LinkPerson');
      const sid = r.createStory('LinkStory');
      expect(r.isPersonStoryLinked(pid, sid)).assertFalse();
      r.linkPersonStory(pid, sid);
      expect(r.isPersonStoryLinked(pid, sid)).assertTrue();
      const stories = r.linkedStoriesForPerson(pid);
      expect(stories.length).assertEqual(1);
      expect(stories[0].title).assertEqual('LinkStory');
      const persons = r.linkedPersonsForStory(sid);
      expect(persons.length).assertEqual(1);
      expect(persons[0].displayName).assertEqual('LinkPerson');
      r.unlinkPersonStory(pid, sid);
      expect(r.isPersonStoryLinked(pid, sid)).assertFalse();
    });

    it('rdb_link_person_story_idempotent', 0, (): void => {
      const r = repo as RepositoryImpl;
      const pid = r.createPerson('IdemP');
      const sid = r.createStory('IdemS');
      r.linkPersonStory(pid, sid);
      r.linkPersonStory(pid, sid);
      expect(r.linkedStoriesForPerson(pid).length).assertEqual(1);
    });

    it('rdb_addPhoto_person_success_and_duplicate', 0, (): void => {
      const r = repo as RepositoryImpl;
      const pid = r.createPerson('PhotoP');
      const uri = 'file://tier1/photo-person-1';
      const a1 = r.addPhotoForPerson(pid, uri);
      expect(a1.success).assertTrue();
      expect(a1.duplicate).assertFalse();
      const a2 = r.addPhotoForPerson(pid, uri);
      expect(a2.success).assertFalse();
      expect(a2.duplicate).assertTrue();
      const photos = r.photosForPerson(pid);
      expect(photos.length).assertEqual(1);
      expect(photos[0].uri).assertEqual(uri);
    });

    it('rdb_addPhoto_person_unknown_owner_fails', 0, (): void => {
      const r = repo as RepositoryImpl;
      const res = r.addPhotoForPerson(999999999, 'file://tier1/orphan');
      expect(res.success).assertFalse();
      expect(res.duplicate).assertFalse();
    });

    it('rdb_addPhoto_empty_uri_fails', 0, (): void => {
      const r = repo as RepositoryImpl;
      const pid = r.createPerson('UriEmpty');
      const res = r.addPhotoForPerson(pid, '  \t');
      expect(res.success).assertFalse();
    });

    it('rdb_addPhoto_story_success', 0, (): void => {
      const r = repo as RepositoryImpl;
      const sid = r.createStory('PhotoSt');
      const uri = 'file://tier1/photo-story-1';
      const res = r.addPhotoForStory(sid, uri);
      expect(res.success).assertTrue();
      const photos = r.photosForStory(sid);
      expect(photos.length).assertEqual(1);
      expect(photos[0].uri).assertEqual(uri);
    });

    it('rdb_shared_photo_ref_across_two_persons', 0, (): void => {
      const r = repo as RepositoryImpl;
      const p1 = r.createPerson('Share1');
      const p2 = r.createPerson('Share2');
      const uri = 'file://tier1/shared-ref-1';
      expect(r.addPhotoForPerson(p1, uri).success).assertTrue();
      expect(r.addPhotoForPerson(p2, uri).success).assertTrue();
      const ph1 = r.photosForPerson(p1);
      const ph2 = r.photosForPerson(p2);
      expect(ph1.length).assertEqual(1);
      expect(ph2.length).assertEqual(1);
      expect(ph1[0].uri).assertEqual(uri);
      expect(ph2[0].uri).assertEqual(uri);
      expect(ph1[0].id).assertEqual(ph2[0].id);
    });
  });
}