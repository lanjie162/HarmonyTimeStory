import { relationalStore } from '@kit.ArkData';
import type { MigrationContext, MigrationStep } from './MigrationTypes';

function ensureV1ToV2Precheck(ctx: MigrationContext): void {
  if (ctx.schemaVersion !== 1) {
    throw new Error(`unexpected version ${ctx.schemaVersion}, expected 1`);
  }

  if (ctx.rdbStore) {
    const requiredTables = ['person', 'story', 'photo_ref'];
    const missing = checkMissingTablesSqlite(ctx.rdbStore, requiredTables);
    if (missing.length > 0) {
      throw new Error(`v1 minimal tables are not ready, missing: ${missing.join(', ')}`);
    }
  } else {
    if (!ctx.tables.has('person') || !ctx.tables.has('story') || !ctx.tables.has('photo_ref')) {
      throw new Error('v1 minimal tables are not ready');
    }
  }
}

function checkMissingTablesSqlite(store: relationalStore.RdbStore, required: string[]): string[] {
  const missing: string[] = [];
  const placeholders = required.map(() => '?').join(',');
  const rs = store.querySqlSync(
    `SELECT name FROM sqlite_master WHERE type='table' AND name IN (${placeholders})`,
    required
  );
  const found = new Set<string>();
  if (rs.goToFirstRow()) {
    found.add(rs.getString(rs.getColumnIndex('name')));
  }
  while (rs.goToNextRow()) {
    found.add(rs.getString(rs.getColumnIndex('name')));
  }
  rs.close();
  for (const t of required) {
    if (!found.has(t)) {
      missing.push(t);
    }
  }
  return missing;
}

function applyV1ToV2(ctx: MigrationContext): void {
  if (ctx.rdbStore) {
    ctx.rdbStore.executeSql(
      'CREATE TABLE IF NOT EXISTS migration_audit (' +
        'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
        'batch_id TEXT NOT NULL, ' +
        'from_version INTEGER NOT NULL, ' +
        'to_version INTEGER NOT NULL, ' +
        'created_at INTEGER NOT NULL' +
      ');',
      []
    );
  } else {
    if (!ctx.tables.has('migration_audit')) {
      ctx.tables.set('migration_audit', ['batchId', 'fromVersion', 'toVersion', 'createdAt']);
    }
    const currentRefCount = ctx.counters.get('PhotoRef.referenceCount') ?? 0;
    ctx.counters.set('PhotoRef.referenceCount', currentRefCount);
  }

  ctx.appliedSteps.add('v1_to_v2_core');
  ctx.schemaVersion = 2;
}

function ensureV2ToV3Precheck(ctx: MigrationContext): void {
  if (ctx.schemaVersion !== 2) {
    throw new Error(`unexpected version ${ctx.schemaVersion}, expected 2`);
  }
  if (ctx.rdbStore) {
    const requiredTables = ['person'];
    const missing = checkMissingTablesSqlite(ctx.rdbStore, requiredTables);
    if (missing.length > 0) {
      throw new Error(`v2 minimal tables are not ready, missing: ${missing.join(', ')}`);
    }
  } else {
    if (!ctx.tables.has('person')) {
      throw new Error('v2 minimal tables are not ready');
    }
  }
}

function applyV2ToV3(ctx: MigrationContext): void {
  if (ctx.rdbStore) {
    const newColumns: string[] = [
      'avatar_blob BLOB',
      'birthday INTEGER',
      'gender INTEGER',
      'remark TEXT DEFAULT \'\'',
      'person_type INTEGER DEFAULT 3'
    ];
    for (const colDef of newColumns) {
      ctx.rdbStore.executeSql(`ALTER TABLE person ADD COLUMN ${colDef};`, []);
    }
  }

  ctx.appliedSteps.add('v2_to_v3_person_fields');
  ctx.schemaVersion = 3;
}

function ensureV3ToV4Precheck(ctx: MigrationContext): void {
  if (ctx.schemaVersion !== 3) {
    throw new Error(`unexpected version ${ctx.schemaVersion}, expected 3`);
  }
  if (ctx.rdbStore) {
    const requiredTables = ['story'];
    const missing = checkMissingTablesSqlite(ctx.rdbStore, requiredTables);
    if (missing.length > 0) {
      throw new Error(`v3 minimal tables are not ready, missing: ${missing.join(', ')}`);
    }
  } else {
    if (!ctx.tables.has('story')) {
      throw new Error('v3 minimal tables are not ready');
    }
  }
}

function applyV3ToV4(ctx: MigrationContext): void {
  if (ctx.rdbStore) {
    const newColumns: string[] = [
      'description TEXT DEFAULT \'\'',
      'time_start INTEGER',
      'time_end INTEGER',
      'cover_uri TEXT DEFAULT \'\'',
      'location TEXT DEFAULT \'\'',
      'tags TEXT DEFAULT \'[]\''
    ];
    for (const colDef of newColumns) {
      ctx.rdbStore.executeSql(`ALTER TABLE story ADD COLUMN ${colDef};`, []);
    }
  }

  ctx.appliedSteps.add('v3_to_v4_story_fields');
  ctx.schemaVersion = 4;
}

export const migrationSteps: MigrationStep[] = [
  {
    fromVersion: 1,
    toVersion: 2,
    stepId: 'v1_to_v2_core',
    precheck: ensureV1ToV2Precheck,
    apply: applyV1ToV2
  },
  {
    fromVersion: 2,
    toVersion: 3,
    stepId: 'v2_to_v3_person_fields',
    precheck: ensureV2ToV3Precheck,
    apply: applyV2ToV3
  },
  {
    fromVersion: 3,
    toVersion: 4,
    stepId: 'v3_to_v4_story_fields',
    precheck: ensureV3ToV4Precheck,
    apply: applyV3ToV4
  }
];