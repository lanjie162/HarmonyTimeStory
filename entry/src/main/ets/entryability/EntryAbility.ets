import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import hilog from '@ohos.hilog';
import UIAbility from '@ohos.app.ability.UIAbility';
import Want from '@ohos.app.ability.Want';
import window from '@ohos.window';
import { relationalStore } from '@kit.ArkData';
import { installAppDataStore } from '../bootstrap/AppDataInstaller';
import { ensureSchemaV1, RDB_SCHEMA_META_VERSION } from '../infrastructure/data/RdbSchema';
import { MigrationRunner } from '../infrastructure/data/MigrationRunner';
import type { MigrationContext } from '../infrastructure/data/MigrationTypes';
import { RepositoryImpl } from '../infrastructure/repository/RepositoryImpl';
import { CrashReporter } from '../infrastructure/api/CrashReporter';

const DOMAIN = 0x0000;

const RDB_CONFIG: relationalStore.StoreConfig = {
  name: 'Timestore.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    relationalStore.getRdbStore(this.context, RDB_CONFIG).then((store: relationalStore.RdbStore) => {
      // Step 1: Bootstrap schema to V1
      ensureSchemaV1(store);

      // Step 2: Run migrations to latest version
      const ctx: MigrationContext = {
        schemaVersion: 0, // will be read from DB
        tables: new Map(),
        counters: new Map(),
        appliedSteps: new Set(),
        rdbStore: store
      };
      const runner = new MigrationRunner();
      const results = runner.run(ctx, RDB_SCHEMA_META_VERSION);
      for (const r of results) {
        hilog.info(DOMAIN, 'migration', '[bootstrap] step=%{public}s status=%{public}s msg=%{public}s elapsed=%{public}d',
          r.stepId, r.status, r.message, r.elapsedMs);
      }
      const failed = results.filter(r => r.status === 'failed');
      if (failed.length > 0) {
        hilog.error(DOMAIN, 'migration', '[bootstrap] migration chain has FAILED steps, app starts but version may be stale');
      } else if (results.length > 0) {
        hilog.info(DOMAIN, 'migration', '[bootstrap] all migrations completed successfully');
      } else {
        hilog.info(DOMAIN, 'migration', '[bootstrap] no pending migrations to apply');
      }

      const repo = RepositoryImpl.getInstance();
      repo.attachRdb(store);
      windowStage.loadContent('pages/shell/ShellPage', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
        installAppDataStore(repo);
        CrashReporter.getInstance().register();
      });
    }).catch((e: object) => {
      hilog.error(DOMAIN, 'testTag', 'RDB init failed: %{public}s', JSON.stringify(e));
    });
  }

  onWindowStageDestroy(): void {
    CrashReporter.getInstance().unregister();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}