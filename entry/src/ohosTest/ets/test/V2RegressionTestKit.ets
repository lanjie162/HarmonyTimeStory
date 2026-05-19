import { abilityDelegatorRegistry, Component, Driver, On, ON, UiDirection } from '@kit.TestKit';
import type { Want } from '@kit.AbilityKit';

/**
 * V2_TIMEOUT: 集中分档超时常量，激进快速失败策略。
 * 配置或脚本错误应在数秒内报错，避免长时间等待浪费测试时间。
 */
export interface V2TimeoutConfig {
  FAST: number;
  NORMAL: number;
  SCAN: number;
  COLD_START: number;
}
export const V2_TIMEOUT: V2TimeoutConfig = {
  /** 页内 Button/Text 点击、DEBUG 入口、Tab 切换、对话框（800ms） */
  FAST: 800,
  /** 列表行、详情底栏、页面就绪等轻导航（1500ms） */
  NORMAL: 1500,
  /** 等待导入扫描完成 → 候选步（5s；扫描循环约 3s + 余量） */
  SCAN: 5000,
  /** 冷启动首屏（5s；首次真正冷启动 + 安全余量） */
  COLD_START: 5000,
};

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

/** findComponents 安全封装，防御 null/undefined。 */
export async function safeFindComponents(driver: Driver, onLike: On): Promise<Component[]> {
  const raw = await driver.findComponents(onLike);
  if (raw === null || raw === undefined) {
    return [];
  }
  return raw;
}

// ── 快速失败点击 ──────────────────────────────────────────────

/**
 * 安全点击：先 waitForComponent 等待组件出现（默认 FAST=800ms），再点击。
 * 超时即抛错实现快速失败。
 */
export async function clickComponentSafely(driver: Driver, matcher: On, timeoutMs: number = V2_TIMEOUT.FAST): Promise<void> {
  const comp = await driver.waitForComponent(matcher, timeoutMs);
  if (comp === null) {
    throw new Error('clickComponentSafely: 组件未找到（超时 ' + timeoutMs + 'ms）: ' + JSON.stringify(matcher));
  }
  await comp.click();
}

/** 按精确文本找 Button 并点击。 */
export async function clickButtonByText(driver: Driver, text: string, timeoutMs: number = V2_TIMEOUT.FAST): Promise<void> {
  await clickComponentSafely(driver, ON.text(text).type('Button'), timeoutMs);
}

/** 等待指定文本出现在页面上，超时即快速失败。 */
export async function waitForText(driver: Driver, text: string, timeoutMs: number = V2_TIMEOUT.NORMAL): Promise<Component> {
  const comp = await driver.waitForComponent(ON.text(text), timeoutMs);
  if (comp === null) {
    throw new Error('waitForText: 文本未找到（超时 ' + timeoutMs + 'ms）: ' + text);
  }
  return comp;
}

/** 断言指定文本存在于页面上（快速失败）。 */
export async function assertTextExist(driver: Driver, text: string, timeoutMs: number = V2_TIMEOUT.NORMAL): Promise<void> {
  await waitForText(driver, text, timeoutMs);
}

// ── 页面导航 + 断言 ────────────────────────────────────────────

/** 冷启动主应用，等待 ShellPage「时光故事」标题出现。 */
export async function coldStartMainApp(): Promise<Driver> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const bn = resolveBundleName();
  const want: Want = {
    bundleName: bn,
    abilityName: 'EntryAbility'
  };
  await delegator.startAbility(want);
  const driver = Driver.create();
  // 先快速检查（约 0.01s）：如果已处于 ShellPage 直接返回
  let shell = await driver.findComponent(ON.text('时光故事'));
  if (shell === null) {
    // 立即进入 fallback，不浪费 20s 盲等
    await ensureOnMainShell(driver);
    shell = await driver.waitForComponent(ON.text('时光故事'), V2_TIMEOUT.COLD_START);
    if (shell === null) {
      throw new Error('coldStartMainApp: 无法回到主壳页');
    }
  }
  await driver.waitForIdle(300, 800);
  return driver;
}

/** MainShell 标识文本。 */
function mainShellMatcher(): On {
  return ON.text('时光故事');
}

