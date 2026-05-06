import type { MigrationContext, MigrationStep } from './MigrationTypes';

function ensureV1ToV2Precheck(ctx: MigrationContext): void {
  if (ctx.schemaVersion !== 1) {
    throw new Error(`unexpected version ${ctx.schemaVersion}, expected 1`);
  }
  if (!ctx.tables.has('Person') || !ctx.tables.has('Story') || !ctx.tables.has('PhotoRef')) {
    throw new Error('v1 minimal tables are not ready');
  }
}

function applyV1ToV2(ctx: MigrationContext): void {
  if (!ctx.tables.has('MigrationAudit')) {
    ctx.tables.set('MigrationAudit', ['batchId', 'fromVersion', 'toVersion', 'createdAt']);
  }
  const currentRefCount = ctx.counters.get('PhotoRef.referenceCount') ?? 0;
  ctx.counters.set('PhotoRef.referenceCount', currentRefCount);
  ctx.appliedSteps.add('v1_to_v2_core');
  ctx.schemaVersion = 2;
}

export const migrationSteps: MigrationStep[] = [
  {
    fromVersion: 1,
    toVersion: 2,
    stepId: 'v1_to_v2_core',
    precheck: ensureV1ToV2Precheck,
    apply: applyV1ToV2
  }
];
