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
  /** 页内 Button/Text 点击、DEBUG 入口、Tab 切换、对话框（1500ms） */
  FAST: 1500,
  /** 列表行、详情底栏、页面就绪等轻导航（3000ms；全量测试需更长等待） */
  NORMAL: 3000,
  /** 等待导入扫描完成 → 候选步（5s；扫描循环约 3s + 余量） */
  SCAN: 5000,
  /** 冷启动首屏（8s；首次真正冷启动 + 安全余量） */
  COLD_START: 8000,
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

/** 判断是否为 uitest 并发冲突错误 */
function isConcurrentError(e: Object): boolean {
  const msg = String(e);
  return msg.includes('concurrently') || msg.includes('dose not allow');
}

/** findComponents 安全封装，防御 null/undefined，含并发错误重试。 */
export async function safeFindComponents(driver: Driver, onLike: On, maxRetries: number = 3): Promise<Component[]> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const raw = await driver.findComponents(onLike);
      if (raw === null || raw === undefined) {
        return [];
      }
      return raw;
    } catch (e) {
      if (isConcurrentError(e as Object) && attempt < maxRetries - 1) {
        await sleepMs(2000 * (attempt + 1));
        continue;
      }
      throw new Error('safeFindComponents: ' + String(e));
    }
  }
  return [];
}

// ── 快速失败点击 ──────────────────────────────────────────────

/**
 * 安全点击：先 waitForComponent 等待组件出现（默认 FAST=1500ms），再点击。
 * 超时即抛错实现快速失败。含并发错误重试。
 */
export async function clickComponentSafely(driver: Driver, matcher: On, timeoutMs: number = V2_TIMEOUT.FAST): Promise<void> {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const comp = await driver.waitForComponent(matcher, timeoutMs);
      if (comp === null) {
        throw new Error('clickComponentSafely: 组件未找到（超时 ' + timeoutMs + 'ms）: ' + JSON.stringify(matcher));
      }
      await comp.click();
      return;
    } catch (e) {
      if (isConcurrentError(e as Object) && attempt < 2) {
        await sleepMs(2000 * (attempt + 1));
        continue;
      }
      throw new Error('clickComponentSafely: ' + String(e));
    }
  }
}

/**
 * 点击 AlertDialog 中的确认按钮（如「删除」）。
 * ON.text('删除') 是包含匹配，会同时匹配「删除人物」「确认删除」等文本。
 * AlertDialog 中的按钮是最后添加的组件，所以取 findComponents 的最后一个。
 */
export async function clickDialogConfirmButton(driver: Driver, buttonText: string): Promise<void> {
  const allMatches = await safeFindComponents(driver, ON.text(buttonText));
  if (allMatches.length === 0) {
    throw new Error('clickDialogConfirmButton: 未找到文本「' + buttonText + '」的组件');
  }
  // AlertDialog 中的按钮是最后添加的，取最后一个
  await allMatches[allMatches.length - 1].click();
}

/** 按精确文本找 Button 并点击。默认使用 NORMAL 超时，避免 Sheet 动画后组件短暂不可见。 */
export async function clickButtonByText(driver: Driver, text: string, timeoutMs: number = V2_TIMEOUT.NORMAL): Promise<void> {
  await clickComponentSafely(driver, ON.text(text).type('Button'), timeoutMs);
}

/** 等待指定文本出现在页面上，超时即快速失败。含并发错误重试。 */
export async function waitForText(driver: Driver, text: string, timeoutMs: number = V2_TIMEOUT.NORMAL): Promise<Component> {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const comp = await driver.waitForComponent(ON.text(text), timeoutMs);
      if (comp === null) {
        throw new Error('waitForText: 文本未找到（超时 ' + timeoutMs + 'ms）: ' + text);
      }
      return comp;
    } catch (e) {
      if (isConcurrentError(e as Object) && attempt < 2) {
        await sleepMs(2000 * (attempt + 1));
        continue;
      }
      throw new Error('waitForText: ' + String(e));
    }
  }
  throw new Error('waitForText: 文本未找到（重试耗尽）: ' + text);
}

/** 断言指定文本存在于页面上（快速失败）。 */
export async function assertTextExist(driver: Driver, text: string, timeoutMs: number = V2_TIMEOUT.NORMAL): Promise<void> {
  await waitForText(driver, text, timeoutMs);
}

