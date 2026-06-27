import { MigrationRunner } from './MigrationRunner';
import type { MigrationContext, MigrationStepResult } from './MigrationTypes';

export class DataImpl {
  createV1SampleContext(): MigrationContext {
    return {
      schemaVersion: 1,
      tables: new Map<string, string[]>([
        ['person', ['id', 'displayName']],
        ['story', ['id', 'title']],
        ['photo_ref', ['id', 'uri']],
        ['photo_owner_link', ['id', 'ownerKind', 'ownerId', 'photoRefId']]
      ]),
      counters: new Map<string, number>([['PhotoRef.referenceCount', 3]]),
      appliedSteps: new Set<string>()
    };
  }

  createV2SampleContext(): MigrationContext {
    return {
      schemaVersion: 2,
      tables: new Map<string, string[]>([
        ['person', ['id', 'displayName', 'createdAt', 'updatedAt']],
        ['story', ['id', 'title', 'createdAt', 'updatedAt']],
        ['person_story', ['personId', 'storyId']],
        ['photo_ref', ['id', 'uri']],
        ['photo_owner_link', ['id', 'ownerKind', 'ownerId', 'photoRefId']],
        ['migration_audit', ['batchId', 'fromVersion', 'toVersion', 'createdAt']]
      ]),
      counters: new Map<string, number>([['PhotoRef.referenceCount', 3]]),
      appliedSteps: new Set<string>(['v1_to_v2_core'])
    };
  }

  migrateV1ToV2(context: MigrationContext): MigrationStepResult[] {
    const runner = new MigrationRunner();
    return runner.run(context, 2);
  }

  createV3SampleContext(): MigrationContext {
    return {
      schemaVersion: 3,
      tables: new Map<string, string[]>([
        ['person', ['id', 'displayName', 'avatarBlob', 'birthday', 'gender', 'remark', 'personType']],
        ['story', ['id', 'title', 'createdAt', 'updatedAt']],
        ['person_story', ['personId', 'storyId']],
        ['photo_ref', ['id', 'uri']],
        ['photo_owner_link', ['id', 'ownerKind', 'ownerId', 'photoRefId']],
        ['migration_audit', ['batchId', 'fromVersion', 'toVersion', 'createdAt']]
      ]),
      counters: new Map<string, number>([['PhotoRef.referenceCount', 3]]),
      appliedSteps: new Set<string>(['v1_to_v2_core', 'v2_to_v3_person_fields'])
    };
  }

  migrateV3ToV4(context: MigrationContext): MigrationStepResult[] {
    const runner = new MigrationRunner();
    return runner.run(context, 4);
  }
}