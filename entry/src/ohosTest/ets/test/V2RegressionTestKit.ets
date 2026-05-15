import { abilityDelegatorRegistry, Component, Driver, On, ON, UiDirection } from '@kit.TestKit';
import type { Want } from '@kit.AbilityKit';

function resolveBundleName(): string {
  const args = abilityDelegatorRegistry.getArguments();
  const n = args.bundleName;
  if (typeof n === 'string' && n.length > 0) {
    return n;
  }
  return 'com.lanjie162.timestore';
}

export function sleepMs(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void): void => {
    setTimeout((): void => {
      resolve();
    }, ms);
  });
}

/** findComponents 在部分设备/版本上可能返回 null，不能直连 .length */
export async function safeFindComponents(driver: Driver, onLike: On): Promise<Component[]> {
  const raw = await driver.findComponents(onLike);
  if (raw === null || raw === undefined) {
    return [];
  }
  return raw;
}

function mainShellMatcher() {
  return ON.text('时光故事');
}

/** startAbility 只会置前窗口，不清理 router 栈；用返回键回到主壳（同包测试禁止 aa force-stop）。 */
async function ensureOnMainShell(driver: Driver): Promise<void> {
  const matcher = mainShellMatcher();
  const maxBack = 16;
  for (let i = 0; i < maxBack; i++) {
    const main = await driver.findComponent(matcher);
    if (main !== null) {
      return;
    }
    await driver.pressBack();
    await driver.waitForIdle(400, 1400);
  }
  await driver.waitForComponent(matcher, 8000);
}

/**
 * 在人物/故事页的 List 中点开指定文案行。
 * 根因：`driver.fling` 常滚的是整窗，不保证 List 视口变化；官方建议在可滑动控件上用
 * scrollToTop / scrollToBottom / scrollSearch（见 js-apis-uitest · Component）。
 * 新建项在 ForEach 末尾，优先滚到底再 find / scrollSearch。
 */
async function scrollListToFindRow(list: Component, driver: Driver, matcher: On): Promise<Component | null> {
  let row: Component | null = null;
  try {
    row = await list.scrollSearch(matcher);
    if (row !== null) {
      return row;
    }
  } catch (_e0) {
    row = null;
  }
  for (let pass = 0; pass < 3; pass++) {
    try {
      await list.scrollToBottom(28000);
      await driver.waitForIdle(500, 2200);
    } catch (_e) {
      // ignore
    }
    row = await driver.findComponent(matcher);
    if (row !== null) {
      return row;
    }
    try {
      row = await list.scrollSearch(matcher);
      if (row !== null) {
        return row;
      }
    } catch (_e2) {
      row = null;
    }
  }
  try {
    await list.scrollToTop(4000);
    await driver.waitForIdle(500, 1800);
    row = await list.scrollSearch(matcher);
    if (row !== null) {
      return row;
    }
  } catch (_e3) {
    row = null;
  }
  return null;
}

async function openListRowByVisibleText(driver: Driver, label: string, errorPrefix: string): Promise<void> {
  const matcher = ON.text(label);
  let row: Component | null = await driver.findComponent(matcher);
  if (row !== null) {
    await row.click();
    return;
  }
  const lists = await safeFindComponents(driver, ON.type('List'));
  for (const list of lists) {
    row = await scrollListToFindRow(list, driver, matcher);
    if (row !== null) {
      await row.click();
      return;
    }
  }
  if (row === null) {
    for (let i = 0; i < 10; i++) {
      await driver.fling(UiDirection.UP, 7500);
      await driver.waitForIdle(350, 1100);
    }
    for (let i = 0; i < 36; i++) {
      await driver.fling(UiDirection.DOWN, 9500);
      await driver.waitForIdle(450, 1500);
      row = await driver.findComponent(matcher);
      if (row !== null) {
        break;
      }
      for (const list of lists) {
        row = await scrollListToFindRow(list, driver, matcher);
        if (row !== null) {
          break;
        }
      }
      if (row !== null) {
        break;
      }
    }
  }
  if (row === null) {
    throw new Error(`${errorPrefix}：${label}`);
  }
  await row.click();
}