/**
 * 断言指定文本存在于列表中（支持滚动查找）。
 * 列表为 newest first（最新在顶部），新创建的项在顶部。
 * 策略：直接 find → fling UP 到顶部再 find（修复列表之前 fling DOWN 离开顶部的问题）
 *       → fling DOWN 逐段查找兜底（防止项在底部）。
 */
export async function assertTextInList(driver: Driver, text: string, timeoutMs: number = V2_TIMEOUT.NORMAL): Promise<void> {
  const matcher = ON.text(text);
  // 1. 直接 find（快速路径，含并发重试）
  if (await safeFindComponent(driver, matcher)) {
    return;
  }
  // 2. fling 到顶部查找（新项在顶部，列表可能之前 fling 过导致顶部不可见）
  for (let i = 0; i < 3; i++) {
    await driver.fling(UiDirection.UP, 3000);
  }
  await sleepMs(600);
  if (await safeFindComponent(driver, matcher)) {
    return;
  }
  // 3. fling 逐段向下滚动查找（兜底，防止项在底部）
  for (let i = 0; i < 4; i++) {
    await driver.fling(UiDirection.DOWN, 3000);
    await sleepMs(800);
    if (await safeFindComponent(driver, matcher)) {
      return;
    }
  }
  throw new Error('assertTextInList: 文本未找到（含滚动查找）: ' + text);
}

/**
 * 断言当前处于人物详情页。
 * PersonDetailPage 标题是动态人物名（非固定文本），以「编辑」按钮+「←」按钮组合判定。
 */
export async function assertOnPersonDetail(driver: Driver, displayName?: string, timeoutMs: number = V2_TIMEOUT.NORMAL): Promise<void> {
  // 详情页顶栏必有「编辑」按钮
  await waitForText(driver, '编辑', timeoutMs);
  // 如果指定了 displayName，额外验证标题
  if (displayName !== undefined && displayName.length > 0) {
    await waitForText(driver, displayName, timeoutMs);
  }
}

/**
 * 断言当前处于故事详情页。
 * StoryDetailPage 标题是动态故事标题（非固定文本），以「编辑」按钮+「←」按钮组合判定。
 */
export async function assertOnStoryDetail(driver: Driver, storyTitle?: string, timeoutMs: number = V2_TIMEOUT.NORMAL): Promise<void> {
  // 详情页顶栏必有「编辑」按钮
  await waitForText(driver, '编辑', timeoutMs);
  // 如果指定了 storyTitle，额外验证标题
  if (storyTitle !== undefined && storyTitle.length > 0) {
    await waitForText(driver, storyTitle, timeoutMs);
  }
}

// ── 页面导航 + 断言 ────────────────────────────────────────────

/**
 * 关闭可能残留的 bindSheet。
 * 仅在确认 Sheet 打开时才按返回关闭；Sheet 未打开时不做任何操作。
 */
async function closeAnyOpenSheet(driver: Driver): Promise<void> {
  const sheetIndicators = ['新建人物', '新建故事'];
  for (const indicator of sheetIndicators) {
    if (await safeFindComponent(driver, ON.text(indicator))) {
      await driver.pressBack();
      await driver.waitForIdle(300, 800);
      return;
    }
  }
}

/**
 * 等待 bindSheet 关闭：轮询检测指定文本消失。
 * 最多等待 2000ms，每 200ms 检查一次。
 * 超时不强制 pressBack——避免在 Sheet 已关闭时误导航离开当前页面。
 */
async function waitSheetClosed(driver: Driver, sheetTitle: string): Promise<void> {
  const maxWait = 3000;
  const interval = 300;
  const start = Date.now();
  while (Date.now() - start < maxWait) {
    const found = await safeFindComponent(driver, ON.text(sheetTitle));
    if (!found) {
      await driver.waitForIdle(200, 500);
      return;
    }
    await sleepMs(interval);
  }
  // 超时不强制 pressBack，仅等待 UI 稳定
  await driver.waitForIdle(300, 800);
}

/**
 * 获取或创建主应用 Driver。
 * 分层串行设计：L3 先执行并启动 EntryAbility，E2E 复用已运行的 Ability，
 * 无需冷启动，单用例耗时 ~2s，远低于 Hypium 默认 5s 超时。
 */
let cachedDriver: Driver | undefined = undefined;

function getDriver(): Driver {
  if (cachedDriver === undefined) {
    cachedDriver = Driver.create();
  }
  return cachedDriver;
}

