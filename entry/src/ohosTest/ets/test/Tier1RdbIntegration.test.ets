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
import { GenderEnum, PersonTypeEnum } from '../../../main/ets/domain/model/Models';
import type { PersonModel, StoryModel } from '../../../main/ets/domain/model/Models';

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
      expect(r.createPerson({ displayName: '   ' })).assertEqual(-1);
      expect(r.createPerson({ displayName: '\t\n' })).assertEqual(-1);
    });

    it('rdb_createPerson_trims_and_reads', 0, (): void => {
      const r = repo as RepositoryImpl;
      const id = r.createPerson({ displayName: '  Alice  ' });
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
      const id = r.createPerson({ displayName: 'Bob' });
      expect(id > 0).assertTrue();
      expect(r.updatePerson(id, { displayName: '  ' })).assertFalse();
      expect((r.getPerson(id)?.displayName ?? '')).assertEqual('Bob');
    });

    it('rdb_listPersons_newest_first', 0, async (): Promise<void> => {
      const r = repo as RepositoryImpl;
      const idA = r.createPerson({ displayName: 'ListA' });
      await sleepMs(15);
      const idB = r.createPerson({ displayName: 'ListB' });
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
      expect(r.updatePerson(999999999, { displayName: 'Ghost' })).assertFalse();
    });

    it('rdb_link_unlink_and_query', 0, (): void => {
      const r = repo as RepositoryImpl;
      const pid = r.createPerson({ displayName: 'LinkPerson' });
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
      const pid = r.createPerson({ displayName: 'IdemP' });
      const sid = r.createStory('IdemS');
      r.linkPersonStory(pid, sid);
      r.linkPersonStory(pid, sid);
      expect(r.linkedStoriesForPerson(pid).length).assertEqual(1);
    });

    it('rdb_addPhoto_person_success_and_duplicate', 0, (): void => {
      const r = repo as RepositoryImpl;
      const pid = r.createPerson({ displayName: 'PhotoP' });
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
      const pid = r.createPerson({ displayName: 'UriEmpty' });
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
      const p1 = r.createPerson({ displayName: 'Share1' });
      const p2 = r.createPerson({ displayName: 'Share2' });
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

    // ── T-22 (C-1) Person 新字段 ──────────────────────────────

    it('rdb_createPerson_with_all_new_fields', 0, (): void => {
      const r = repo as RepositoryImpl;
      const now = Date.now();
      const avatar = new Uint8Array([0x89, 0x50, 0x4E, 0x47]);
      const id = r.createPerson({
        displayName: 'FullFields',
        avatarBlob: avatar,
        birthday: now,
        gender: GenderEnum.UNSPECIFIED,
        remark: 'test remark',
        personType: PersonTypeEnum.BABY
      });
      expect(id > 0).assertTrue();
      const p = r.getPerson(id) as PersonModel;
      expect(p.displayName).assertEqual('FullFields');
      expect(p.avatarBlob !== null).assertTrue();
      expect(p.avatarBlob!.length).assertEqual(4);
      expect(p.birthday).assertEqual(now);
      expect(p.gender).assertEqual(GenderEnum.UNSPECIFIED);
      expect(p.remark).assertEqual('test remark');
      expect(p.personType).assertEqual(PersonTypeEnum.BABY);
    });

    it('rdb_createPerson_defaults_new_fields', 0, (): void => {
      const r = repo as RepositoryImpl;
      const id = r.createPerson({ displayName: 'MinFields' });
      expect(id > 0).assertTrue();
      const p = r.getPerson(id) as PersonModel;
      expect(p.avatarBlob === null).assertTrue();
      expect(p.birthday === null).assertTrue();
      expect(p.gender === null).assertTrue();
      expect(p.remark).assertEqual('');
      expect(p.personType).assertEqual(PersonTypeEnum.OTHER);
    });

    it('rdb_updatePerson_birthday_set_then_clear', 0, (): void => {
      const r = repo as RepositoryImpl;
      const id = r.createPerson({ displayName: 'BirthTest' });
      expect(id > 0).assertTrue();
      const ts = 946684800000; // 2000-01-01
      expect(r.updatePerson(id, { birthday: ts })).assertTrue();
      let p = r.getPerson(id) as PersonModel;
      expect(p.birthday).assertEqual(ts);
      expect(r.updatePerson(id, { birthday: null })).assertTrue();
      p = r.getPerson(id) as PersonModel;
      expect(p.birthday === null).assertTrue();
    });

    it('rdb_updatePerson_gender_change', 0, (): void => {
      const r = repo as RepositoryImpl;
      const id = r.createPerson({ displayName: 'GenderChg' });
      expect(r.updatePerson(id, { gender: GenderEnum.MALE })).assertTrue();
      expect((r.getPerson(id) as PersonModel).gender).assertEqual(GenderEnum.MALE);
      expect(r.updatePerson(id, { gender: GenderEnum.FEMALE })).assertTrue();
      expect((r.getPerson(id) as PersonModel).gender).assertEqual(GenderEnum.FEMALE);
    });

    it('rdb_updatePerson_remark_and_type', 0, (): void => {
      const r = repo as RepositoryImpl;
      const id = r.createPerson({ displayName: 'RmkType' });
      expect(r.updatePerson(id, { remark: 'new note', personType: PersonTypeEnum.ELDER })).assertTrue();
      const p = r.getPerson(id) as PersonModel;
      expect(p.remark).assertEqual('new note');
      expect(p.personType).assertEqual(PersonTypeEnum.ELDER);
    });

    it('rdb_updatePerson_avatarBlob_null', 0, (): void => {
      const r = repo as RepositoryImpl;
      const id = r.createPerson({
        displayName: 'AvatarNull',
        avatarBlob: new Uint8Array([0x01, 0x02])
      });
      expect((r.getPerson(id) as PersonModel).avatarBlob !== null).assertTrue();
      expect(r.updatePerson(id, { avatarBlob: null })).assertTrue();
      expect((r.getPerson(id) as PersonModel).avatarBlob === null).assertTrue();
    });

    // ── T-23 (C-2) Story 新字段 ──────────────────────────────

    it('rdb_createStory_with_all_new_fields', 0, (): void => {
      const r = repo as RepositoryImpl;
      const now = Date.now();
      const sid = r.createStory('FullSt', 'desc text', now, now + 86400000,
        'file://cover', 'Beijing', ['tag1', 'tag2']);
      expect(sid > 0).assertTrue();
      const s = r.getStory(sid) as StoryModel;
      expect(s.title).assertEqual('FullSt');
      expect(s.description).assertEqual('desc text');
      expect(s.timeStart).assertEqual(now);
      expect(s.timeEnd).assertEqual(now + 86400000);
      expect(s.coverUri).assertEqual('file://cover');
      expect(s.location).assertEqual('Beijing');
      expect(s.tags.length).assertEqual(2);
      expect(s.tags[0]).assertEqual('tag1');
      expect(s.tags[1]).assertEqual('tag2');
    });

    it('rdb_createStory_defaults_new_fields', 0, (): void => {
      const r = repo as RepositoryImpl;
      const sid = r.createStory('MinSt');
      expect(sid > 0).assertTrue();
      const s = r.getStory(sid) as StoryModel;
      expect(s.description).assertEqual('');
      expect(s.timeStart === null).assertTrue();
      expect(s.timeEnd === null).assertTrue();
      expect(s.coverUri).assertEqual('');
      expect(s.location).assertEqual('');
      expect(s.tags.length).assertEqual(0);
    });

    it('rdb_tags_read_write_roundtrip', 0, (): void => {
      const r = repo as RepositoryImpl;
      const sid = r.createStory('TagsTest', '', null, null, '', '', ['a', 'b', 'c']);
      let s = r.getStory(sid) as StoryModel;
      expect(s.tags.length).assertEqual(3);
      expect(s.tags[0]).assertEqual('a');
      expect(s.tags[1]).assertEqual('b');
      expect(s.tags[2]).assertEqual('c');

      // updateStoryAll 换标签
      const ok = r.updateStoryAll(sid, { tags: ['x', 'y'] });
      expect(ok).assertTrue();
      s = r.getStory(sid) as StoryModel;
      expect(s.tags.length).assertEqual(2);
      expect(s.tags[0]).assertEqual('x');
      expect(s.tags[1]).assertEqual('y');

      // updateStoryAll 清空标签
      expect(r.updateStoryAll(sid, { tags: [] })).assertTrue();
      s = r.getStory(sid) as StoryModel;
      expect(s.tags.length).assertEqual(0);
    });

    it('rdb_updateStoryAll_full_fields', 0, (): void => {
      const r = repo as RepositoryImpl;
      const sid = r.createStory('UpdateAllOrig');
      const now = Date.now();
      const ok = r.updateStoryAll(sid, {
        title: 'UpdateAllNew',
        description: 'new desc',
        timeStart: now,
        timeEnd: now + 3600000,
        coverUri: 'file://new-cover',
        location: 'Shanghai',
        tags: ['travel', '2026']
      });
      expect(ok).assertTrue();
      const s = r.getStory(sid) as StoryModel;
      expect(s.title).assertEqual('UpdateAllNew');
      expect(s.description).assertEqual('new desc');
      expect(s.timeStart).assertEqual(now);
      expect(s.location).assertEqual('Shanghai');
      expect(s.tags.length).assertEqual(2);
    });

    // ── T-24 (C-3) 删除 + 级联规则 ──────────────────────────

    it('rdb_deletePerson_cascade_cleanup', 0, (): void => {
      const r = repo as RepositoryImpl;
      const pid = r.createPerson({ displayName: 'CascadeP' });
      const sid = r.createStory('CascadeS');
      r.linkPersonStory(pid, sid);
      r.addPhotoForPerson(pid, 'file://tier1/cascade-photo');
      expect(r.deletePerson(pid)).assertTrue();
      // person 记录删除
      expect(r.getPerson(pid) === null).assertTrue();
      // person-story 关联删除
      expect(r.isPersonStoryLinked(pid, sid)).assertFalse();
      // person 侧 photo_owner_link 清除
      expect(r.photosForPerson(pid).length).assertEqual(0);
      // story 侧 link 不受影响
      expect(r.linkedPersonsForStory(sid).length).assertEqual(0);
    });

    it('rdb_deleteStory_cascade_cleanup', 0, (): void => {
      const r = repo as RepositoryImpl;
      const pid = r.createPerson({ displayName: 'CascadeSP' });
      const sid = r.createStory('CascadeSS');
      r.linkPersonStory(pid, sid);
      r.addPhotoForStory(sid, 'file://tier1/cascade-s-photo');
      expect(r.deleteStory(sid)).assertTrue();
      expect(r.getStory(sid) === null).assertTrue();
      expect(r.isPersonStoryLinked(pid, sid)).assertFalse();
      expect(r.linkedStoriesForPerson(pid).length).assertEqual(0);
      expect(r.photosForStory(sid).length).assertEqual(0);
    });

    it('rdb_deletePerson_nonexistent_returns_false', 0, (): void => {
      const r = repo as RepositoryImpl;
      expect(r.deletePerson(999999999)).assertFalse();
    });

    it('rdb_deleteStory_nonexistent_returns_false', 0, (): void => {
      const r = repo as RepositoryImpl;
      expect(r.deleteStory(999999999)).assertFalse();
    });

    it('rdb_deletePerson_shared_photo_keeps_other_ref', 0, (): void => {
      const r = repo as RepositoryImpl;
      const p1 = r.createPerson({ displayName: 'SharedDelP1' });
      const p2 = r.createPerson({ displayName: 'SharedDelP2' });
      const uri = 'file://tier1/shared-del-photo';
      expect(r.addPhotoForPerson(p1, uri).success).assertTrue();
      expect(r.addPhotoForPerson(p2, uri).success).assertTrue();
      const phBefore = r.photosForPerson(p2);
      expect(phBefore.length).assertEqual(1);
      expect(r.deletePerson(p1)).assertTrue();
      // P2 仍拥有该照片
      const phAfter = r.photosForPerson(p2);
      expect(phAfter.length).assertEqual(1);
      expect(phAfter[0].uri).assertEqual(uri);
    });

    // ── T-25 (C-4) 移除照片 ─────────────────────────────────

    it('rdb_removePhoto_person_removes_link_keeps_ref', 0, (): void => {
      const r = repo as RepositoryImpl;
      const pid = r.createPerson({ displayName: 'RemoveP' });
      const uri = 'file://tier1/remove-photo-1';
      const add = r.addPhotoForPerson(pid, uri);
      expect(add.success).assertTrue();
      const ph = r.photosForPerson(pid);
      expect(ph.length).assertEqual(1);
      expect(r.removePhotoForPerson(pid, ph[0].id)).assertTrue();
      expect(r.photosForPerson(pid).length).assertEqual(0);
    });

    it('rdb_removePhoto_nonexistent_link_returns_false', 0, (): void => {
      const r = repo as RepositoryImpl;
      const pid = r.createPerson({ displayName: 'RemoveFail' });
      expect(r.removePhotoForPerson(pid, 999999999)).assertFalse();
    });

    it('rdb_removePhoto_shared_photo_other_owner_unaffected', 0, (): void => {
      const r = repo as RepositoryImpl;
      const p1 = r.createPerson({ displayName: 'SharedR1' });
      const p2 = r.createPerson({ displayName: 'SharedR2' });
      const uri = 'file://tier1/shared-remove-photo';
      expect(r.addPhotoForPerson(p1, uri).success).assertTrue();
      expect(r.addPhotoForPerson(p2, uri).success).assertTrue();
      const ph1 = r.photosForPerson(p1);
      expect(r.removePhotoForPerson(p1, ph1[0].id)).assertTrue();
      expect(r.photosForPerson(p1).length).assertEqual(0);
      expect(r.photosForPerson(p2).length).assertEqual(1);
    });

    it('rdb_removePhoto_story_same_semantics', 0, (): void => {
      const r = repo as RepositoryImpl;
      const sid = r.createStory('RemoveSt');
      const uri = 'file://tier1/remove-story-photo';
      expect(r.addPhotoForStory(sid, uri).success).assertTrue();
      const ph = r.photosForStory(sid);
      expect(ph.length).assertEqual(1);
      expect(r.removePhotoForStory(sid, ph[0].id)).assertTrue();
      expect(r.photosForStory(sid).length).assertEqual(0);
    });

    // ── T-26 (C-5) sortOrder 修正 ───────────────────────────

    it('rdb_photo_sort_order_taken_at_desc', 0, async (): Promise<void> => {
      const r = repo as RepositoryImpl;
      const pid = r.createPerson({ displayName: 'SortP' });
      // Add 3 photos with explicit delays to ensure ordered linked_at values
      r.addPhotoForPerson(pid, 'file://tier1/sort-a');
      await sleepMs(15);
      r.addPhotoForPerson(pid, 'file://tier1/sort-b');
      await sleepMs(15);
      r.addPhotoForPerson(pid, 'file://tier1/sort-c');
      const photos = r.photosForPerson(pid);
      expect(photos.length).assertEqual(3);
      // With taken_at_cache=NULLS LAST + linked_at DESC: newest first = sort-c
      expect(photos[0].uri).assertEqual('file://tier1/sort-c');
      expect(photos[2].uri).assertEqual('file://tier1/sort-a');
    });

    // ── T-27 (C-6) PhotoRef 孤儿 GC ─────────────────────────

    it('rdb_gcOrphan_cleans_unreferenced_photo', 0, (): void => {
      const r = repo as RepositoryImpl;
      // add then remove → orphan
      const pid = r.createPerson({ displayName: 'OrphanP' });
      const uri = 'file://tier1/orphan-photo';
      expect(r.addPhotoForPerson(pid, uri).success).assertTrue();
      const ph = r.photosForPerson(pid);
      expect(r.removePhotoForPerson(pid, ph[0].id)).assertTrue();
      // photo_ref row still exists (is_referenced=0 or still has ref)
      // After remove, reference_count becomes 0, but row stays.
      const n = r.gcOrphanPhotoRefs();
      expect(n >= 1).assertTrue();
    });

    it('rdb_gcOrphan_skips_referenced_photos', 0, (): void => {
      const r = repo as RepositoryImpl;
      const pid = r.createPerson({ displayName: 'RefP' });
      r.addPhotoForPerson(pid, 'file://tier1/ref-photo');
      const n = r.gcOrphanPhotoRefs();
      expect(n).assertEqual(0);
      expect(r.photosForPerson(pid).length).assertEqual(1);
    });

    it('rdb_gcOrphan_no_orphans_return_0', 0, (): void => {
      const r = repo as RepositoryImpl;
      expect(r.gcOrphanPhotoRefs()).assertEqual(0);
    });

    // ── [SLOW] T-29 (C-8) ST-07 超上限阻断（RDB 层） ──────

    it('rdb_addPhoto_story_cap_limit', 0, (): void => {
      const r = repo as RepositoryImpl;
      const sid = r.createStory('CapStory');
      expect(sid > 0).assertTrue();
      // 通过闭包中的 store 变量直接 SQL 批量造 1000 条 link
      const s = store as relationalStore.RdbStore;
      for (let i = 0; i < 1000; i++) {
        const uri = `file://tier1/cap-batch-${i}`;
        const prVb: relationalStore.ValuesBucket = {
          uri: uri,
          added_at: Date.now(),
          ref_status: 1,
          reference_count: 1,
          is_referenced: 1
        };
        const prId = s.insertSync('photo_ref', prVb, relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
        if (prId > 0) {
          const linkVb: relationalStore.ValuesBucket = {
            owner_kind: 1,
            owner_id: sid,
            photo_ref_id: prId,
            linked_at: Date.now() + i,
            sort_key: Date.now() + i
          };
          s.insertSync('photo_owner_link', linkVb, relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
        }
      }
      // 第 1001 条通过正常 API 应被阻断
      const res = r.addPhotoForStory(sid, 'file://tier1/cap-1001');
      expect(res.success).assertFalse();
      expect(res.duplicate).assertFalse();
    });
  });
}