export async function openPersonListRowByDisplayName(driver: Driver, displayName: string): Promise<void> {
  await openListRowByVisibleText(driver, displayName, '人物列表未找到行');
}

export async function openStoryListRowByTitle(driver: Driver, title: string): Promise<void> {
  await openListRowByVisibleText(driver, title, '故事列表未找到行');
}

/** 人物/故事详情主体已包 Scroll：底部「导入」「DEBUG」需滚入视口；多 Scroll 时逐个尝试 scrollSearch */
async function scrollDetailScrollToBottom(driver: Driver): Promise<void> {
  const importLabel = ON.text('进入导入向导壳页');
  if ((await driver.findComponent(importLabel)) !== null) {
    return;
  }
  const scrolls = await safeFindComponents(driver, ON.type('Scroll'));
  for (const sc of scrolls) {
    for (let r = 0; r < 5; r++) {
      try {
        const hit = await sc.scrollSearch(importLabel);
        if (hit !== null) {
          return;
        }
      } catch (_e) {
        // ignore
      }
      try {
        await sc.scrollToBottom(32000);
      } catch (_e2) {
        // ignore
      }
      await driver.waitForIdle(450, 1600);
      if ((await driver.findComponent(importLabel)) !== null) {
        return;
      }
    }
  }
  for (let i = 0; i < 28; i++) {
    await driver.fling(UiDirection.DOWN, 9000);
    await driver.waitForIdle(350, 1000);
    if ((await driver.findComponent(importLabel)) !== null) {
      return;
    }
  }
}

/** 在页面首层 Scroll（人物/故事详情、导入向导等）内把匹配控件滚入检索范围。 */
export async function scrollDetailUntilVisible(driver: Driver, matcher: On): Promise<void> {
  if ((await driver.findComponent(matcher)) !== null) {
    return;
  }
  const scrolls = await safeFindComponents(driver, ON.type('Scroll'));
  for (const sc of scrolls) {
    try {
      await sc.scrollToTop(5000);
      await driver.waitForIdle(400, 1100);
    } catch (_e) {
      // ignore
    }
    if ((await driver.findComponent(matcher)) !== null) {
      return;
    }
    for (let r = 0; r < 10; r++) {
      try {
        const hit = await sc.scrollSearch(matcher);
        if (hit !== null) {
          return;
        }
      } catch (_e2) {
        // ignore
      }
      try {
        await sc.scrollToBottom(24000);
      } catch (_e3) {
        // ignore
      }
      await driver.waitForIdle(400, 1200);
      if ((await driver.findComponent(matcher)) !== null) {
        return;
      }
    }
  }
}

export async function clickDetailEnterImportWizard(driver: Driver): Promise<void> {
  await scrollDetailUntilVisible(driver, ON.text('进入导入向导壳页'));
  await scrollDetailScrollToBottom(driver);
  const btn = await driver.findComponent(ON.text('进入导入向导壳页'));
  if (btn === null) {
    throw new Error('详情页未找到「进入导入向导壳页」（需安装含 Scroll 详情的主 hap）');
  }
  await btn.click();
}

export async function clickDetailDebugInjectAlbum(driver: Driver): Promise<void> {
  const m = ON.text('【DEBUG】注入相册等价 URI');
  await scrollDetailUntilVisible(driver, m);
  await scrollDetailScrollToBottom(driver);
  const btn = await driver.findComponent(m);
  if (btn === null) {
    throw new Error('详情页未找到「【DEBUG】注入相册等价 URI」');
  }
  await btn.click();
}

export async function clickDetailDebugSameUriAgain(driver: Driver): Promise<void> {
  const m = ON.text('【DEBUG】再注相同 URI');
  await scrollDetailUntilVisible(driver, m);
  const btn = await driver.findComponent(m);
  if (btn === null) {
    throw new Error('详情页未找到「【DEBUG】再注相同 URI」');
  }
  await btn.click();
}