/** 冷启动主应用，等待 ShellPage「人物」Tab 出现。
 *  策略：先等待足够时间让上一个用例的 native 层 uitest 操作完成，
 *  然后检测当前页面，如果已在 ShellPage 则等待 UI 稳定后返回；
 *  如果不在 ShellPage，通过 pressBack 回退到 ShellPage；
 *  如果 pressBack 无法回到 ShellPage，则通过 startAbility 冷启动。
 *
 *  ShellPage 检测：用「人物」+「故事」同时存在来判断。
 *  不能单独用「人物」，因为 PersonDetailPage 有 Text(displayName ?? '人物')；
 *  不能单独用「人脸建议」，因为故事 Tab 下不可见；
 *  只有 ShellPage 同时有「人物」和「故事」两个 Tab 文本。
 */
export async function coldStartMainApp(): Promise<Driver> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const bn = resolveBundleName();

  // 等待上一个用例的 native 层 uitest 操作完成（防止并发冲突）
  await sleepMs(3000);

  const driver = getDriver();

  // 先检测是否已在 ShellPage（「人物」+「故事」同时存在）
  const alreadyOnShell = await isOnShellPage(driver);
  if (alreadyOnShell) {
    // 即使已在 ShellPage，也要等待 UI 完全稳定
    await driver.waitForIdle(500, 1500);
    await sleepMs(1000);
    return driver;
  }

  // 不在 ShellPage，尝试 pressBack 回退（最多 8 次）
  for (let i = 0; i < 8; i++) {
    try {
      await driver.pressBack();
      await sleepMs(800);
    } catch (e) {
      const msg = String(e);
      if (msg.includes('concurrently') || msg.includes('dose not allow')) {
        // 并发冲突，等待更长时间
        await sleepMs(3000);
      }
      // pressBack 可能失败，继续尝试
    }
    if (await isOnShellPage(driver)) {
      await driver.waitForIdle(500, 1500);
      await sleepMs(1000);
      return driver;
    }
  }

  // pressBack 无法回到 ShellPage，使用 startAbility 冷启动
  const want: Want = {
    bundleName: bn,
    abilityName: 'EntryAbility'
  };
  const monitor: abilityDelegatorRegistry.AbilityMonitor = {
    abilityName: 'EntryAbility'
  };
  await delegator.addAbilityMonitor(monitor);
  try {
    await delegator.startAbility(want);
    await delegator.waitAbilityMonitor(monitor, 8000);
  } catch (e) {
    console.info('coldStartMainApp: startAbility exception, continuing: ' + String(e));
  } finally {
    try {
      await delegator.removeAbilityMonitor(monitor);
    } catch (_e) {
      // ignore
    }
  }
  await sleepMs(1000);

  // startAbility 后应用可能仍在子页面，尝试 pressBack 回退到 ShellPage
  for (let i = 0; i < 8; i++) {
    if (await isOnShellPage(driver)) {
      await driver.waitForIdle(500, 1500);
      await sleepMs(1000);
      return driver;
    }
    try {
      await driver.pressBack();
      await sleepMs(800);
    } catch (e) {
      const msg = String(e);
      if (msg.includes('concurrently') || msg.includes('dose not allow')) {
        await sleepMs(3000);
      }
    }
  }

  // 等待 ShellPage 出现（带并发错误重试）
  let shell: Component | null = null;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      shell = await driver.waitForComponent(ON.text('故事'), V2_TIMEOUT.COLD_START);
      break;
    } catch (e) {
      const msg = String(e);
      if (msg.includes('concurrently') || msg.includes('dose not allow')) {
        await sleepMs(3000);
        continue;
      }
      throw new Error('coldStartMainApp waitForComponent: ' + msg);
    }
  }
  if (shell === null) {
    throw new Error('coldStartMainApp: 无法回到主壳页');
  }
  await driver.waitForIdle(500, 1500);
  return driver;
}

/** 检测是否在 ShellPage：同时存在「人物」和「故事」Tab 文本。
 *  对并发调用错误进行重试：上一个用例超时后 native 层操作可能仍在运行，
 *  导致 findComponent 与正在执行的 scrollSearch/click 冲突。
 */
/** 导出版本：检测是否在 ShellPage */
export async function isOnShellPageExported(driver: Driver): Promise<boolean> {
  return isOnShellPage(driver);
}

