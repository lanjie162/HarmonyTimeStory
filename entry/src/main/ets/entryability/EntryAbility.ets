import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import hilog from '@ohos.hilog';
import UIAbility from '@ohos.app.ability.UIAbility';
import Want from '@ohos.app.ability.Want';
import window from '@ohos.window';
import { relationalStore } from '@kit.ArkData';
import { installAppDataStore } from '../bootstrap/AppDataInstaller';
import { ensureSchemaV1 } from '../infrastructure/data/RdbSchema';
import { RepositoryImpl } from '../infrastructure/repository/RepositoryImpl';

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
      ensureSchemaV1(store);
      const repo = RepositoryImpl.getInstance();
      repo.attachRdb(store);
      windowStage.loadContent('pages/shell/ShellPage', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
        installAppDataStore(repo);
      });
    }).catch((e: object) => {
      hilog.error(DOMAIN, 'testTag', 'RDB init failed: %{public}s', JSON.stringify(e));
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
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