export async function coldStartMainApp(): Promise<Driver> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const bn = resolveBundleName();
  const want: Want = {
    bundleName: bn,
    abilityName: 'EntryAbility'
  };
  await delegator.startAbility(want);
  const driver = Driver.create();
  const matcher = mainShellMatcher();
  await driver.waitForComponent(matcher, 35000);
  await ensureOnMainShell(driver);
  await driver.waitForComponent(matcher, 8000);
  await driver.waitForIdle(300, 2000);
  return driver;
}

/** PersonDetail：第 1 个 TextInput 为显示名，第 2 个为新故事标题。 */
export async function inputPersonDetailSecondTextInput(driver: Driver, text: string): Promise<void> {
  const pageScroll = await driver.findComponent(ON.type('Scroll'));
  if (pageScroll !== null) {
    try {
      await pageScroll.scrollToTop(4000);
      await driver.waitForIdle(400, 1400);
    } catch (_e) {
      // ignore
    }
  }
  for (let t = 0; t < 8; t++) {
    const inputs = await safeFindComponents(driver, ON.type('TextInput'));
    if (inputs.length >= 2) {
      await inputs[1].inputText(text);
      return;
    }
    if (pageScroll !== null && t === 4) {
      try {
        await pageScroll.scrollToBottom(12000);
        await driver.waitForIdle(400, 1400);
      } catch (_e2) {
        // ignore
      }
    }
    await driver.fling(UiDirection.DOWN, 6000);
    await driver.waitForIdle(400, 1200);
  }
  throw new Error('PersonDetail：未收集到至少 2 个 TextInput（可滚动后再试）');
}

/** StoryDetail：第 1 个为标题，第 2 个为新人物名。 */
export async function inputStoryDetailSecondTextInput(driver: Driver, text: string): Promise<void> {
  const pageScroll = await driver.findComponent(ON.type('Scroll'));
  if (pageScroll !== null) {
    try {
      await pageScroll.scrollToTop(4000);
      await driver.waitForIdle(400, 1400);
    } catch (_e) {
      // ignore
    }
  }
  for (let t = 0; t < 8; t++) {
    const inputs = await safeFindComponents(driver, ON.type('TextInput'));
    if (inputs.length >= 2) {
      await inputs[1].inputText(text);
      return;
    }
    if (pageScroll !== null && t === 4) {
      try {
        await pageScroll.scrollToBottom(12000);
        await driver.waitForIdle(400, 1400);
      } catch (_e2) {
        // ignore
      }
    }
    await driver.fling(UiDirection.DOWN, 6000);
    await driver.waitForIdle(400, 1200);
  }
  throw new Error('StoryDetail：未收集到至少 2 个 TextInput（可滚动后再试）');
}

export async function clickConfirmImportButton(driver: Driver): Promise<void> {
  const matcher = ON.text('确认导入').type('Button');
  let commitBtn: Component | null = await driver.findComponent(matcher);
  if (commitBtn === null) {
    const scroll = await driver.findComponent(ON.type('Scroll'));
    if (scroll !== null) {
      try {
        await scroll.scrollToBottom(20000);
        await driver.waitForIdle(450, 1400);
      } catch (_e) {
        // ignore
      }
      commitBtn = await driver.findComponent(matcher);
      if (commitBtn === null) {
        try {
          commitBtn = await scroll.scrollSearch(matcher);
        } catch (_e2) {
          commitBtn = null;
        }
      }
    }
  }
  if (commitBtn === null) {
    for (let i = 0; i < 18; i++) {
      await driver.fling(UiDirection.DOWN, 8500);
      await driver.waitForIdle(350, 900);
      commitBtn = await driver.findComponent(matcher);
      if (commitBtn !== null) {
        break;
      }
    }
  }
  if (commitBtn === null) {
    commitBtn = await driver.findComponent(ON.type('Button').isAfter(ON.text('上一步（改条件）')));
  }
  if (commitBtn === null) {
    throw new Error('候选步未找到「确认导入」按钮（已尝试 Scroll + fling + isAfter 兜底）');
  }
  await commitBtn.click();
}