/**
 * 回到主壳页（ShellPage，含「时光故事」标题）。
 * 策略简洁：先找「时光故事」→ 已到则返回；
 * 否则找「返回列表」→ 点击；找「返回」→ 点击；
 * 最后 fallback 到 driver.fling + pressBack。
 */
async function ensureOnMainShell(driver: Driver): Promise<void> {
  const matcher = mainShellMatcher();
  const maxAttempts = 4;

  for (let i = 0; i < maxAttempts; i++) {
    const main = await driver.findComponent(matcher);
    if (main !== null) {
      return;
    }
    const backToList = await driver.findComponent(ON.text('返回列表'));
    if (backToList !== null) {
      await backToList.click();
      await driver.waitForIdle(300, 1000);
      continue;
    }
    const backBtn = await driver.findComponent(ON.text('返回'));
    if (backBtn !== null) {
      await backBtn.click();
      await driver.waitForIdle(300, 1000);
      continue;
    }
    await driver.pressBack();
    await driver.waitForIdle(300, 800);
  }
  const final = await driver.waitForComponent(matcher, V2_TIMEOUT.FAST);
  if (final === null) {
    throw new Error('ensureOnMainShell: 无法回到主壳页（已尝试 ' + maxAttempts + ' 次）');
  }
}

/** ShellPage → 点击「人物」卡片 → 等待 PersonPage。 */
export async function navigateToPersonFromShell(driver: Driver): Promise<void> {
  const personCards = await safeFindComponents(driver, ON.text('人物').type('Column'));
  if (personCards.length > 0) {
    await personCards[0].click();
  } else {
    await clickComponentSafely(driver, ON.text('人物'));
  }
  // 人物页有两个「人物」文本（标题 + Tab），等待「新建人物」出现确认已进入
  await driver.waitForComponent(ON.text('新建人物'), V2_TIMEOUT.NORMAL);
  await driver.waitForIdle(300, 800);
}

/** ShellPage → 点击「故事」卡片 → 等待 StoryPage。 */
export async function navigateToStoryFromShell(driver: Driver): Promise<void> {
  const storyCards = await safeFindComponents(driver, ON.text('故事').type('Column'));
  if (storyCards.length > 0) {
    // 第一个「故事」Column 是壳页入口卡片
    await storyCards[0].click();
  } else {
    await clickComponentSafely(driver, ON.text('故事'));
  }
  await driver.waitForComponent(ON.text('新建故事'), V2_TIMEOUT.NORMAL);
  await driver.waitForIdle(300, 800);
}

/** 在人物列表页创建人物（输入名称 + 点击「创建人物」）。 */
export async function createPersonOnPage(driver: Driver, displayName: string): Promise<void> {
  const input = await driver.findComponent(ON.type('TextInput'));
  if (input === null) {
    throw new Error('createPersonOnPage: 未找到 TextInput');
  }
  await input.inputText(displayName);
  await clickButtonByText(driver, '创建人物');
  await driver.waitForIdle(300, 800);
}

/** 在故事列表页创建故事（输入标题 + 点击「创建故事」）。 */
export async function createStoryOnPage(driver: Driver, title: string): Promise<void> {
  const input = await driver.findComponent(ON.type('TextInput'));
  if (input === null) {
    throw new Error('createStoryOnPage: 未找到 TextInput');
  }
  await input.inputText(title);
  await clickButtonByText(driver, '创建故事');
  await driver.waitForIdle(300, 800);
}

// ── 列表滚动与行定位 ──────────────────────────────────────────

/**
 * 在 List 中通过 scrollSearch 找到指定文本的行并点击。
 * scrollSearch 内部增量滚动，找到即停，无需 scrollToBottom 盲等。
 */
async function scrollListToFindRow(list: Component, matcher: On): Promise<Component | null> {
  try {
    const row = await list.scrollSearch(matcher, true, 30);
    if (row !== null) {
      return row;
    }
  } catch (_e) {
    // ignore
  }
  return null;
}

/**
 * 在列表中通过可见文本定位行并点击。
 * 策略：先直接 find，失败后 scrollSearch 每个 List，最后短迭代 fling 兜底。
 */
