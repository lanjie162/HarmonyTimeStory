import { relationalStore } from '@kit.ArkData';

/** 与 `schema_meta.version` 对齐；供 Tier1 契约断言（勿与 RDB 运行时 DDL 混测）。 */
export const RDB_SCHEMA_META_VERSION = 1;

/** V2.1 首版：与当前 MVP 主链字段对齐；后续迁移由 T-18 扩展。 */
export function ensureSchemaV1(store: relationalStore.RdbStore): void {
  store.executeSql(
    'CREATE TABLE IF NOT EXISTS schema_meta (id INTEGER PRIMARY KEY CHECK (id = 1), version INTEGER NOT NULL);',
    []
  );
  store.executeSql(
    'INSERT OR IGNORE INTO schema_meta (id, version) VALUES (1, 0);',
    []
  );
  store.executeSql(
    'CREATE TABLE IF NOT EXISTS person (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'display_name TEXT NOT NULL, ' +
      'created_at INTEGER NOT NULL, ' +
      'updated_at INTEGER NOT NULL' +
      ');',
    []
  );
  store.executeSql(
    'CREATE TABLE IF NOT EXISTS story (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'title TEXT NOT NULL, ' +
      'created_at INTEGER NOT NULL, ' +
      'updated_at INTEGER NOT NULL' +
      ');',
    []
  );
  store.executeSql(
    'CREATE TABLE IF NOT EXISTS person_story (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'person_id INTEGER NOT NULL, ' +
      'story_id INTEGER NOT NULL, ' +
      'UNIQUE(person_id, story_id)' +
      ');',
    []
  );
  store.executeSql(
    'CREATE TABLE IF NOT EXISTS photo_ref (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'uri TEXT NOT NULL UNIQUE, ' +
      'taken_at_cache INTEGER, ' +
      'added_at INTEGER NOT NULL, ' +
      'ref_status INTEGER NOT NULL DEFAULT 1, ' +
      'reference_count INTEGER NOT NULL DEFAULT 0, ' +
      'is_referenced INTEGER NOT NULL DEFAULT 0' +
      ');',
    []
  );
  store.executeSql(
    'CREATE TABLE IF NOT EXISTS photo_owner_link (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'owner_kind INTEGER NOT NULL, ' +
      'owner_id INTEGER NOT NULL, ' +
      'photo_ref_id INTEGER NOT NULL, ' +
      'linked_at INTEGER NOT NULL, ' +
      'sort_key INTEGER NOT NULL, ' +
      'UNIQUE(owner_kind, owner_id, photo_ref_id)' +
      ');',
    []
  );
  const rs = store.querySqlSync('SELECT version FROM schema_meta WHERE id = 1', []);
  let current = 0;
  if (rs.goToFirstRow()) {
    current = rs.getLong(rs.getColumnIndex('version')) as number;
  }
  rs.close();
  if (current < RDB_SCHEMA_META_VERSION) {
    store.executeSql('UPDATE schema_meta SET version = ? WHERE id = 1;', [RDB_SCHEMA_META_VERSION]);
  }
}
