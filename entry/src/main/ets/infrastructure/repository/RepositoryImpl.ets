import { relationalStore } from '@kit.ArkData';
import type { CreatePersonParams, IAppDataStore, UpdatePersonParams, UpdateStoryParams } from '../api/AppDataStore';
import type { GenderEnum, PersonModel, PersonTypeEnum, PhotoAddResult, PhotoRefModel, StoryModel } from '../../domain/model/Models';
import { requireTrimmedNonEmpty } from './RepositoryTextNormalize';

function parseTags(raw: string | null): string[] {
  if (raw === null || raw.length === 0) {
    return [];
  }
  // JSON.parse returns 'any' which ArkTS blocks, so manual parse for string arrays
  const out: string[] = [];
  let trimmed = raw.trim();
  if (trimmed.length < 2 || trimmed[0] !== '[' || trimmed[trimmed.length - 1] !== ']') {
    return out;
  }
  const inner = trimmed.substring(1, trimmed.length - 1).trim();
  if (inner.length === 0) {
    return out;
  }
  let i = 0;
  while (i < inner.length) {
    // skip whitespace
    while (i < inner.length && (inner[i] === ' ' || inner[i] === '\t' || inner[i] === '\n')) {
      i++;
    }
    if (i >= inner.length) {
      break;
    }
    if (inner[i] !== '"') {
      return out; // unexpected format
    }
    i++; // skip opening quote
    let token = '';
    while (i < inner.length && inner[i] !== '"') {
      if (inner[i] === '\\') {
        i++;
        if (i < inner.length) {
          token += inner[i];
          i++;
        }
      } else {
        token += inner[i];
        i++;
      }
    }
    if (i < inner.length) {
      i++; // skip closing quote
    }
    out.push(token);
    // skip whitespace and comma
    while (i < inner.length && (inner[i] === ' ' || inner[i] === '\t' || inner[i] === '\n')) {
      i++;
    }
    if (i < inner.length && inner[i] === ',') {
      i++;
    }
  }
  return out;
}

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

  private rowToPerson(rs: relationalStore.ResultSet): PersonModel {
    const id = Number(rs.getLong(rs.getColumnIndex('id')));
    const displayName = rs.getString(rs.getColumnIndex('display_name'));
    const avatarBlob = rs.getBlob(rs.getColumnIndex('avatar_blob'));
    const birthdayRaw = rs.getLong(rs.getColumnIndex('birthday'));
    const genderRaw = rs.getLong(rs.getColumnIndex('gender'));
    const remark = rs.getString(rs.getColumnIndex('remark')) ?? '';
    const personTypeRaw = Number(rs.getLong(rs.getColumnIndex('person_type')));
    const updatedAt = Number(rs.getLong(rs.getColumnIndex('updated_at')));
    return {
      id,
      displayName,
      avatarBlob: avatarBlob ?? null,
      birthday: birthdayRaw !== null ? Number(birthdayRaw) : null,
      gender: genderRaw !== null ? (Number(genderRaw) as GenderEnum) : null,
      remark,
      personType: personTypeRaw as PersonTypeEnum,
      updatedAt
    };
  }

  private rowToStory(rs: relationalStore.ResultSet): StoryModel {
    const id = Number(rs.getLong(rs.getColumnIndex('id')));
    const title = rs.getString(rs.getColumnIndex('title')) ?? '';
    const description = rs.getString(rs.getColumnIndex('description')) ?? '';
    const timeStartRaw = rs.getLong(rs.getColumnIndex('time_start'));
    const timeEndRaw = rs.getLong(rs.getColumnIndex('time_end'));
    const coverUri = rs.getString(rs.getColumnIndex('cover_uri')) ?? '';
    const location = rs.getString(rs.getColumnIndex('location')) ?? '';
    const tagsRaw = rs.getString(rs.getColumnIndex('tags'));
    return {
      id,
      title,
      description,
      timeStart: timeStartRaw !== null ? Number(timeStartRaw) : null,
      timeEnd: timeEndRaw !== null ? Number(timeEndRaw) : null,
      coverUri,
      location,
      tags: parseTags(tagsRaw)
    };
  }

  listPersons(): PersonModel[] {
    const store = this.db();
    const rs = store.querySqlSync(
      'SELECT id, display_name, avatar_blob, birthday, gender, remark, person_type, updated_at ' +
        'FROM person ORDER BY updated_at DESC;',
      []
    );
    const out: PersonModel[] = [];
    while (rs.goToNextRow()) {
      out.push(this.rowToPerson(rs));
    }
    rs.close();
    return out;
  }

  createPerson(params: CreatePersonParams): number {
    const t = requireTrimmedNonEmpty(params.displayName);
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
    if (params.avatarBlob !== undefined) {
      vb['avatar_blob'] = params.avatarBlob;
    }
    if (params.birthday !== undefined) {
      vb['birthday'] = params.birthday;
    }
    if (params.gender !== undefined) {
      vb['gender'] = params.gender;
    }
    if (params.remark !== undefined) {
      vb['remark'] = params.remark;
    }
    if (params.personType !== undefined) {
      vb['person_type'] = params.personType;
    }
    const rowId = store.insertSync('person', vb, relationalStore.ConflictResolution.ON_CONFLICT_ROLLBACK);
    return rowId > 0 ? rowId : -1;
  }

  getPerson(id: number): PersonModel | null {
    const store = this.db();
    const rs = store.querySqlSync(
      'SELECT id, display_name, avatar_blob, birthday, gender, remark, person_type, updated_at FROM person WHERE id = ?;',
      [id]
    );
    let p: PersonModel | null = null;
    if (rs.goToFirstRow()) {
      p = this.rowToPerson(rs);
    }
    rs.close();
    return p;
  }

  updatePerson(id: number, params: UpdatePersonParams): boolean {
    const store = this.db();
    const setClauses: string[] = ['updated_at = ?'];
    const bindArgs: relationalStore.ValueType[] = [nowMs()];

    // displayName 有特殊校验：非空 + trim
    if (params.displayName !== undefined) {
      const t = requireTrimmedNonEmpty(params.displayName);
      if (t === null) {
        return false;
      }
      setClauses.push('display_name = ?');
      bindArgs.push(t);
    }
    if (params.avatarBlob !== undefined) {
      setClauses.push('avatar_blob = ?');
      bindArgs.push(params.avatarBlob as Uint8Array);
    }
    if (params.birthday !== undefined) {
      setClauses.push('birthday = ?');
      bindArgs.push(params.birthday);
    }
    if (params.gender !== undefined) {
      setClauses.push('gender = ?');
      bindArgs.push(params.gender);
    }
    if (params.remark !== undefined) {
      setClauses.push('remark = ?');
      bindArgs.push(params.remark);
    }
    if (params.personType !== undefined) {
      setClauses.push('person_type = ?');
      bindArgs.push(params.personType);
    }
    bindArgs.push(id);
    store.executeSql(
      `UPDATE person SET ${setClauses.join(', ')} WHERE id = ?;`,
      bindArgs
    );
    return changesCount(store) > 0;
  }

  listStories(): StoryModel[] {
    const store = this.db();
    const rs = store.querySqlSync(
      'SELECT id, title, description, time_start, time_end, cover_uri, location, tags ' +
        'FROM story ORDER BY updated_at DESC;',
      []
    );
    const out: StoryModel[] = [];
    while (rs.goToNextRow()) {
      out.push(this.rowToStory(rs));
    }
    rs.close();
    return out;
  }

  createStory(title: string, description?: string, timeStart?: number | null, timeEnd?: number | null, coverUri?: string, location?: string, tags?: string[]): number {
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
    if (description !== undefined) {
      vb['description'] = description;
    }
    if (timeStart !== undefined) {
      vb['time_start'] = timeStart;
    }
    if (timeEnd !== undefined) {
      vb['time_end'] = timeEnd;
    }
    if (coverUri !== undefined) {
      vb['cover_uri'] = coverUri;
    }
    if (location !== undefined) {
      vb['location'] = location;
    }
    if (tags !== undefined) {
      vb['tags'] = JSON.stringify(tags);
    }
    const rowId = store.insertSync('story', vb, relationalStore.ConflictResolution.ON_CONFLICT_ROLLBACK);
    return rowId > 0 ? rowId : -1;
  }

  getStory(id: number): StoryModel | null {
    const store = this.db();
    const rs = store.querySqlSync(
      'SELECT id, title, description, time_start, time_end, cover_uri, location, tags ' +
        'FROM story WHERE id = ?;',
      [id]
    );
    let s: StoryModel | null = null;
    if (rs.goToFirstRow()) {
      s = this.rowToStory(rs);
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

  updateStoryAll(id: number, params: UpdateStoryParams): boolean {
    const store = this.db();
    const setClauses: string[] = ['updated_at = ?'];
    const bindArgs: relationalStore.ValueType[] = [nowMs()];

    if (params.title !== undefined) {
      const t = requireTrimmedNonEmpty(params.title);
      if (t === null) {
        return false;
      }
      setClauses.push('title = ?');
      bindArgs.push(t);
    }
    if (params.description !== undefined) {
      setClauses.push('description = ?');
      bindArgs.push(params.description);
    }
    if (params.timeStart !== undefined) {
      setClauses.push('time_start = ?');
      bindArgs.push(params.timeStart);
    }
    if (params.timeEnd !== undefined) {
      setClauses.push('time_end = ?');
      bindArgs.push(params.timeEnd);
    }
    if (params.coverUri !== undefined) {
      setClauses.push('cover_uri = ?');
      bindArgs.push(params.coverUri);
    }
    if (params.location !== undefined) {
      setClauses.push('location = ?');
      bindArgs.push(params.location);
    }
    if (params.tags !== undefined) {
      setClauses.push('tags = ?');
      bindArgs.push(JSON.stringify(params.tags));
    }
    bindArgs.push(id);
    store.executeSql(
      `UPDATE story SET ${setClauses.join(', ')} WHERE id = ?;`,
      bindArgs
    );
    return changesCount(store) > 0;
  }

  linkedPersonsForStory(storyId: number): PersonModel[] {
    const store = this.db();
    const rs = store.querySqlSync(
      'SELECT p.id AS id, p.display_name AS display_name, p.avatar_blob, p.birthday, p.gender, p.remark, p.person_type, p.updated_at ' +
        'FROM person p ' +
        'INNER JOIN person_story ps ON ps.person_id = p.id WHERE ps.story_id = ? ORDER BY p.updated_at DESC;',
      [storyId]
    );
    const out: PersonModel[] = [];
    while (rs.goToNextRow()) {
      out.push(this.rowToPerson(rs));
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
      'SELECT s.id AS id, s.title AS title, s.description, s.time_start, s.time_end, s.cover_uri, s.location, s.tags ' +
        'FROM story s ' +
        'INNER JOIN person_story ps ON ps.story_id = s.id WHERE ps.person_id = ? ORDER BY s.updated_at DESC;',
      [personId]
    );
    const out: StoryModel[] = [];
    while (rs.goToNextRow()) {
      out.push(this.rowToStory(rs));
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
      'SELECT pr.id AS id, pr.uri AS uri, pr.ref_status AS ref_status FROM photo_ref pr ' +
        'INNER JOIN photo_owner_link pol ON pol.photo_ref_id = pr.id ' +
        'WHERE pol.owner_kind = ? AND pol.owner_id = ? ORDER BY pr.taken_at_cache DESC NULLS LAST, pol.linked_at DESC;',
      [ownerKind, ownerId]
    );
    const out: PhotoRefModel[] = [];
    while (rs.goToNextRow()) {
      out.push({
        id: Number(rs.getLong(rs.getColumnIndex('id'))),
        uri: rs.getString(rs.getColumnIndex('uri')),
        refStatus: Number(rs.getLong(rs.getColumnIndex('ref_status')))
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

  deletePerson(id: number): boolean {
    const store = this.db();
    const p = this.getPerson(id);
    if (p === null) {
      return false;
    }
    try {
      store.beginTransaction();
      // Collect affected photo_ref ids before deleting links
      const refRs = store.querySqlSync(
        'SELECT photo_ref_id FROM photo_owner_link WHERE owner_kind = ? AND owner_id = ?;',
        [OWN_PERSON, id]
      );
      const refIds: number[] = [];
      while (refRs.goToNextRow()) {
        refIds.push(Number(refRs.getLong(refRs.getColumnIndex('photo_ref_id'))));
      }
      refRs.close();
      // Delete person-side photo owner links
      store.executeSql('DELETE FROM photo_owner_link WHERE owner_kind = ? AND owner_id = ?;', [OWN_PERSON, id]);
      // Decrement reference_count for each affected photo_ref
      for (const rid of refIds) {
        store.executeSql('UPDATE photo_ref SET reference_count = MAX(0, reference_count - 1) WHERE id = ?;', [rid]);
        store.executeSql('UPDATE photo_ref SET is_referenced = 0 WHERE id = ? AND reference_count = 0;', [rid]);
      }
      // Delete person-story associations
      store.executeSql('DELETE FROM person_story WHERE person_id = ?;', [id]);
      // Delete person
      store.executeSql('DELETE FROM person WHERE id = ?;', [id]);
      store.commit();
      return changesCount(store) > 0;
    } catch (_e) {
      store.rollBack();
      return false;
    }
  }

  deleteStory(id: number): boolean {
    const store = this.db();
    const s = this.getStory(id);
    if (s === null) {
      return false;
    }
    try {
      store.beginTransaction();
      // Collect affected photo_ref ids before deleting links
      const refRs = store.querySqlSync(
        'SELECT photo_ref_id FROM photo_owner_link WHERE owner_kind = ? AND owner_id = ?;',
        [OWN_STORY, id]
      );
      const refIds: number[] = [];
      while (refRs.goToNextRow()) {
        refIds.push(Number(refRs.getLong(refRs.getColumnIndex('photo_ref_id'))));
      }
      refRs.close();
      // Delete story-side photo owner links
      store.executeSql('DELETE FROM photo_owner_link WHERE owner_kind = ? AND owner_id = ?;', [OWN_STORY, id]);
      // Decrement reference_count for each affected photo_ref
      for (const rid of refIds) {
        store.executeSql('UPDATE photo_ref SET reference_count = MAX(0, reference_count - 1) WHERE id = ?;', [rid]);
        store.executeSql('UPDATE photo_ref SET is_referenced = 0 WHERE id = ? AND reference_count = 0;', [rid]);
      }
      // Delete person-story associations
      store.executeSql('DELETE FROM person_story WHERE story_id = ?;', [id]);
      // Delete story
      store.executeSql('DELETE FROM story WHERE id = ?;', [id]);
      store.commit();
      return changesCount(store) > 0;
    } catch (_e) {
      store.rollBack();
      return false;
    }
  }

  removePhotoForPerson(personId: number, photoRefId: number): boolean {
    return this.removePhotoForOwner(OWN_PERSON, personId, photoRefId);
  }

  removePhotoForStory(storyId: number, photoRefId: number): boolean {
    return this.removePhotoForOwner(OWN_STORY, storyId, photoRefId);
  }

  private removePhotoForOwner(ownerKind: number, ownerId: number, photoRefId: number): boolean {
    const store = this.db();
    try {
      store.beginTransaction();
      const rs = store.querySqlSync(
        'SELECT COUNT(*) AS c FROM photo_owner_link WHERE owner_kind = ? AND owner_id = ? AND photo_ref_id = ?;',
        [ownerKind, ownerId, photoRefId]
      );
      let exists = false;
      if (rs.goToFirstRow()) {
        exists = (rs.getLong(rs.getColumnIndex('c')) as number) > 0;
      }
      rs.close();
      if (!exists) {
        store.rollBack();
        return false;
      }
      store.executeSql(
        'DELETE FROM photo_owner_link WHERE owner_kind = ? AND owner_id = ? AND photo_ref_id = ?;',
        [ownerKind, ownerId, photoRefId]
      );
      store.executeSql(
        'UPDATE photo_ref SET reference_count = MAX(0, reference_count - 1) WHERE id = ?;',
        [photoRefId]
      );
      store.executeSql(
        'UPDATE photo_ref SET is_referenced = 0 WHERE id = ? AND reference_count = 0;',
        [photoRefId]
      );
      store.commit();
      return true;
    } catch (_e) {
      store.rollBack();
      return false;
    }
  }

  updatePhotoRefStatus(photoRefId: number, status: number): void {
    const store = this.db();
    store.executeSql('UPDATE photo_ref SET ref_status = ? WHERE id = ?;', [status, photoRefId]);
  }

  gcOrphanPhotoRefs(): number {
    const store = this.db();
    // Query orphan IDs before GC
    const idRs = store.querySqlSync(
      'SELECT pr.id FROM photo_ref pr LEFT JOIN photo_owner_link pol ON pol.photo_ref_id = pr.id WHERE pol.id IS NULL;',
      []
    );
    const ids: number[] = [];
    while (idRs.goToNextRow()) {
      ids.push(Number(idRs.getLong(idRs.getColumnIndex('id'))));
    }
    idRs.close();
    if (ids.length === 0) {
      console.info('T-27-GC', 'no orphan photo_ref found');
      return 0;
    }
    const before = ids.length;
    // Delete each orphan in a transaction
    try {
      store.beginTransaction();
      for (const orphanId of ids) {
        store.executeSql('DELETE FROM photo_ref WHERE id = ?;', [orphanId]);
      }
      store.commit();
    } catch (_e) {
      store.rollBack();
      console.info('T-27-GC', `orphan GC failed, rolled back ${ids.length} deletions`);
      return 0;
    }
    console.info('T-27-GC', `orphan GC: before=${before}, deleted=${ids.length}`);
    return ids.length;
  }
}
