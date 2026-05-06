import { migrationSteps } from './MigrationRegistry';
import type { MigrationContext, MigrationStepResult } from './MigrationTypes';

export class MigrationRunner {
  run(ctx: MigrationContext, targetVersion: number): MigrationStepResult[] {
    const results: MigrationStepResult[] = [];
    const sorted = migrationSteps.sort((a, b) => a.fromVersion - b.fromVersion);

    for (const step of sorted) {
      if (ctx.schemaVersion >= targetVersion) {
        break;
      }
      if (step.fromVersion !== ctx.schemaVersion || step.toVersion > targetVersion) {
        continue;
      }

      const startedAt = Date.now();
      try {
        if (ctx.appliedSteps.has(step.stepId)) {
          results.push({
            stepId: step.stepId,
            status: 'skipped',
            message: 'step already applied, skip by idempotent guard',
            elapsedMs: Date.now() - startedAt
          });
          continue;
        }
        step.precheck(ctx);
        step.apply(ctx);
        results.push({
          stepId: step.stepId,
          status: 'applied',
          message: `migrated ${step.fromVersion} -> ${step.toVersion}`,
          elapsedMs: Date.now() - startedAt
        });
      } catch (error) {
        const message = error instanceof Error ? error.message : 'unknown migration failure';
        results.push({
          stepId: step.stepId,
          status: 'failed',
          message,
          elapsedMs: Date.now() - startedAt
        });
        break;
      }
    }

    return results;
  }
}