async function isOnShellPage(driver: Driver, maxRetries: number = 5): Promise<boolean> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const personTab = await driver.findComponent(ON.text('人物'));
      const storyTab = await driver.findComponent(ON.text('故事'));
      return personTab !== null && storyTab !== null;
    } catch (e) {
      const msg = String(e);
      if (msg.includes('concurrently') || msg.includes('dose not allow')) {
        // 并发调用冲突，等待更长时间后重试
        console.info('isOnShellPage: concurrent call conflict, retry ' + (attempt + 1) + '/' + maxRetries);
        await sleepMs(2000 * (attempt + 1)); // 递增等待：2s, 4s, 6s, 8s, 10s
        continue;
      }
      throw new Error('isOnShellPage unexpected: ' + msg);
    }
  }
  // 重试耗尽，返回 false（不在 ShellPage）
  return false;
}

/** MainShell 标识文本。V2.6 ShellPage 极简版无标题，以「人物」Tab 文本为锚点。 */
function mainShellMatcher(): On {
  return ON.text('人物');
}

/**
 * 回到主壳页（ShellPage，含「人物」Tab）。
 * 策略：先找「人物」Tab → 已到则返回；
 * 否则找「返回人物列表」/「返回故事列表」→ 点击；
 * 否则找「←」按钮（详情页返回）→ 点击；
 * 最后 fallback 到 driver.pressBack。
 */
async function ensureOnMainShell(driver: Driver): Promise<void> {
  const matcher = mainShellMatcher();
  const maxAttempts = 5;

  for (let i = 0; i < maxAttempts; i++) {
    if (await safeFindComponent(driver, matcher)) {
      return;
    }
    // 详情页底部「返回人物列表」/「返回故事列表」按钮
    try {
      const backToPersonList = await driver.findComponent(ON.text('返回人物列表'));
      if (backToPersonList !== null) {
        await backToPersonList.click();
        await driver.waitForIdle(300, 1000);
        continue;
      }
    } catch (_e) { /* ignore */ }
    try {
      const backToStoryList = await driver.findComponent(ON.text('返回故事列表'));
      if (backToStoryList !== null) {
        await backToStoryList.click();
        await driver.waitForIdle(300, 1000);
        continue;
      }
    } catch (_e) { /* ignore */ }
    // 详情页顶栏「←」按钮
    try {
      const backArrow = await driver.findComponent(ON.text('←'));
      if (backArrow !== null) {
        await backArrow.click();
        await driver.waitForIdle(300, 1000);
        continue;
      }
    } catch (_e) { /* ignore */ }
    await driver.pressBack();
    await driver.waitForIdle(300, 800);
  }
  const final = await driver.waitForComponent(matcher, V2_TIMEOUT.FAST);
  if (final === null) {
    throw new Error('ensureOnMainShell: 无法回到主壳页（已尝试 ' + maxAttempts + ' 次）');
  }
}

/** ShellPage → 确认在人物 Tab。PersonPage 为默认 Tab(index 0)，点击「人物」Tab 切换。 */
export async function navigateToPersonFromShell(driver: Driver): Promise<void> {
  // 点击底栏「人物」Tab（最后一个「人物」文本 = Tab 栏位置）
  const personTabs = await safeFindComponents(driver, ON.text('人物'));
  if (personTabs.length > 0) {
    await personTabs[personTabs.length - 1].click();
  }
  // 「人脸建议」按钮是人物页独有元素，确认已进入人物 Tab
  await driver.waitForComponent(ON.text('人脸建议'), V2_TIMEOUT.NORMAL);
  await driver.waitForIdle(300, 800);
}

/** ShellPage → 切换到故事 Tab。点击底栏「故事」Tab，验证已离开人物页。 */
export async function navigateToStoryFromShell(driver: Driver): Promise<void> {
  // 点击底栏「故事」Tab（最后一个「故事」文本 = Tab 栏位置）
  const storyTabs = await safeFindComponents(driver, ON.text('故事'));
  if (storyTabs.length > 0) {
    await storyTabs[storyTabs.length - 1].click();
  }
  // 等待 Tab 切换动画完成
  await driver.waitForIdle(300, 800);
  // 验证已离开人物页：人物页独有元素「人脸建议」应不可见
  // 轮询检测「人脸建议」消失，最多等待 NORMAL 超时
  const start = Date.now();
  while (Date.now() - start < V2_TIMEOUT.NORMAL) {
    const faceFound = await safeFindComponent(driver, ON.text('人脸建议'));
    if (!faceFound) {
      // 「人脸建议」已消失，确认已切换到故事 Tab
      await driver.waitForIdle(200, 500);
      return;
    }
    await sleepMs(200);
  }
  // 超时仍未切换，强制再点击一次「故事」Tab
  const retryTabs = await safeFindComponents(driver, ON.text('故事'));
  if (retryTabs.length > 0) {
    await retryTabs[retryTabs.length - 1].click();
    await driver.waitForIdle(300, 800);
  }
}

