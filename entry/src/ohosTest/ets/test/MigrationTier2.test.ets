/**
 * Tier2：Migration L2 证据 —— 成功路径 & 失败路径。
 * 使用 EntryAbility 的 UIAbilityContext（见 OhosTestRdbContext），独立 RDB 文件。
 *
 * 覆盖 DoD C-2：失败路径下版本号不前进、应用不宣称成功。
 */
import { relationalStore } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import { ensureSchemaV1, RDB_SCHEMA_META_VERSION } from '../../../main/ets/infrastructure/data/RdbSchema';
import { MigrationRunner } from '../../../main/ets/infrastructure/data/MigrationRunner';
import type { MigrationContext, MigrationStep, MigrationStepResult } from '../../../main/ets/infrastructure/data/MigrationTypes';
import { resolveRdbCapableContext } from './OhosTestRdbContext';

function makeIsolatedDbName(): string {
  return `MigrationTest_${Date.now()}_${Math.floor(Math.random() * 10000)}.db`;
}

async function createIsolatedRdb(): Promise<relationalStore.RdbStore> {
  const ctx = await resolveRdbCapableContext();
  const cfg: relationalStore.StoreConfig = {
    name: makeIsolatedDbName(),
    securityLevel: relationalStore.SecurityLevel.S1
  };
  return await relationalStore.getRdbStore(ctx, cfg);
}

function readSchemaVersion(store: relationalStore.RdbStore): number {
  return new MigrationRunner().readSchemaVersion(store);
}

/** ensureSchemaV1 对新库设置版本为 RDB_SCHEMA_META_VERSION，轮询确认版本就绪。 */
async function bootstrapSchemaV1(store: relationalStore.RdbStore): Promise<void> {
  ensureSchemaV1(store);
  // ensureSchemaV1 现在使用 executeSync，版本立即可见，无需轮询
  const v = readSchemaVersion(store);
  if (v < 1) {
    throw new Error(`bootstrapSchemaV1: schema_meta.version=${v}, expected >= 1`);
  }
}

