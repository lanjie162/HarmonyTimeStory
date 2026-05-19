import { relationalStore } from '@kit.ArkData';
import type { IAppDataStore } from '../api/AppDataStore';
import type { PersonModel, PhotoAddResult, PhotoRefModel, StoryModel } from '../../domain/model/Models';
import { requireTrimmedNonEmpty } from './RepositoryTextNormalize';

const OWN_STORY = 1;
const OWN_PERSON = 2;
const STORY_PHOTO_CAP = 1000;

function nowMs(): number {
  return Date.now();
}

function changesCount(store: relationalStore.RdbStore): number {
  const rs = store.querySqlSync('SELECT changes() AS c;', []);
  let n = 0;
  if (rs.goToFirstRow()) {
    n = Number(rs.getLong(rs.getColumnIndex('c')));
  }
  rs.close();
  return n;
}

/**
 * RDB 真相实现：与 `document/techdoc/时光故事-MVP技术方案-v1.md` §4 对齐的最小子集
 *（Person/Story/PersonStory/PhotoRef/PhotoOwnerLink + reference_count 维护 + ST-07）。
 */
export class RepositoryImpl implements IAppDataStore {
  private static instance: RepositoryImpl | undefined;
  private rdb: relationalStore.RdbStore | undefined;

  static getInstance(): RepositoryImpl {
    if (RepositoryImpl.instance === undefined) {
      RepositoryImpl.instance = new RepositoryImpl();
    }
    return RepositoryImpl.instance;
  }

  attachRdb(store: relationalStore.RdbStore): void {
    this.rdb = store;
  }

  private db(): relationalStore.RdbStore {
    if (this.rdb === undefined) {
      throw new Error('RepositoryImpl: RdbStore not attached');
    }
    return this.rdb;
  }

  listPersons(): PersonModel[] {
    const store = this.db();
    const rs = store.querySqlSync(
      'SELECT id, display_name FROM person ORDER BY updated_at DESC;',
      []
    );
    const out: PersonModel[] = [];
    while (rs.goToNextRow()) {
      out.push({
        id: Number(rs.getLong(rs.getColumnIndex('id'))),
        displayName: rs.getString(rs.getColumnIndex('display_name'))
      });
    }
    rs.close();
    return out;
  }

  createPerson(displayName: string): number {
    const t = requireTrimmedNonEmpty(displayName);
    if (t === null) {
      return -1;
    }
    const store = this.db();
    const ts = nowMs();
    const vb: relationalStore.ValuesBucket = {
      display_name: t,
      created_at: ts,
      updated_at: ts
    };
    const rowId = store.insertSync('person', vb, relationalStore.ConflictResolution.ON_CONFLICT_ROLLBACK);
    return rowId > 0 ? rowId : -1;
  }

  getPerson(id: number): PersonModel | null {
    const store = this.db();
    const rs = store.querySqlSync('SELECT id, display_name FROM person WHERE id = ?;', [id]);
    let p: PersonModel | null = null;
    if (rs.goToFirstRow()) {
      p = {
        id: Number(rs.getLong(rs.getColumnIndex('id'))),
        displayName: rs.getString(rs.getColumnIndex('display_name'))
      };
    }
    rs.close();
    return p;
  }

  updatePerson(id: number, displayName: string): boolean {
    const t = requireTrimmedNonEmpty(displayName);
    if (t === null) {
      return false;
    }
    const store = this.db();
    store.executeSql('UPDATE person SET display_name = ?, updated_at = ? WHERE id = ?;', [t, nowMs(), id]);
    return changesCount(store) > 0;
  }

  listStories(): StoryModel[] {
    const store = this.db();
    const rs = store.querySqlSync('SELECT id, title FROM story ORDER BY updated_at DESC;', []);
    const out: StoryModel[] = [];
    while (rs.goToNextRow()) {
      out.push({
        id: Number(rs.getLong(rs.getColumnIndex('id'))),
        title: rs.getString(rs.getColumnIndex('title'))
      });
    }
    rs.close();
    return out;
  }

  createStory(title: string): number {
    const t = requireTrimmedNonEmpty(title);
    if (t === null) {
      return -1;
    }
    const store = this.db();
    const ts = nowMs();
    const vb: relationalStore.ValuesBucket = {
      title: t,
      created_at: ts,
      updated_at: ts
    };
    const rowId = store.insertSync('story', vb, relationalStore.ConflictResolution.ON_CONFLICT_ROLLBACK);
    return rowId > 0 ? rowId : -1;
  }