/** HarmonyOS Enter 键 keyCode，用于 triggerKey 模拟回车。 */
const KEYCODE_ENTER: number = 2054;

/** 在人物列表页创建人物（点击「+ 创建」→ bindSheet → 输入名称 → Enter 提交）。
 *  利用 TextInputWithKeyboard.onSubmit → doCreatePerson() 完成创建，
 *  绕过 inputText 后按钮从无障碍树消失的问题，无需坐标点击。
 */
export async function createPersonOnPage(driver: Driver, displayName: string): Promise<void> {
  // 重试：全量测试中"+ 创建"点击可能首次未响应，Sheet 未弹出
  let sheetOpened = false;
  for (let attempt = 0; attempt < 2; attempt++) {
    await clickComponentSafely(driver, ON.text('+ 创建'), V2_TIMEOUT.NORMAL);
    try {
      await waitForText(driver, '新建人物', V2_TIMEOUT.NORMAL);
      sheetOpened = true;
      break;
    } catch (_e) {
      if (attempt === 0) {
        await sleepMs(500);
      }
    }
  }
  if (!sheetOpened) {
    throw new Error('createPersonOnPage: 「+ 创建」点击后 Sheet 未弹出（已重试）');
  }
  const input = await driver.waitForComponent(ON.type('TextInput'), V2_TIMEOUT.NORMAL);
  if (input === null) {
    throw new Error('createPersonOnPage: Sheet 中未找到 TextInput');
  }
  await input.inputText(displayName);
  // inputText 后键盘弹出、按钮从无障碍树消失，用 Enter 触发 onSubmit → doCreatePerson
  await driver.triggerKey(KEYCODE_ENTER);
  await waitSheetClosed(driver, '新建人物');
}

/** 在故事列表页创建故事（点击「+ 创建」→ bindSheet → 输入标题 → Enter 提交）。
 *  同 createPersonOnPage，用 Enter 触发 onSubmit → doCreateStory。
 */
export async function createStoryOnPage(driver: Driver, title: string): Promise<void> {
  // 重试：全量测试中"+ 创建"点击可能首次未响应，Sheet 未弹出
  let sheetOpened = false;
  for (let attempt = 0; attempt < 2; attempt++) {
    await clickComponentSafely(driver, ON.text('+ 创建'), V2_TIMEOUT.NORMAL);
    try {
      await waitForText(driver, '新建故事', V2_TIMEOUT.NORMAL);
      sheetOpened = true;
      break;
    } catch (_e) {
      if (attempt === 0) {
        await sleepMs(500);
      }
    }
  }
  if (!sheetOpened) {
    throw new Error('createStoryOnPage: 「+ 创建」点击后 Sheet 未弹出（已重试）');
  }
  const input = await driver.waitForComponent(ON.type('TextInput'), V2_TIMEOUT.NORMAL);
  if (input === null) {
    throw new Error('createStoryOnPage: Sheet 中未找到 TextInput');
  }
  await input.inputText(title);
  await driver.triggerKey(KEYCODE_ENTER);
  await waitSheetClosed(driver, '新建故事');
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
 * 列表为 newest first，新创建的项在顶部。
 * 策略：直接 find → fling UP 到顶部再 find → fling DOWN 逐段查找。
 */
async function openListRowByVisibleText(driver: Driver, label: string, errorPrefix: string): Promise<void> {
  const matcher = ON.text(label);
  // 1. 先尝试直接查找（含并发重试）
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const row = await driver.findComponent(matcher);
      if (row !== null) {
        await row.click();
        return;
      }
    } catch (e) {
      if (isConcurrentError(e as Object) && attempt < 1) {
        await sleepMs(2000);
        continue;
      }
    }
    break;
  }
  // 2. fling 到顶部查找（新项在顶部，列表可能之前 fling 过导致顶部不可见）
  for (let i = 0; i < 3; i++) {
    await driver.fling(UiDirection.UP, 3000);
  }
  await sleepMs(600);
  try {
    const row = await driver.findComponent(matcher);
    if (row !== null) {
      await row.click();
      return;
    }
  } catch (_e) {
    // ignore
  }
  // 3. fling 逐段向下滚动查找（兜底）
  for (let i = 0; i < 4; i++) {
    await driver.fling(UiDirection.DOWN, 3000);
    await sleepMs(800);
    if (await safeFindComponent(driver, matcher)) {
      // 找到了，需要再次 findComponent 获取组件引用来点击
      try {
        const row = await driver.findComponent(matcher);
        if (row !== null) {
          await row.click();
          return;
        }
      } catch (_e) {
        // 并发冲突，继续尝试
      }
    }
  }
  throw new Error(errorPrefix + ': ' + label);
}