async function openListRowByVisibleText(driver: Driver, label: string, errorPrefix: string): Promise<void> {
  const matcher = ON.text(label);
  let row: Component | null = await driver.findComponent(matcher);
  if (row !== null) {
    await row.click();
    return;
  }
  const lists = await safeFindComponents(driver, ON.type('List'));
  for (const list of lists) {
    row = await scrollListToFindRow(list, matcher);
    if (row !== null) {
      await row.click();
      return;
    }
  }
  if (row === null) {
    // fling 短迭代兜底
    for (let i = 0; i < 3; i++) {
      await driver.fling(UiDirection.DOWN, 6000);
      await driver.waitForIdle(300, 600);
      row = await driver.findComponent(matcher);
      if (row !== null) {
        break;
      }
    }
  }
  if (row === null) {
    throw new Error(errorPrefix + ': ' + label);
  }
  await row.click();
}

export async function openPersonListRowByDisplayName(driver: Driver, displayName: string): Promise<void> {
  await openListRowByVisibleText(driver, displayName, '人物列表未找到行');
}

export async function openStoryListRowByTitle(driver: Driver, title: string): Promise<void> {
  await openListRowByVisibleText(driver, title, '故事列表未找到行');
}

// ── 详情页滚动 ──────────────────────────────────────────────────

/**
 * 在详情页 Scroll 中将目标组件滚入视口。
 * 策略：findComponent 先行 → scrollSearch(vertical, offset) → 短迭代 fling 兜底。
 * scrollSearch 是唯一不盲等的滚动 API（增量滚动，找到即停）。
 * offset=30 让滚动起止点距 Scroll 边框 30px，避免滑入标题栏。
 */
export async function scrollDetailUntilVisible(driver: Driver, matcher: On): Promise<void> {
  if ((await driver.findComponent(matcher)) !== null) {
    return;
  }
  const scrolls = await safeFindComponents(driver, ON.type('Scroll'));
  for (const sc of scrolls) {
    try {
      const hit = await sc.scrollSearch(matcher, true, 30);
      if (hit !== null) {
        return;
      }
    } catch (_e) {
      // ignore
    }
  }
  // fling 短迭代兜底（scrollSearch 已覆盖 95%+ 场景）
  for (let i = 0; i < 2; i++) {
    await driver.fling(UiDirection.DOWN, 6000);
    await driver.waitForIdle(300, 600);
    if ((await driver.findComponent(matcher)) !== null) {
      return;
    }
  }
}

// ── 详情页专用操作 ────────────────────────────────────────────

export async function clickDetailEnterImportWizard(driver: Driver): Promise<void> {
  await scrollDetailUntilVisible(driver, ON.text('进入导入向导壳页'));
  await clickButtonByText(driver, '进入导入向导壳页');
}

export async function clickDetailDebugInjectAlbum(driver: Driver): Promise<void> {
  const m = ON.text('【DEBUG】注入相册等价 URI');
  await scrollDetailUntilVisible(driver, m);
  await clickComponentSafely(driver, m);
}

export async function clickDetailDebugSameUriAgain(driver: Driver): Promise<void> {
  const m = ON.text('【DEBUG】再注相同 URI');
  await scrollDetailUntilVisible(driver, m);
  await clickComponentSafely(driver, m);
}

/**
 * 在详情页 Scroll 内找第 2 个 TextInput 并输入。
 * 使用 within() 限定搜索范围，避免匹配导航栏 TextInput。
 * 去掉 scrollToTop，短迭代提前终止。
 */
async function inputDetailSecondTextInput(driver: Driver, text: string, errorPrefix: string): Promise<void> {
  // within() 限定只在 Scroll 内搜索 TextInput，减少匹配面积
  const withinMatcher = ON.type('TextInput').within(ON.type('Scroll'));
  for (let t = 0; t < 3; t++) {
    const inputs = await safeFindComponents(driver, withinMatcher);
    if (inputs.length >= 2) {
      await inputs[1].inputText(text);
      return;
    }
    await driver.fling(UiDirection.DOWN, 6000);
    await driver.waitForIdle(300, 600);
  }
  throw new Error(errorPrefix + ': 未收集到至少 2 个 TextInput');
}

