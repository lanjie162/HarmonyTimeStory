import { relationalStore } from '@kit.ArkData';
import hilog from '@ohos.hilog';
import { migrationSteps as defaultSteps } from './MigrationRegistry';
import type { MigrationContext, MigrationStep, MigrationStepResult } from './MigrationTypes';

const DOMAIN = 0x0000;

export class MigrationRunner {
  /**
   * Run migrations from current version to target.
   * @param ctx - migration context; if rdbStore is set, reads current version from DB
   * @param targetVersion - desired target version
   * @param steps - optional custom step array (default: registry steps). Provided for testability.
   */
  run(ctx: MigrationContext, targetVersion: number, steps?: MigrationStep[]): MigrationStepResult[] {
    const results: MigrationStepResult[] = [];
    const sorted = (steps ?? defaultSteps).sort((a, b) => a.fromVersion - b.fromVersion);

    // If RDB store is available, read current version from DB
    if (ctx.rdbStore) {
      ctx.schemaVersion = this.readSchemaVersion(ctx.rdbStore);
    }

    for (const step of sorted) {
      if (ctx.schemaVersion >= targetVersion) {
        break;
      }
      if (step.fromVersion !== ctx.schemaVersion || step.toVersion > targetVersion) {
        continue;
      }

      // Idempotency check: already applied in this session context
      if (ctx.appliedSteps.has(step.stepId)) {
        const elapsedMs = 0;
        results.push({
          stepId: step.stepId,
          status: 'skipped',
          message: 'step already applied in context, skip by idempotent guard',
          elapsedMs
        });
        continue;
      }

      const startedAt = Date.now();
      try {
        hilog.info(DOMAIN, 'migration', 'precheck step=%{public}s from=%{public}d to=%{public}d',
          step.stepId, step.fromVersion, step.toVersion);
        step.precheck(ctx);

        hilog.info(DOMAIN, 'migration', 'apply step=%{public}s', step.stepId);
        step.apply(ctx);

        // Persist version in RDB if available — only AFTER successful apply
        if (ctx.rdbStore) {
          this.writeSchemaVersion(ctx.rdbStore, step.toVersion);
          hilog.info(DOMAIN, 'migration', 'version advanced: %{public}d -> %{public}d',
            step.fromVersion, step.toVersion);
        }

        ctx.appliedSteps.add(step.stepId);
        ctx.schemaVersion = step.toVersion;

        results.push({
          stepId: step.stepId,
          status: 'applied',
          message: `migrated ${step.fromVersion} -> ${step.toVersion}`,
          elapsedMs: Date.now() - startedAt
        });
      } catch (error) {
        const message = error instanceof Error ? error.message : 'unknown migration failure';
        hilog.error(DOMAIN, 'migration', 'step=%{public}s FAILED: %{public}s', step.stepId, message);
        results.push({
          stepId: step.stepId,
          status: 'failed',
          message,
          elapsedMs: Date.now() - startedAt
        });
        // Critical: break on failure, version NOT advanced
        break;
      }
    }

    return results;
  }

  readSchemaVersion(store: relationalStore.RdbStore): number {
    try {
      const rs = store.querySqlSync('SELECT version FROM schema_meta WHERE id = 1', []);
      let version = 0;
      if (rs.goToFirstRow()) {
        version = rs.getLong(rs.getColumnIndex('version')) as number;
      }
      rs.close();
      return version;
    } catch (_e) {
      hilog.error(DOMAIN, 'migration', 'readSchemaVersion failed, assuming 0');
      return 0;
    }
  }

  writeSchemaVersion(store: relationalStore.RdbStore, version: number): void {
    store.executeSql('UPDATE schema_meta SET version = ? WHERE id = 1;', [version]);
  }
}