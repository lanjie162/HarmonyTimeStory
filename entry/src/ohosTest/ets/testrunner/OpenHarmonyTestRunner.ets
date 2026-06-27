import hilog from '@ohos.hilog';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import type { Want } from '@kit.AbilityKit';

const tag = 'OpenHarmonyTestRunner';

export default class OpenHarmonyTestRunner {
  onPrepare(): void {
    hilog.info(0x0000, tag, '%{public}s', 'onPrepare');
  }

  onRun(): void {
    hilog.info(0x0000, tag, '%{public}s', 'onRun begin');
    const args = abilityDelegatorRegistry.getArguments();
    const bundleName = args.parameters['bundleName'] as string;
    const moduleName = args.parameters['moduleName'] as string;
    const testAbilityName = 'TestAbility';
    hilog.info(0x0000, tag, 'bundleName: %{public}s, moduleName: %{public}s', bundleName ?? '', moduleName ?? '');
    const abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator();
    const want: Want = {
      bundleName: 'com.lanjie162.timestore',
      moduleName: 'entry_test',
      abilityName: testAbilityName
    };
    abilityDelegator.startAbility(want, (err: Error) => {
      if (err) {
        hilog.error(0x0000, tag, 'startAbility failed: %{public}s', JSON.stringify(err) ?? '');
      }
      hilog.info(0x0000, tag, '%{public}s', 'onRun end');
    });
  }
}