  getStory(id: number): StoryModel | null {
    const store = this.db();
    const rs = store.querySqlSync('SELECT id, title FROM story WHERE id = ?;', [id]);
    let s: StoryModel | null = null;
    if (rs.goToFirstRow()) {
      s = {
        id: Number(rs.getLong(rs.getColumnIndex('id'))),
        title: rs.getString(rs.getColumnIndex('title'))
      };
    }
    rs.close();
    return s;
  }

  updateStory(id: number, title: string): boolean {
    const t = requireTrimmedNonEmpty(title);
    if (t === null) {
      return false;
    }
    const store = this.db();
    store.executeSql('UPDATE story SET title = ?, updated_at = ? WHERE id = ?;', [t, nowMs(), id]);
    return changesCount(store) > 0;
  }

  linkedPersonsForStory(storyId: number): PersonModel[] {
    const store = this.db();
    const rs = store.querySqlSync(
      'SELECT p.id AS id, p.display_name AS display_name FROM person p ' +
        'INNER JOIN person_story ps ON ps.person_id = p.id WHERE ps.story_id = ? ORDER BY p.updated_at DESC;',
      [storyId]
    );
    const out: PersonModel[] = [];
    while (rs.goToNextRow()) {
      out.push({
        id: Number(rs.getLong(rs.getColumnIndex('id'))),
        displayName: rs.getString(rs.getColumnIndex('display_name'))
      });
    }
    rs.close();
    return out;
  }

