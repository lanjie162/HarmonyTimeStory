import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityDelegatorRegistry from '@ohos.application.abilityDelegatorRegistry';
import { Hypium } from '@ohos/hypium';
import hilog from '@ohos.hilog';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import testsuite from '../test/List.test';

const tag = 'TestAbility';

export default class TestAbility extends UIAbility {
  onCreate(): void {
    hilog.info(0x0000, tag, '%{public}s', 'TestAbility onCreate');
    const abilityDelegator = AbilityDelegatorRegistry.getAbilityDelegator();
    const abilityDelegatorArguments = AbilityDelegatorRegistry.getArguments();
    hilog.info(0x0000, tag, '%{public}s', 'start run testcase!!!');
    Hypium.hypiumTest(abilityDelegator, abilityDelegatorArguments, testsuite);
  }

  onDestroy(): void {
    hilog.info(0x0000, tag, '%{public}s', 'TestAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, tag, '%{public}s', 'TestAbility onWindowStageCreate');
    windowStage.loadContent('testability/pages/Index', (err: BusinessError): void => {
      if (err.code) {
        hilog.error(0x0000, tag, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, tag, 'Succeeded in loading the content. Data: %{public}s', JSON.stringify(err) ?? '');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, tag, '%{public}s', 'TestAbility onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, tag, '%{public}s', 'TestAbility onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, tag, '%{public}s', 'TestAbility onBackground');
  }
}