export async function openPersonListRowByDisplayName(driver: Driver, displayName: string): Promise<void> {
  await openListRowByVisibleText(driver, displayName, '人物列表未找到行');
}

export async function openStoryListRowByTitle(driver: Driver, title: string): Promise<void> {
  await openListRowByVisibleText(driver, title, '故事列表未找到行');
}

// ── 详情页滚动 ──────────────────────────────────────────────────

/**
 * 在详情页中将目标组件滚入视口。
 * 策略：先直接查找 → 找到 List/Scroll 组件获取边界 → 在组件区域内 swipe 滚动查找。
 * 坐标基于组件实际边界（getBounds），不硬编码设备坐标。
 */
export async function scrollDetailUntilVisible(driver: Driver, matcher: On): Promise<void> {
  // 先尝试 waitForComponent 等待（给页面渲染时间，含并发重试）
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const found = await driver.waitForComponent(matcher, V2_TIMEOUT.NORMAL);
      if (found !== null) {
        return;
      }
    } catch (e) {
      if (isConcurrentError(e as Object) && attempt < 2) {
        await sleepMs(2000 * (attempt + 1));
        continue;
      }
    }
  }
  // 悬浮 DEBUG 工具栏策略：'↓底'始终可见，先滚到底找；找不到再回顶逐页翻
  // 1. 先点 ↓底 一次滚到底
  try {
    const bottomBtn = await driver.findComponent(ON.text('↓底'));
    if (bottomBtn !== null) {
      await bottomBtn.click();
      await sleepMs(1200);
      if (await safeFindComponent(driver, matcher)) {
        return;
      }
      // 2. 点 ↑顶 回到顶部，然后逐页 ↓下 翻找
      const topBtn = await driver.findComponent(ON.text('↑顶'));
      if (topBtn !== null) {
        await topBtn.click();
        await sleepMs(800);
      }
      for (let i = 0; i < 15; i++) {
        const downBtn = await driver.findComponent(ON.text('↓下'));
        if (downBtn !== null) {
          await downBtn.click();
          await sleepMs(600);
          if (await safeFindComponent(driver, matcher)) {
            return;
          }
        } else {
          break;
        }
      }
      throw new Error('scrollDetailUntilVisible: 组件未找到（已通过悬浮 DEBUG 按钮逐页滚动查找）');
    }
  } catch (e) {
    if (e instanceof Error && e.message.includes('组件未找到')) {
      throw e;
    }
  }
  // 没有悬浮 DEBUG 按钮的页面（如详情页、导入页），尝试 drag/swipe
  let scrollComp: Component | null = null;
  try {
    scrollComp = await driver.findComponent(ON.type('List'));
  } catch (_e) { /* ignore */ }
  if (scrollComp === null) {
    try {
      scrollComp = await driver.findComponent(ON.type('Scroll'));
    } catch (_e) { /* ignore */ }
  }
  if (scrollComp !== null) {
    const bounds = await scrollComp.getBounds();
    const centerX = bounds.left + Math.floor((bounds.right - bounds.left) / 2);
    const topY = bounds.top + 30;
    const bottomY = bounds.bottom - 30;
    for (let i = 0; i < 4; i++) {
      try {
        await driver.drag(centerX, bottomY, centerX, topY, 600);
      } catch (_e) { /* ignore */ }
      await sleepMs(800);
      if (await safeFindComponent(driver, matcher)) {
        return;
      }
    }
    for (let i = 0; i < 4; i++) {
      try {
        await driver.swipe(centerX, bottomY, centerX, topY, 2000);
      } catch (_e) { /* ignore */ }
      await sleepMs(500);
      if (await safeFindComponent(driver, matcher)) {
        return;
      }
    }
  }
  throw new Error('scrollDetailUntilVisible: 组件未找到（已滚动查找）');
}

