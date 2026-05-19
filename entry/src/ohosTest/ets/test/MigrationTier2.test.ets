/**
 * Tier2：Migration L2 证据 —— 成功路径 & 失败路径。
 * 使用 EntryAbility 的 UIAbilityContext（见 OhosTestRdbContext），独立 RDB 文件。
 *
 * 覆盖 DoD C-2：失败路径下版本号不前进、应用不宣称成功。
 */
import { relationalStore } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import { ensureSchemaV1 } from '../../../main/ets/infrastructure/data/RdbSchema';
import { MigrationRunner } from '../../../main/ets/infrastructure/data/MigrationRunner';
import type { MigrationContext, MigrationStep, MigrationStepResult } from '../../../main/ets/infrastructure/data/MigrationTypes';
import { resolveRdbCapableContext } from './OhosTestRdbContext';

const SCHEMA_POLL_MS = 50;
const SCHEMA_POLL_MAX = 24;

function makeIsolatedDbName(): string {
  return `MigrationTest_${Date.now()}_${Math.floor(Math.random() * 10000)}.db`;
}

function sleepMs(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void): void => {
    setTimeout((): void => {
      resolve();
    }, ms);
  });
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

/** ensureSchemaV1 内 executeSql 在真机上可能异步落盘，轮询至 version≥1。 */
async function bootstrapSchemaV1(store: relationalStore.RdbStore): Promise<void> {
  ensureSchemaV1(store);
  for (let i = 0; i < SCHEMA_POLL_MAX; i++) {
    if (readSchemaVersion(store) >= 1) {
      return;
    }
    await sleepMs(SCHEMA_POLL_MS);
  }
  throw new Error('bootstrapSchemaV1: schema_meta.version did not reach 1');
}

export default function migrationTier2(): void {
  describe('migration_tier2', () => {
    /**
     * TS1: 成功路径 —— 迁移后版本号正确推进
     */
    it('success_path_version_advances', 0, async (): Promise<void> => {
      const store: relationalStore.RdbStore = await createIsolatedRdb();
      try {
        await bootstrapSchemaV1(store);
        const vAfterSchema = readSchemaVersion(store);
        console.info('MigrationTier2: vAfterSchema=' + vAfterSchema);
        expect(vAfterSchema).assertEqual(1);

        const ctx: MigrationContext = {
          schemaVersion: 0,
          tables: new Map(),
          counters: new Map(),
          appliedSteps: new Set(),
          rdbStore: store
        };

        const runner = new MigrationRunner();
        const testStep: MigrationStep = {
          fromVersion: 1,
          toVersion: 2,
          stepId: 'test_v1_to_v2',
          precheck: (c: MigrationContext): void => {
            if (c.schemaVersion !== 1) {
              throw new Error(`expected version 1, got ${c.schemaVersion}`);
            }
          },
          apply: (c: MigrationContext): void => {
            c.rdbStore!.executeSql(
              'CREATE TABLE IF NOT EXISTS migration_test_migration_v2_marker (id INTEGER PRIMARY KEY, label TEXT);',
              []
            );
          }
        };

        const results: MigrationStepResult[] = runner.run(ctx, 2, [testStep]);
        console.info('MigrationTier2: success results=' + JSON.stringify(results));

        expect(results.length).assertEqual(1);
        expect(results[0].status).assertEqual('applied');
        expect(results[0].stepId).assertEqual('test_v1_to_v2');

        const vAfter = readSchemaVersion(store);
        expect(vAfter).assertEqual(2);
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
        expect(readSchemaVersion(store)).assertEqual(1);

        const ctx: MigrationContext = {
          schemaVersion: 0,
          tables: new Map(),
          counters: new Map(),
          appliedSteps: new Set(),
          rdbStore: store
        };

        const runner = new MigrationRunner();
        const failingStep: MigrationStep = {
          fromVersion: 1,
          toVersion: 2,
          stepId: 'test_v1_to_v2_fail',
          precheck: (c: MigrationContext): void => {
            if (c.schemaVersion !== 1) {
              throw new Error(`expected version 1, got ${c.schemaVersion}`);
            }
          },
          apply: (_c: MigrationContext): void => {
            throw new Error('simulated migration failure');
          }
        };

        const results: MigrationStepResult[] = runner.run(ctx, 2, [failingStep]);
        console.info('MigrationTier2: fail results=' + JSON.stringify(results));

        expect(results[0].status).assertEqual('failed');
        expect(results[0].stepId).assertEqual('test_v1_to_v2_fail');
        expect(readSchemaVersion(store)).assertEqual(1);
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
        expect(readSchemaVersion(store)).assertEqual(1);

        const ctx: MigrationContext = {
          schemaVersion: 0,
          tables: new Map(),
          counters: new Map(),
          appliedSteps: new Set(),
          rdbStore: store
        };

        const runner = new MigrationRunner();
        const precheckFailingStep: MigrationStep = {
          fromVersion: 1,
          toVersion: 2,
          stepId: 'test_v1_to_v2_badpc',
          precheck: (_c: MigrationContext): void => {
            throw new Error('simulated precheck failure');
          },
          apply: (_c: MigrationContext): void => {
            // should never reach here
          }
        };

        const results: MigrationStepResult[] = runner.run(ctx, 2, [precheckFailingStep]);
        console.info('MigrationTier2: precheck fail results=' + JSON.stringify(results));

        expect(results.length).assertEqual(1);
        expect(results[0].status).assertEqual('failed');
        expect(readSchemaVersion(store)).assertEqual(1);
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
        expect(readSchemaVersion(store)).assertEqual(1);

        const ctx: MigrationContext = {
          schemaVersion: 0,
          tables: new Map(),
          counters: new Map(),
          appliedSteps: new Set(),
          rdbStore: store
        };

        const runner = new MigrationRunner();
        const step: MigrationStep = {
          fromVersion: 1,
          toVersion: 2,
          stepId: 'idem_step',
          precheck: (c: MigrationContext): void => {
            if (c.schemaVersion !== 1) {
              throw new Error(`expected 1, got ${c.schemaVersion}`);
            }
          },
          apply: (c: MigrationContext): void => {
            c.rdbStore!.executeSql(
              'CREATE TABLE IF NOT EXISTS idem_marker (id INTEGER PRIMARY KEY);',
              []
            );
          }
        };

        const r1: MigrationStepResult[] = runner.run(ctx, 2, [step]);
        expect(r1.length).assertEqual(1);
        expect(r1[0].status).assertEqual('applied');

        ctx.schemaVersion = 1;
        const r2: MigrationStepResult[] = runner.run(ctx, 2, [step]);
        // 第二次：DB 已达 target 则无新结果；或 appliedSteps 记步 → status=skipped
        if (r2.length > 0) {
          expect(r2.length).assertEqual(1);
          expect(r2[0].status).assertEqual('skipped');
        }
        expect(readSchemaVersion(store)).assertEqual(2);
      } finally {
        try { store.close(); } catch (_e) { /* ignore */ }
      }
    });
  });
}
