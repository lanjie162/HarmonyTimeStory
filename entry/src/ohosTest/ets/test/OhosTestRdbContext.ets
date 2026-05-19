/**
 * ohosTest 内获取可用于 relationalStore.getRdbStore 的 Context。
 * getAppContext() 在部分真机/API 上会触发 Parameter error.Illegal context（code 401）。
 */
import { abilityDelegatorRegistry } from '@kit.TestKit';
import type { UIAbility, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

function resolveBundleName(): string {
  const args = abilityDelegatorRegistry.getArguments();
  const n = args.bundleName;
  if (typeof n === 'string' && n.length > 0) {
    return n;
  }
  return 'com.lanjie162.timestore';
}

let cachedRdbContext: Context | undefined = undefined;

function sleepMs(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void): void => {
    setTimeout((): void => {
      resolve();
    }, ms);
  });
}

function tryGetTopAbilityContext(delegator: abilityDelegatorRegistry.AbilityDelegator): Promise<Context | undefined> {
  return new Promise<Context | undefined>((resolve: (ctx: Context | undefined) => void): void => {
    delegator.getCurrentTopAbility((err: BusinessError, ability: UIAbility) => {
      if (err !== null && err !== undefined) {
        resolve(undefined);
        return;
      }
      if (ability === null || ability === undefined) {
        resolve(undefined);
        return;
      }
      resolve(ability.context);
    });
  });
}

/**
 * 拉起 EntryAbility 并返回其 UIAbilityContext（与生产 EntryAbility 一致）。
 * 同进程内缓存，避免重复 waitAbilityMonitor 失败。
 */
export async function resolveRdbCapableContext(): Promise<Context> {
  if (cachedRdbContext !== undefined) {
    return cachedRdbContext;
  }

  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const bundleName = resolveBundleName();
  const want: Want = {
    bundleName: bundleName,
    abilityName: 'EntryAbility'
  };

  let ctx = await tryGetTopAbilityContext(delegator);
  if (ctx === undefined) {
    const monitor: abilityDelegatorRegistry.AbilityMonitor = {
      abilityName: 'EntryAbility',
      onAbilityCreate: (_ability: UIAbility): void => {
        console.info('OhosTestRdbContext: EntryAbility onAbilityCreate');
      }
    };
    await delegator.addAbilityMonitor(monitor);
    try {
      await delegator.startAbility(want);
      const ability: UIAbility = await delegator.waitAbilityMonitor(monitor);
      ctx = ability.context;
    } finally {
      try {
        await delegator.removeAbilityMonitor(monitor);
      } catch (_e) {
        // ignore
      }
    }
  } else {
    await delegator.startAbility(want);
    await sleepMs(300);
  }

  cachedRdbContext = ctx;
  console.info('OhosTestRdbContext: cached UIAbility context for RDB');
  return ctx;
}
