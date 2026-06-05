import { afterAll, beforeAll, describe, expect, it } from '@ohos/hypium';
import type { IPersonService } from '../../../main/ets/features/api/Services';
import { PersonService } from '../../../main/ets/features/person/PersonFeature';
import { GenderEnum, PersonTypeEnum } from '../../../main/ets/domain/model/Models';
import { ServiceTestContext } from './utils/ServiceTestContext';
import { TestDataFactory } from './utils/TestDataFactory';

export default function l3PersonService(): void {
  describe('L3_personService', () => {
    const ctx = new ServiceTestContext<IPersonService>((repo) => new PersonService(repo));

    beforeAll(async () => {
      await ctx.setup();
    });

    afterAll(async () => {
      await ctx.teardown();
    });

    it('L3_personService_createPerson_success', 0, (): void => {
      const svc = ctx.getService();
      const id = svc.createPerson(TestDataFactory.uniqueName('Alice'));
      expect(id > 0).assertTrue();
    });

    it('L3_personService_createPerson_rejects_blank', 0, (): void => {
      const svc = ctx.getService();
      expect(svc.createPerson('   ')).assertEqual(-1);
      expect(svc.createPerson('\t\n')).assertEqual(-1);
      expect(svc.createPerson('')).assertEqual(-1);
    });

    it('L3_personService_createPerson_trims_name', 0, (): void => {
      const svc = ctx.getService();
      const id = svc.createPerson('  Bob  ');
      expect(id > 0).assertTrue();
      const p = svc.getPerson(id);
      expect(p !== null).assertTrue();
      expect(p!.displayName).assertEqual('Bob');
    });

    it('L3_personService_createPerson_with_all_fields', 0, (): void => {
      const svc = ctx.getService();
      const now = Date.now();
      const avatar = new Uint8Array([0x89, 0x50, 0x4E, 0x47]);
      const id = svc.createPerson(
        TestDataFactory.uniqueName('FullFields'),
        avatar,
        now,
        GenderEnum.UNSPECIFIED,
        'test remark',
        PersonTypeEnum.BABY
      );
      expect(id > 0).assertTrue();
      const p = svc.getPerson(id);
      expect(p !== null).assertTrue();
      expect(p!.displayName.length > 0).assertTrue();
      expect(p!.avatarBlob !== null).assertTrue();
      expect(p!.avatarBlob!.length).assertEqual(4);
      expect(p!.birthday).assertEqual(now);
      expect(p!.gender).assertEqual(GenderEnum.UNSPECIFIED);
      expect(p!.remark).assertEqual('test remark');
      expect(p!.personType).assertEqual(PersonTypeEnum.BABY);
    });

    it('L3_personService_createPerson_defaults', 0, (): void => {
      const svc = ctx.getService();
      const id = svc.createPerson(TestDataFactory.uniqueName('MinFields'));
      expect(id > 0).assertTrue();
      const p = svc.getPerson(id);
      expect(p !== null).assertTrue();
      expect(p!.avatarBlob === null).assertTrue();
      expect(p!.birthday === null).assertTrue();
      expect(p!.gender === null).assertTrue();
      expect(p!.remark).assertEqual('');
      expect(p!.personType).assertEqual(PersonTypeEnum.OTHER);
    });

    it('L3_personService_getPerson_exists', 0, (): void => {
      const svc = ctx.getService();
      const name = TestDataFactory.uniqueName('GetP');
      const id = svc.createPerson(name);
      const p = svc.getPerson(id);
      expect(p !== null).assertTrue();
      expect(p!.id).assertEqual(id);
      expect(p!.displayName).assertEqual(name);
    });

    it('L3_personService_getPerson_missing', 0, (): void => {
      const svc = ctx.getService();
      expect(svc.getPerson(999999999) === null).assertTrue();
    });

    it('L3_personService_listPersons_newest_first', 0, async (): Promise<void> => {
      const svc = ctx.getService();
      const idA = svc.createPerson(TestDataFactory.uniqueName('ListA'));
      await new Promise<void>((r) => setTimeout(r, 15));
      const idB = svc.createPerson(TestDataFactory.uniqueName('ListB'));
      expect(idA > 0 && idB > 0).assertTrue();
      const list = svc.listPersons();
      const found = list.filter((p) => p.id === idA || p.id === idB);
      expect(found.length >= 2).assertTrue();
      expect(found[0].id).assertEqual(idB);
    });

    it('L3_personService_listPersons_empty', 0, (): void => {
      const svc = ctx.getService();
      const list = svc.listPersons();
      expect(Array.isArray(list)).assertTrue();
    });

    it('L3_personService_updatePerson_success', 0, (): void => {
      const svc = ctx.getService();
      const id = svc.createPerson(TestDataFactory.uniqueName('UpdP'));
      expect(id > 0).assertTrue();
      const newName = TestDataFactory.uniqueName('UpdPNew');
      expect(svc.updatePerson(id, newName)).assertTrue();
      const p = svc.getPerson(id);
      expect(p !== null).assertTrue();
      expect(p!.displayName).assertEqual(newName);
    });

    it('L3_personService_updatePerson_rejects_blank', 0, (): void => {
      const svc = ctx.getService();
      const id = svc.createPerson(TestDataFactory.uniqueName('BlankUpd'));
      expect(svc.updatePerson(id, '  ')).assertFalse();
    });

    it('L3_personService_updatePerson_birthday_set_clear', 0, (): void => {
      const svc = ctx.getService();
      const id = svc.createPerson(TestDataFactory.uniqueName('BirthP'));
      const ts = 946684800000;
      expect(svc.updatePerson(id, TestDataFactory.uniqueName('BirthP'), undefined, ts)).assertTrue();
      let p = svc.getPerson(id);
      expect(p!.birthday).assertEqual(ts);
      expect(svc.updatePerson(id, TestDataFactory.uniqueName('BirthP'), undefined, null)).assertTrue();
      p = svc.getPerson(id);
      expect(p!.birthday === null).assertTrue();
    });

    it('L3_personService_updatePerson_gender_change', 0, (): void => {
      const svc = ctx.getService();
      const id = svc.createPerson(TestDataFactory.uniqueName('GenderP'));
      expect(svc.updatePerson(id, TestDataFactory.uniqueName('GenderP'), undefined, undefined, GenderEnum.MALE)).assertTrue();
      expect(svc.getPerson(id)!.gender).assertEqual(GenderEnum.MALE);
      expect(svc.updatePerson(id, TestDataFactory.uniqueName('GenderP'), undefined, undefined, GenderEnum.FEMALE)).assertTrue();
      expect(svc.getPerson(id)!.gender).assertEqual(GenderEnum.FEMALE);
    });

    it('L3_personService_updatePerson_remark_and_type', 0, (): void => {
      const svc = ctx.getService();
      const id = svc.createPerson(TestDataFactory.uniqueName('RmkType'));
      expect(svc.updatePerson(id, TestDataFactory.uniqueName('RmkType'), undefined, undefined, undefined, 'new note', PersonTypeEnum.ELDER)).assertTrue();
      const p = svc.getPerson(id);
      expect(p!.remark).assertEqual('new note');
      expect(p!.personType).assertEqual(PersonTypeEnum.ELDER);
    });

    it('L3_personService_updatePerson_empty_params_returns_true', 0, (): void => {
      const svc = ctx.getService();
      const id = svc.createPerson(TestDataFactory.uniqueName('EmptyUpd'));
      const name = svc.getPerson(id)!.displayName;
      expect(svc.updatePerson(id, name)).assertTrue();
    });

    it('L3_personService_updatePerson_nonexistent_id', 0, (): void => {
      const svc = ctx.getService();
      const result = svc.updatePerson(999999999, 'Ghost');
      expect(result).assertTrue();
    });

    it('L3_personService_deletePerson_success', 0, (): void => {
      const svc = ctx.getService();
      const id = svc.createPerson(TestDataFactory.uniqueName('DelP'));
      expect(id > 0).assertTrue();
      expect(svc.deletePerson(id)).assertTrue();
      expect(svc.getPerson(id) === null).assertTrue();
    });

    it('L3_personService_deletePerson_cascade', 0, (): void => {
      const svc = ctx.getService();
      const pid = svc.createPerson(TestDataFactory.uniqueName('CascadeP'));
      const repo = ctx.getRepo();
      const sid = repo.createStory(TestDataFactory.createStoryTitle());
      svc.linkPersonToStory(pid, sid);
      svc.addPhotoToPerson(pid, TestDataFactory.createPhotoUri());
      expect(svc.deletePerson(pid)).assertTrue();
      expect(svc.getPerson(pid) === null).assertTrue();
      expect(svc.isLinked(pid, sid)).assertFalse();
      expect(svc.listPersonPhotos(pid).length).assertEqual(0);
    });

    it('L3_personService_deletePerson_nonexistent', 0, (): void => {
      const svc = ctx.getService();
      expect(svc.deletePerson(999999999)).assertFalse();
    });

    it('L3_personService_linkPersonToStory_success', 0, (): void => {
      const svc = ctx.getService();
      const repo = ctx.getRepo();
      const pid = svc.createPerson(TestDataFactory.uniqueName('LinkP'));
      const sid = repo.createStory(TestDataFactory.createStoryTitle());
      svc.linkPersonToStory(pid, sid);
      expect(svc.isLinked(pid, sid)).assertTrue();
    });

    it('L3_personService_unlinkPersonFromStory', 0, (): void => {
      const svc = ctx.getService();
      const repo = ctx.getRepo();
      const pid = svc.createPerson(TestDataFactory.uniqueName('UnlinkP'));
      const sid = repo.createStory(TestDataFactory.createStoryTitle());
      svc.linkPersonToStory(pid, sid);
      expect(svc.isLinked(pid, sid)).assertTrue();
      svc.unlinkPersonFromStory(pid, sid);
      expect(svc.isLinked(pid, sid)).assertFalse();
    });

    it('L3_personService_isLinked_true_false', 0, (): void => {
      const svc = ctx.getService();
      const repo = ctx.getRepo();
      const pid = svc.createPerson(TestDataFactory.uniqueName('IsLinkP'));
      const sid = repo.createStory(TestDataFactory.createStoryTitle());
      expect(svc.isLinked(pid, sid)).assertFalse();
      svc.linkPersonToStory(pid, sid);
      expect(svc.isLinked(pid, sid)).assertTrue();
    });

    it('L3_personService_listLinkedStories', 0, (): void => {
      const svc = ctx.getService();
      const repo = ctx.getRepo();
      const pid = svc.createPerson(TestDataFactory.uniqueName('ListLinkP'));
      const s1 = repo.createStory(TestDataFactory.createStoryTitle());
      const s2 = repo.createStory(TestDataFactory.createStoryTitle());
      svc.linkPersonToStory(pid, s1);
      svc.linkPersonToStory(pid, s2);
      const stories = svc.listLinkedStories(pid);
      expect(stories.length).assertEqual(2);
    });

    it('L3_personService_listLinkedStories_empty', 0, (): void => {
      const svc = ctx.getService();
      const pid = svc.createPerson(TestDataFactory.uniqueName('NoLinkP'));
      const stories = svc.listLinkedStories(pid);
      expect(stories.length).assertEqual(0);
    });

    it('L3_personService_addPhotoToPerson_success', 0, (): void => {
      const svc = ctx.getService();
      const pid = svc.createPerson(TestDataFactory.uniqueName('PhotoP'));
      const uri = TestDataFactory.createPhotoUri();
      const res = svc.addPhotoToPerson(pid, uri);
      expect(res.success).assertTrue();
      expect(res.duplicate).assertFalse();
      const photos = svc.listPersonPhotos(pid);
      expect(photos.length).assertEqual(1);
      expect(photos[0].uri).assertEqual(uri);
    });

    it('L3_personService_addPhotoToPerson_duplicate', 0, (): void => {
      const svc = ctx.getService();
      const pid = svc.createPerson(TestDataFactory.uniqueName('DupP'));
      const uri = TestDataFactory.createPhotoUri();
      const a1 = svc.addPhotoToPerson(pid, uri);
      expect(a1.success).assertTrue();
      const a2 = svc.addPhotoToPerson(pid, uri);
      expect(a2.success).assertFalse();
      expect(a2.duplicate).assertTrue();
    });

    it('L3_personService_addPhotoToPerson_with_metadata', 0, (): void => {
      const svc = ctx.getService();
      const pid = svc.createPerson(TestDataFactory.uniqueName('MetaP'));
      const uri = TestDataFactory.createPhotoUri();
      const takenAt = 1700000000000;
      const res = svc.addPhotoToPerson(pid, uri, { takenAt });
      expect(res.success).assertTrue();
      const photos = svc.listPersonPhotos(pid);
      expect(photos.length).assertEqual(1);
      expect(photos[0].metadata !== undefined).assertTrue();
      expect(photos[0].metadata!.takenAt).assertEqual(takenAt);
    });

    it('L3_personService_removePhotoFromPerson', 0, (): void => {
      const svc = ctx.getService();
      const pid = svc.createPerson(TestDataFactory.uniqueName('RmPhotoP'));
      const uri = TestDataFactory.createPhotoUri();
      svc.addPhotoToPerson(pid, uri);
      const photos = svc.listPersonPhotos(pid);
      expect(photos.length).assertEqual(1);
      expect(svc.removePhotoFromPerson(pid, photos[0].id)).assertTrue();
      expect(svc.listPersonPhotos(pid).length).assertEqual(0);
    });
  });
}