export default function migrationTier2(): void {
  describe('migration_tier2', () => {
    /**
     * TS1: 成功路径 —— 迁移后版本号正确推进
     * ensureSchemaV1 对新库设置版本为 RDB_SCHEMA_META_VERSION（当前为 5），
     * 迁移步骤从 RDB_SCHEMA_META_VERSION 推进到 RDB_SCHEMA_META_VERSION + 1。
     */
    it('success_path_version_advances', 0, async (): Promise<void> => {
      const store: relationalStore.RdbStore = await createIsolatedRdb();
      try {
        await bootstrapSchemaV1(store);
        const vAfterSchema = readSchemaVersion(store);
        console.info('MigrationTier2: vAfterSchema=' + vAfterSchema);
        expect(vAfterSchema).assertEqual(RDB_SCHEMA_META_VERSION);

        const ctx: MigrationContext = {
          schemaVersion: 0,
          tables: new Map(),
          counters: new Map(),
          appliedSteps: new Set(),
          rdbStore: store
        };

        const targetVersion = RDB_SCHEMA_META_VERSION + 1;
        const runner = new MigrationRunner();
        const testStep: MigrationStep = {
          fromVersion: RDB_SCHEMA_META_VERSION,
          toVersion: targetVersion,
          stepId: 'test_v5_to_v6',
          precheck: (c: MigrationContext): void => {
            if (c.schemaVersion !== RDB_SCHEMA_META_VERSION) {
              throw new Error(`expected version ${RDB_SCHEMA_META_VERSION}, got ${c.schemaVersion}`);
            }
          },
          apply: (c: MigrationContext): void => {
            c.rdbStore!.executeSync(
              'CREATE TABLE IF NOT EXISTS migration_test_migration_v6_marker (id INTEGER PRIMARY KEY, label TEXT);',
              []
            );
          }
        };

        const results: MigrationStepResult[] = runner.run(ctx, targetVersion, [testStep]);
        console.info('MigrationTier2: success results=' + JSON.stringify(results));

        expect(results.length).assertEqual(1);
        expect(results[0].status).assertEqual('applied');
        expect(results[0].stepId).assertEqual('test_v5_to_v6');

        const vAfter = readSchemaVersion(store);
        expect(vAfter).assertEqual(targetVersion);
      } finally {
        try { store.close(); } catch (_e) { /* ignore */ }
      }
    });

    /**
     * TS2: 失败路径 —— 迁移步骤失败时版本号不推进
     */
    it('failure_path_version_does_not_advance', 0, async (): Promise<void> => {
      const store: relationalStore.RdbStore = await createIsolatedRdb();
      try {
        await bootstrapSchemaV1(store);
        expect(readSchemaVersion(store)).assertEqual(RDB_SCHEMA_META_VERSION);

        const ctx: MigrationContext = {
          schemaVersion: 0,
          tables: new Map(),
          counters: new Map(),
          appliedSteps: new Set(),
          rdbStore: store
        };

        const targetVersion = RDB_SCHEMA_META_VERSION + 1;
        const runner = new MigrationRunner();
        const failingStep: MigrationStep = {
          fromVersion: RDB_SCHEMA_META_VERSION,
          toVersion: targetVersion,
          stepId: 'test_v5_to_v6_fail',
          precheck: (c: MigrationContext): void => {
            if (c.schemaVersion !== RDB_SCHEMA_META_VERSION) {
              throw new Error(`expected version ${RDB_SCHEMA_META_VERSION}, got ${c.schemaVersion}`);
            }
          },
          apply: (_c: MigrationContext): void => {
            throw new Error('simulated migration failure');
          }
        };

        const results: MigrationStepResult[] = runner.run(ctx, targetVersion, [failingStep]);
        console.info('MigrationTier2: fail results=' + JSON.stringify(results));

        expect(results[0].status).assertEqual('failed');
        expect(results[0].stepId).assertEqual('test_v5_to_v6_fail');
        expect(readSchemaVersion(store)).assertEqual(RDB_SCHEMA_META_VERSION);
      } finally {
        try { store.close(); } catch (_e) { /* ignore */ }
      }
    });

    /**
     * TS3: 失败路径 —— precheck 失败也阻止版本前进
     */
    it('failure_path_precheck_fails_version_does_not_advance', 0, async (): Promise<void> => {
      const store: relationalStore.RdbStore = await createIsolatedRdb();
      try {
        await bootstrapSchemaV1(store);
        expect(readSchemaVersion(store)).assertEqual(RDB_SCHEMA_META_VERSION);

        const ctx: MigrationContext = {
          schemaVersion: 0,
          tables: new Map(),
          counters: new Map(),
          appliedSteps: new Set(),
          rdbStore: store
        };

        const targetVersion = RDB_SCHEMA_META_VERSION + 1;
        const runner = new MigrationRunner();
        const precheckFailingStep: MigrationStep = {
          fromVersion: RDB_SCHEMA_META_VERSION,
          toVersion: targetVersion,
          stepId: 'test_v5_to_v6_badpc',
          precheck: (_c: MigrationContext): void => {
            throw new Error('simulated precheck failure');
          },
          apply: (_c: MigrationContext): void => {
            // should never reach here
          }
        };

        const results: MigrationStepResult[] = runner.run(ctx, targetVersion, [precheckFailingStep]);
        console.info('MigrationTier2: precheck fail results=' + JSON.stringify(results));

        expect(results.length).assertEqual(1);
        expect(results[0].status).assertEqual('failed');
        expect(readSchemaVersion(store)).assertEqual(RDB_SCHEMA_META_VERSION);
      } finally {
        try { store.close(); } catch (_e) { /* ignore */ }
      }
    });

    /**
     * TS4: 幂等 —— 已应用步骤跳过
     */
    it('idempotent_skips_already_applied_steps', 0, async (): Promise<void> => {
      const store: relationalStore.RdbStore = await createIsolatedRdb();
      try {
        await bootstrapSchemaV1(store);
        expect(readSchemaVersion(store)).assertEqual(RDB_SCHEMA_META_VERSION);

        const ctx: MigrationContext = {
          schemaVersion: 0,
          tables: new Map(),
          counters: new Map(),
          appliedSteps: new Set(),
          rdbStore: store
        };

        const targetVersion = RDB_SCHEMA_META_VERSION + 1;
        const runner = new MigrationRunner();
        const step: MigrationStep = {
          fromVersion: RDB_SCHEMA_META_VERSION,
          toVersion: targetVersion,
          stepId: 'idem_step',
          precheck: (c: MigrationContext): void => {
            if (c.schemaVersion !== RDB_SCHEMA_META_VERSION) {
              throw new Error(`expected ${RDB_SCHEMA_META_VERSION}, got ${c.schemaVersion}`);
            }
          },
          apply: (c: MigrationContext): void => {
            c.rdbStore!.executeSync(
              'CREATE TABLE IF NOT EXISTS idem_marker (id INTEGER PRIMARY KEY);',
              []
            );
          }
        };

        const r1: MigrationStepResult[] = runner.run(ctx, targetVersion, [step]);
        expect(r1.length).assertEqual(1);
        expect(r1[0].status).assertEqual('applied');

        ctx.schemaVersion = RDB_SCHEMA_META_VERSION;
        const r2: MigrationStepResult[] = runner.run(ctx, targetVersion, [step]);
        // 第二次：DB 已达 target 则无新结果；或 appliedSteps 记步 → status=skipped
        if (r2.length > 0) {
          expect(r2.length).assertEqual(1);
          expect(r2[0].status).assertEqual('skipped');
        }
        expect(readSchemaVersion(store)).assertEqual(targetVersion);
      } finally {
        try { store.close(); } catch (_e) { /* ignore */ }
      }
    });
  });
}