  linkPersonStory(personId: number, storyId: number): void {
    const store = this.db();
    const p = this.getPerson(personId);
    const s = this.getStory(storyId);
    if (p === null || s === null) {
      return;
    }
    const chk = store.querySqlSync(
      'SELECT 1 FROM person_story WHERE person_id = ? AND story_id = ? LIMIT 1;',
      [personId, storyId]
    );
    if (chk.goToFirstRow()) {
      chk.close();
      return;
    }
    chk.close();
    const vb: relationalStore.ValuesBucket = {
      person_id: personId,
      story_id: storyId
    };
    store.insertSync('person_story', vb, relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
  }

  unlinkPersonStory(personId: number, storyId: number): void {
    const store = this.db();
    store.executeSql('DELETE FROM person_story WHERE person_id = ? AND story_id = ?;', [personId, storyId]);
  }

  linkedStoriesForPerson(personId: number): StoryModel[] {
    const store = this.db();
    const rs = store.querySqlSync(
      'SELECT s.id AS id, s.title AS title FROM story s ' +
        'INNER JOIN person_story ps ON ps.story_id = s.id WHERE ps.person_id = ? ORDER BY s.updated_at DESC;',
      [personId]
    );
    const out: StoryModel[] = [];
    while (rs.goToNextRow()) {
      out.push({
        id: Number(rs.getLong(rs.getColumnIndex('id'))),
        title: rs.getString(rs.getColumnIndex('title'))
      });
    }
    rs.close();
    return out;
  }

  isPersonStoryLinked(personId: number, storyId: number): boolean {
    const store = this.db();
    const rs = store.querySqlSync(
      'SELECT 1 FROM person_story WHERE person_id = ? AND story_id = ? LIMIT 1;',
      [personId, storyId]
    );
    const ok = rs.goToFirstRow();
    rs.close();
    return ok;
  }

  photosForPerson(personId: number): PhotoRefModel[] {
    return this.queryPhotosForOwner(OWN_PERSON, personId);
  }

  addPhotoForPerson(personId: number, uri: string): PhotoAddResult {
    return this.addPhotoForOwner(OWN_PERSON, personId, uri, false);
  }

  photosForStory(storyId: number): PhotoRefModel[] {
    return this.queryPhotosForOwner(OWN_STORY, storyId);
  }

  addPhotoForStory(storyId: number, uri: string): PhotoAddResult {
    return this.addPhotoForOwner(OWN_STORY, storyId, uri, true);
  }

  private queryPhotosForOwner(ownerKind: number, ownerId: number): PhotoRefModel[] {
    const store = this.db();
    const rs = store.querySqlSync(
      'SELECT pr.id AS id, pr.uri AS uri FROM photo_ref pr ' +
        'INNER JOIN photo_owner_link pol ON pol.photo_ref_id = pr.id ' +
        'WHERE pol.owner_kind = ? AND pol.owner_id = ? ORDER BY pol.linked_at DESC;',
      [ownerKind, ownerId]
    );
    const out: PhotoRefModel[] = [];
    while (rs.goToNextRow()) {
      out.push({
        id: Number(rs.getLong(rs.getColumnIndex('id'))),
        uri: rs.getString(rs.getColumnIndex('uri'))
      });
    }
    rs.close();
    return out;
  }

  private resolveOrCreatePhotoRef(store: relationalStore.RdbStore, uri: string): number {
    const rs = store.querySqlSync('SELECT id FROM photo_ref WHERE uri = ? LIMIT 1;', [uri]);
    let id = -1;
    if (rs.goToFirstRow()) {
      id = Number(rs.getLong(rs.getColumnIndex('id')));
    }
    rs.close();
    if (id > 0) {
      return id;
    }
    const ts = nowMs();
    const vb: relationalStore.ValuesBucket = {
      uri: uri,
      added_at: ts,
      ref_status: 1,
      reference_count: 0,
      is_referenced: 0
    };
    const ins = store.insertSync('photo_ref', vb, relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
    if (ins > 0) {
      return ins;
    }
    const rs2 = store.querySqlSync('SELECT id FROM photo_ref WHERE uri = ? LIMIT 1;', [uri]);
    let id2 = -1;
    if (rs2.goToFirstRow()) {
      id2 = Number(rs2.getLong(rs2.getColumnIndex('id')));
    }
    rs2.close();
    return id2;
  }

  private addPhotoForOwner(ownerKind: number, ownerId: number, uri: string, enforceStoryCap: boolean): PhotoAddResult {
    const trimmed = requireTrimmedNonEmpty(uri);
    if (trimmed === null) {
      return { success: false, duplicate: false };
    }
    if (ownerKind === OWN_PERSON && this.getPerson(ownerId) === null) {
      return { success: false, duplicate: false };
    }
    if (ownerKind === OWN_STORY && this.getStory(ownerId) === null) {
      return { success: false, duplicate: false };
    }
    const existing = this.queryPhotosForOwner(ownerKind, ownerId);
    if (existing.some((p): boolean => p.uri === trimmed)) {
      return { success: false, duplicate: true };
    }

    const store = this.db();
    try {
      store.beginTransaction();
      if (enforceStoryCap) {
        const cRs = store.querySqlSync(
          'SELECT COUNT(*) AS c FROM photo_owner_link WHERE owner_kind = ? AND owner_id = ?;',
          [OWN_STORY, ownerId]
        );
        let cnt = 0;
        if (cRs.goToFirstRow()) {
          cnt = Number(cRs.getLong(cRs.getColumnIndex('c')));
        }
        cRs.close();
        if (cnt >= STORY_PHOTO_CAP) {
          store.rollBack();
          return { success: false, duplicate: false };
        }
      }

      const photoRefId = this.resolveOrCreatePhotoRef(store, trimmed);
      if (photoRefId <= 0) {
        store.rollBack();
        return { success: false, duplicate: false };
      }

      const dupL = store.querySqlSync(
        'SELECT 1 FROM photo_owner_link WHERE owner_kind = ? AND owner_id = ? AND photo_ref_id = ? LIMIT 1;',
        [ownerKind, ownerId, photoRefId]
      );
      if (dupL.goToFirstRow()) {
        dupL.close();
        store.rollBack();
        return { success: false, duplicate: true };
      }
      dupL.close();

      const linkedAt = nowMs();
      const linkVb: relationalStore.ValuesBucket = {
        owner_kind: ownerKind,
        owner_id: ownerId,
        photo_ref_id: photoRefId,
        linked_at: linkedAt,
        sort_key: linkedAt
      };
      const linkRow = store.insertSync(
        'photo_owner_link',
        linkVb,
        relationalStore.ConflictResolution.ON_CONFLICT_ROLLBACK
      );
      if (linkRow <= 0) {
        store.rollBack();
        return { success: false, duplicate: false };
      }

      store.executeSql(
        'UPDATE photo_ref SET reference_count = reference_count + 1, is_referenced = 1 WHERE id = ?;',
        [photoRefId]
      );

      store.commit();
      return { success: true, duplicate: false };
    } catch (_e) {
      store.rollBack();
      return { success: false, duplicate: false };
    }
  }
}