/** 安全 findComponent，含并发错误重试。返回是否找到。 */
async function safeFindComponent(driver: Driver, matcher: On, maxRetries: number = 2): Promise<boolean> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const found = await driver.findComponent(matcher);
      return found !== null;
    } catch (e) {
      if (isConcurrentError(e as Object) && attempt < maxRetries - 1) {
        await sleepMs(2000 * (attempt + 1));
        continue;
      }
      // 非并发错误，视为未找到
      return false;
    }
  }
  return false;
}

// ── 详情页专用操作 ────────────────────────────────────────────

export async function clickDetailEnterImportWizard(driver: Driver): Promise<void> {
  const m = ON.text('进入导入向导壳页');
  await scrollDetailUntilVisible(driver, m);
  await clickComponentSafely(driver, m, V2_TIMEOUT.NORMAL);
}

export async function clickDetailDebugInjectAlbum(driver: Driver): Promise<void> {
  const m = ON.text('【DEBUG】注入相册等价URI');
  await scrollDetailUntilVisible(driver, m);
  // scrollDetailUntilVisible 已确认组件可见，直接 findComponent + click
  const comp = await driver.findComponent(m);
  if (comp !== null) {
    await comp.click();
    return;
  }
  throw new Error('clickDetailDebugInjectAlbum: 组件已滚动到可见但 findComponent 返回 null');
}

export async function clickDetailDebugSameUriAgain(driver: Driver): Promise<void> {
  const m = ON.text('【DEBUG】再注相同URI');
  await scrollDetailUntilVisible(driver, m);
  const comp = await driver.findComponent(m);
  if (comp !== null) {
    await comp.click();
    return;
  }
  throw new Error('clickDetailDebugSameUriAgain: 组件已滚动到可见但 findComponent 返回 null');
}

/**
 * 在详情页 Scroll 内找第 2 个 TextInput 并输入。
 * 使用 within() 限定搜索范围，避免匹配导航栏 TextInput。
 * 去掉 scrollToTop，短迭代提前终止。
 */
