import { MigrationRunner } from './MigrationRunner';
import type { MigrationContext, MigrationStepResult } from './MigrationTypes';

export class DataImpl {
  createV1SampleContext(): MigrationContext {
    return {
      schemaVersion: 1,
      tables: new Map<string, string[]>([
        ['Person', ['id', 'displayName']],
        ['Story', ['id', 'title']],
        ['PhotoRef', ['id', 'uri']],
        ['PhotoOwnerLink', ['id', 'ownerKind', 'ownerId', 'photoRefId']]
      ]),
      counters: new Map<string, number>([['PhotoRef.referenceCount', 3]]),
      appliedSteps: new Set<string>()
    };
  }

  migrateV1ToV2(context: MigrationContext): MigrationStepResult[] {
    const runner = new MigrationRunner();
    return runner.run(context, 2);
  }
}
