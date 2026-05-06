export interface MigrationContext {
  schemaVersion: number;
  tables: Map<string, string[]>;
  counters: Map<string, number>;
  appliedSteps: Set<string>;
}

export interface MigrationStepResult {
  stepId: string;
  status: 'applied' | 'skipped' | 'failed';
  message: string;
  elapsedMs: number;
}

export interface MigrationStep {
  fromVersion: number;
  toVersion: number;
  stepId: string;
  precheck: (ctx: MigrationContext) => void;
  apply: (ctx: MigrationContext) => void;
}