async function inputDetailSecondTextInput(driver: Driver, text: string, errorPrefix: string): Promise<void> {
  // within() 限定只在 Scroll 内搜索 TextInput，减少匹配面积
  const withinMatcher = ON.type('TextInput').within(ON.type('Scroll'));
  for (let t = 0; t < 15; t++) {
    const inputs = await safeFindComponents(driver, withinMatcher);
    if (inputs.length >= 2) {
      await inputs[1].inputText(text);
      return;
    }
    // 尝试悬浮 DEBUG 按钮 ↓下（始终可见）
    try {
      const downBtn = await driver.findComponent(ON.text('↓下'));
      if (downBtn !== null) {
        await downBtn.click();
        await sleepMs(600);
        continue;
      }
    } catch (_e) { /* ignore */ }
    // Fallback to fling（对 List 组件有效）
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
  const comp = await driver.findComponent(m);
  if (comp !== null) {
    await comp.click();
    return;
  }
  throw new Error('clickImportDebugPh01Duplicate: 组件已滚动到可见但 findComponent 返回 null');
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
  // 先直接查找
  try {
    const commitBtn = await driver.findComponent(matcher);
    if (commitBtn !== null) {
      await commitBtn.click();
      return;
    }
  } catch (_e) {
    // ignore
  }
  // fling 逐段滚动查找
  for (let i = 0; i < 4; i++) {
    await driver.fling(UiDirection.DOWN, 3000);
    await sleepMs(800);
    try {
      const commitBtn = await driver.findComponent(matcher);
      if (commitBtn !== null) {
        await commitBtn.click();
        return;
      }
    } catch (_e) {
      // 并发冲突，继续尝试
    }
  }
  throw new Error('候选步未找到「确认导入」按钮');
}

/** 在扫描遮罩/结果区点击「确定取消」对话框按钮。 */
export async function clickConfirmCancelDialog(driver: Driver): Promise<void> {
  try {
    const okBtn = await driver.findComponent(ON.text('确定取消'));
    if (okBtn !== null) {
      await okBtn.click();
      return;
    }
  } catch (_e) { /* ignore */ }
  try {
    const alt = await driver.findComponent(ON.text('确定'));
    if (alt !== null) {
      await alt.click();
      return;
    }
  } catch (_e) { /* ignore */ }
  throw new Error('未找到对话框按钮「确定取消」或「确定」');
}

// ── V2.2 新增辅助函数 ──────────────────────────────────────────

/**
 * 通用滚动到文本组件可见（基于 scrollDetailUntilVisible 模式）。
 * 从 Scroll 内部滚动寻找，提供更明确的文本断言。
 */
export async function scrollToText(driver: Driver, text: string, timeoutMs: number = V2_TIMEOUT.NORMAL): Promise<void> {
  const matcher = ON.text(text);
  // 先尝试 waitForComponent 等待（含并发重试）
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const found = await driver.waitForComponent(matcher, timeoutMs);
      if (found !== null) {
        return;
      }
    } catch (e) {
      if (isConcurrentError(e as Object) && attempt < 2) {
        await sleepMs(2000 * (attempt + 1));
        continue;
      }
    }
  }
  // 使用悬浮 DEBUG 工具栏（'↓底'、'↑顶'、'↓下' 始终可见）
  try {
    const bottomBtn = await driver.findComponent(ON.text('↓底'));
    if (bottomBtn !== null) {
      // 1. 先点 ↓底 滚到底
      await bottomBtn.click();
      await sleepMs(1200);
      if (await safeFindComponent(driver, matcher)) {
        return;
      }
      // 2. 回顶逐页翻
      const topBtn = await driver.findComponent(ON.text('↑顶'));
      if (topBtn !== null) {
        await topBtn.click();
        await sleepMs(800);
      }
      for (let i = 0; i < 15; i++) {
        const downBtn = await driver.findComponent(ON.text('↓下'));
        if (downBtn !== null) {
          await downBtn.click();
          await sleepMs(600);
          if (await safeFindComponent(driver, matcher)) {
            return;
          }
        } else {
          break;
        }
      }
      throw new Error('scrollToText: text not found after scrolling (floating DEBUG btns): ' + text);
    }
  } catch (e) {
    if (e instanceof Error && e.message.includes('not found after scrolling')) {
      throw e;
    }
  }
  // 没有 DEBUG 按钮的页面，用 fling 滚动
  for (let i = 0; i < 2; i++) {
    await driver.fling(UiDirection.UP, 3000);
    await sleepMs(400);
  }
  if (await safeFindComponent(driver, matcher)) {
    return;
  }
  for (let i = 0; i < 6; i++) {
    await driver.fling(UiDirection.DOWN, 3000);
    await sleepMs(800);
    if (await safeFindComponent(driver, matcher)) {
      return;
    }
  }
  throw new Error('scrollToText: text not found after scrolling: ' + text);
}

/**
 * 等待 AlertDialog 标题出现（如「确认删除」「超上限阻断」）。
 * AlertDialog 在 Hypium 中表现为普通 Text 组件。
 */
export async function waitForDialog(driver: Driver, title: string, timeoutMs: number = V2_TIMEOUT.NORMAL): Promise<boolean> {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const comp = await driver.waitForComponent(ON.text(title), timeoutMs);
      return comp !== null;
    } catch (e) {
      if (isConcurrentError(e as Object) && attempt < 2) {
        await sleepMs(2000 * (attempt + 1));
        continue;
      }
      return false;
    }
  }
  return false;
}

/**
 * 验证某人物已从 PersonPage 列表中消失（用于删除后断言）。
 * 先寻找该名称，若找到说明删除未生效。
 */
export async function assertPersonListItemNotExist(driver: Driver, displayName: string): Promise<void> {
  // 尝试直接 find（含并发重试）
  if (await safeFindComponent(driver, ON.text(displayName))) {
    throw new Error('人物仍存在于列表中（删除未生效）: ' + displayName);
  }
  // fling 滚动查找以防列表分页
  for (let i = 0; i < 3; i++) {
    await driver.fling(UiDirection.DOWN, 3000);
    await sleepMs(800);
    if (await safeFindComponent(driver, ON.text(displayName))) {
      throw new Error('人物仍存在于列表中（scroll 后找到）: ' + displayName);
    }
  }
}

/**
 * 点击详情页的 DEBUG GC 按钮。
 */
export async function clickDebugGcButton(driver: Driver): Promise<void> {
  const m = ON.text('【DEBUG】GC 孤儿 PhotoRef');
  await scrollDetailUntilVisible(driver, m);
  const comp = await driver.findComponent(m);
  if (comp !== null) {
    await comp.click();
    return;
  }
  throw new Error('clickDebugGcButton: 组件已滚动到可见但 findComponent 返回 null');
}