/** PersonDetail: 第 2 个 TextInput（新故事标题）。 */
export async function inputPersonDetailSecondTextInput(driver: Driver, text: string): Promise<void> {
  await inputDetailSecondTextInput(driver, text, 'PersonDetail');
}

/** StoryDetail: 第 1 个为标题，第 2 个为新人物名。 */
export async function inputStoryDetailSecondTextInput(driver: Driver, text: string): Promise<void> {
  await inputDetailSecondTextInput(driver, text, 'StoryDetail');
}

// ── Import 域专用 helper ──────────────────────────────────────

export async function clickImportDebugSkipToConditions(driver: Driver): Promise<void> {
  const m = ON.text('【DEBUG】跳过选图进入条件（Hypium E2E）');
  await scrollDetailUntilVisible(driver, m);
  const comp = await driver.findComponent(m);
  if (comp !== null) {
    await comp.click();
    return;
  }
  const pickLabel = await driver.findComponent(ON.text('选图开始（相册）'));
  if (pickLabel !== null) {
    throw new Error(
      'ImportPage DEBUG 入口不可见：已滚动仍未找到 DEBUG 按钮，当前处于 pick 步。'
      + ' 请确认 entry@default 为 debug/LogVerification 构建（BuildProfile.DEBUG）'
    );
  }
  throw new Error('进入 ImportPage 后未进入 pick 步（未找到「选图开始（相册）」）');
}

export async function clickImportDebugPh01Duplicate(driver: Driver): Promise<void> {
  const m = ON.text('【DEBUG】跳过选图 PH-01 双占位（同 URI×2）');
  await scrollDetailUntilVisible(driver, m);
  await clickComponentSafely(driver, m);
}

export async function clickImportStartScan(driver: Driver): Promise<void> {
  const m = ON.text('开始扫描');
  await scrollDetailUntilVisible(driver, m);
  await clickComponentSafely(driver, m);
}

export async function clickImportDebugB2WrongCancel(driver: Driver): Promise<void> {
  const m = ON.text('【DEBUG】错误 ID 触发 cancelRequest（B2 负例）');
  const comp = await driver.waitForComponent(m, V2_TIMEOUT.NORMAL);
  if (comp !== null) {
    await comp.click();
    return;
  }
  await scrollDetailUntilVisible(driver, m);
  await clickComponentSafely(driver, m);
}

export async function clickImportCancelScan(driver: Driver): Promise<void> {
  const m = ON.text('取消扫描');
  const comp = await driver.waitForComponent(m, V2_TIMEOUT.NORMAL);
  if (comp !== null) {
    await comp.click();
    return;
  }
  await scrollDetailUntilVisible(driver, m);
  await clickComponentSafely(driver, m);
}

/** 在候选步点击「确认导入」。 */
export async function clickConfirmImportButton(driver: Driver): Promise<void> {
  const matcher = ON.text('确认导入').type('Button');
  let commitBtn: Component | null = await driver.findComponent(matcher);
  if (commitBtn === null) {
    const scroll = await driver.findComponent(ON.type('Scroll'));
    if (scroll !== null) {
      try {
        commitBtn = await scroll.scrollSearch(matcher, true, 30);
      } catch (_e) {
        commitBtn = null;
      }
    }
  }
  if (commitBtn === null) {
    for (let i = 0; i < 2; i++) {
      await driver.fling(UiDirection.DOWN, 6000);
      await driver.waitForIdle(300, 600);
      commitBtn = await driver.findComponent(matcher);
      if (commitBtn !== null) {
        break;
      }
    }
  }
  if (commitBtn === null) {
    throw new Error('候选步未找到「确认导入」按钮');
  }
  await commitBtn.click();
}

/** 在扫描遮罩/结果区点击「确定取消」对话框按钮。 */
export async function clickConfirmCancelDialog(driver: Driver): Promise<void> {
  const okBtn = await driver.findComponent(ON.text('确定取消'));
  if (okBtn !== null) {
    await okBtn.click();
    return;
  }
  const alt = await driver.findComponent(ON.text('确定'));
  if (alt !== null) {
    await alt.click();
    return;
  }
  throw new Error('未找到对话框按钮「确定取消」或「确定」');
}