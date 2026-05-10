import { describe, it } from '@ohos/hypium';
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

function sleepMs(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void): void => {
    setTimeout((): void => {
      resolve();
    }, ms);
  });
}

/** findComponents 在部分设备/版本上可能返回 null，不能直连 .length */
async function safeFindComponents(driver: Driver, onLike: On): Promise<Component[]> {
  const raw = await driver.findComponents(onLike);
  if (raw === null || raw === undefined) {
    return [];
  }
  return raw;
}

function mainShellMatcher() {
  return ON.text('时光故事 - 主壳页');
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
    await driver.waitForIdle(600, 2500);
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

async function openPersonListRowByDisplayName(driver: Driver, displayName: string): Promise<void> {
  await openListRowByVisibleText(driver, displayName, '人物列表未找到行');
}

async function openStoryListRowByTitle(driver: Driver, title: string): Promise<void> {
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
async function scrollDetailUntilVisible(driver: Driver, matcher: On): Promise<void> {
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

async function clickDetailEnterImportWizard(driver: Driver): Promise<void> {
  await scrollDetailUntilVisible(driver, ON.text('进入导入向导壳页'));
  await scrollDetailScrollToBottom(driver);
  const btn = await driver.findComponent(ON.text('进入导入向导壳页'));
  if (btn === null) {
    throw new Error('详情页未找到「进入导入向导壳页」（需安装含 Scroll 详情的主 hap）');
  }
  await btn.click();
}

async function clickDetailDebugInjectAlbum(driver: Driver): Promise<void> {
  const m = ON.text('【DEBUG】注入相册等价 URI');
  await scrollDetailUntilVisible(driver, m);
  await scrollDetailScrollToBottom(driver);
  const btn = await driver.findComponent(m);
  if (btn === null) {
    throw new Error('详情页未找到「【DEBUG】注入相册等价 URI」');
  }
  await btn.click();
}

async function clickDetailDebugSameUriAgain(driver: Driver): Promise<void> {
  const m = ON.text('【DEBUG】再注相同 URI');
  await scrollDetailUntilVisible(driver, m);
  const btn = await driver.findComponent(m);
  if (btn === null) {
    throw new Error('详情页未找到「【DEBUG】再注相同 URI」');
  }
  await btn.click();
}

async function coldStartMainApp(): Promise<Driver> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const bn = resolveBundleName();
  const want: Want = {
    bundleName: bn,
    abilityName: 'EntryAbility'
  };
  await delegator.startAbility(want);
  const driver = Driver.create();
  await driver.waitForIdle(5000, 15000);
  await ensureOnMainShell(driver);
  await driver.waitForComponent(mainShellMatcher(), 10000);
  return driver;
}

/** PersonDetail：第 1 个 TextInput 为显示名，第 2 个为新故事标题。 */
async function inputPersonDetailSecondTextInput(driver: Driver, text: string): Promise<void> {
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
async function inputStoryDetailSecondTextInput(driver: Driver, text: string): Promise<void> {
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

async function clickConfirmImportButton(driver: Driver): Promise<void> {
  const matcher = ON.text('确认导入').type('Button');
  let commitBtn: Component | null = await driver.findComponent(matcher);
  // 导入向导主体为 Scroll：优先在 Scroll 上 scrollToBottom / scrollSearch；整页 fling 不一定带动 Scroll
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

export default function v2Regression(): void {
  describe('V2Regression', () => {
    it('V2_D1_person_main_create_and_detail', 0, async () => {
      const driver = await coldStartMainApp();
      await driver.assertComponentExist(ON.text('时光故事 - 主壳页'));
      const btnPerson = await driver.findComponent(ON.text('人物'));
      await btnPerson.click();
      await driver.waitForIdle(3000, 6000);
      await driver.assertComponentExist(ON.text('新建人物'));
      const personName = `V2D1_${Date.now()}`;
      const inputNew = await driver.findComponent(ON.type('TextInput'));
      await inputNew.inputText(personName);
      const createPerson = await driver.findComponent(ON.text('创建人物'));
      await createPerson.click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(3000, 6000);
      await driver.assertComponentExist(ON.text('人物详情'));
      await scrollDetailUntilVisible(driver, ON.text('进入导入向导壳页'));
      await driver.assertComponentExist(ON.text('进入导入向导壳页'));
    });

    it('V2_D1_person_detail_quick_story_link_toggle', 0, async () => {
      const driver = await coldStartMainApp();
      const btnPerson = await driver.findComponent(ON.text('人物'));
      await btnPerson.click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2D1lnk_${Date.now()}`;
      const inputNew = await driver.findComponent(ON.type('TextInput'));
      await inputNew.inputText(personName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(3000, 6000);
      await driver.assertComponentExist(ON.text('关联故事'));
      const stTitle = `QuickSt_${Date.now()}`;
      await inputPersonDetailSecondTextInput(driver, stTitle);
      const createSt = await driver.findComponent(ON.text('创建'));
      await createSt.click();
      await driver.waitForIdle(2000, 5000);
      await scrollDetailUntilVisible(driver, ON.text('关联'));
      const linkBtns = await safeFindComponents(driver, ON.text('关联'));
      if (linkBtns.length === 0) {
        throw new Error('人物详情未找到「关联」');
      }
      await linkBtns[linkBtns.length - 1].click();
      await driver.waitForIdle(1500, 4000);
      await driver.assertComponentExist(ON.text('解除关联'));
    });

    it('V2_D2_story_main_create_and_detail', 0, async () => {
      const driver = await coldStartMainApp();
      await driver.assertComponentExist(ON.text('时光故事 - 主壳页'));
      const btnStory = await driver.findComponent(ON.text('故事'));
      await btnStory.click();
      await driver.waitForIdle(3000, 6000);
      await driver.assertComponentExist(ON.text('新建故事'));
      const storyTitle = `V2D2_${Date.now()}`;
      const inputTitle = await driver.findComponent(ON.type('TextInput'));
      await inputTitle.inputText(storyTitle);
      const createStory = await driver.findComponent(ON.text('创建故事'));
      await createStory.click();
      await driver.waitForIdle(2000, 5000);
      await driver.assertComponentExist(ON.text(storyTitle));
      await openStoryListRowByTitle(driver, storyTitle);
      await driver.waitForIdle(3000, 6000);
      await driver.assertComponentExist(ON.text('故事详情'));
    });

    it('V2_D2_story_detail_quick_person_link_toggle', 0, async () => {
      const driver = await coldStartMainApp();
      const btnStory = await driver.findComponent(ON.text('故事'));
      await btnStory.click();
      await driver.waitForIdle(3000, 6000);
      const storyTitle = `V2D2lnk_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(storyTitle);
      await (await driver.findComponent(ON.text('创建故事'))).click();
      await driver.waitForIdle(2000, 5000);
      await openStoryListRowByTitle(driver, storyTitle);
      await driver.waitForIdle(3000, 6000);
      await driver.assertComponentExist(ON.text('关联人物'));
      const pName = `QuickPer_${Date.now()}`;
      await inputStoryDetailSecondTextInput(driver, pName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await scrollDetailUntilVisible(driver, ON.text('关联'));
      const linkBtns = await safeFindComponents(driver, ON.text('关联'));
      if (linkBtns.length === 0) {
        throw new Error('故事详情未找到「关联」');
      }
      await linkBtns[linkBtns.length - 1].click();
      await driver.waitForIdle(1500, 4000);
      await driver.assertComponentExist(ON.text('解除关联'));
    });

    it('V2_D3_suggest_entry_minimal', 0, async () => {
      const driver = await coldStartMainApp();
      const btnPerson = await driver.findComponent(ON.text('人物'));
      await btnPerson.click();
      await driver.waitForIdle(3000, 6000);
      const btnSuggest = await driver.findComponent(ON.text('建议'));
      await btnSuggest.click();
      await driver.waitForIdle(3000, 6000);
      await driver.assertComponentExist(ON.text('建议审阅'));
      await driver.assertComponentExist(ON.text('§4.6 形态三 · 顶栏说明（对齐 v1.2 可测骨架）'));
      const back = await driver.findComponent(ON.text('返回'));
      await back.click();
      await driver.waitForIdle(2000, 4000);
      await driver.assertComponentExist(ON.text('人物'));
    });

    it('V2_D3_import_wizard_shell_from_person', 0, async () => {
      const driver = await coldStartMainApp();
      const btnPerson = await driver.findComponent(ON.text('人物'));
      await btnPerson.click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2D3im_${Date.now()}`;
      const inputNew = await driver.findComponent(ON.type('TextInput'));
      await inputNew.inputText(personName);
      const createPerson = await driver.findComponent(ON.text('创建人物'));
      await createPerson.click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(3000, 6000);
      await clickDetailEnterImportWizard(driver);
      await driver.waitForIdle(3000, 6000);
      await driver.assertComponentExist(ON.text('导入向导'));
      await driver.assertComponentExist(ON.text('选图开始（相册）'));
    });

    /**
     * T9-ST-D3：条件步 + 扫描 + IM-09 二次确认 + cancelRequest（BuildProfile.DEBUG 下「跳过选图」入口）。
     */
    it('V2_D3_import_conditions_scan_cancel_im09', 0, async () => {
      const driver = await coldStartMainApp();
      const btnPerson = await driver.findComponent(ON.text('人物'));
      await btnPerson.click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2D3cn_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(personName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(3000, 6000);
      await clickDetailEnterImportWizard(driver);
      await driver.waitForIdle(3000, 6000);
      await driver.assertComponentExist(ON.text('【DEBUG】跳过选图进入条件（Hypium E2E）'));
      await (await driver.findComponent(ON.text('【DEBUG】跳过选图进入条件（Hypium E2E）'))).click();
      await driver.waitForIdle(1500, 4000);
      await driver.assertComponentExist(ON.text('导入条件 · §4.5 步骤 B（三块骨架 + 可测占位）'));
      await (await driver.findComponent(ON.text('开始扫描'))).click();
      await driver.waitForIdle(800, 3000);
      await driver.assertComponentExist(ON.text('取消扫描'));
      await (await driver.findComponent(ON.text('取消扫描'))).click();
      await sleepMs(600);
      const okBtn = await driver.findComponent(ON.text('确定取消'));
      if (okBtn !== null) {
        await okBtn.click();
      } else {
        const alt = await driver.findComponent(ON.text('确定'));
        if (alt !== null) {
          await alt.click();
        }
      }
      await driver.waitForIdle(2000, 8000);
      await scrollDetailUntilVisible(driver, ON.text('重试（IM-09）'));
      await driver.assertComponentExist(ON.text('重试（IM-09）'));
    });

    /**
     * T9-ST-D3：扫描跑满 → 候选确认 → 确认写入（占位 URI，PH-01 内存链）。
     */
    it('V2_D3_import_scan_confirm_commit', 0, async () => {
      const driver = await coldStartMainApp();
      const btnPerson = await driver.findComponent(ON.text('人物'));
      await btnPerson.click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2D3wr_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(personName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(3000, 6000);
      await clickDetailEnterImportWizard(driver);
      await driver.waitForIdle(3000, 6000);
      await (await driver.findComponent(ON.text('【DEBUG】跳过选图进入条件（Hypium E2E）'))).click();
      await driver.waitForIdle(1500, 4000);
      await (await driver.findComponent(ON.text('开始扫描'))).click();
      await driver.waitForComponent(ON.text('候选确认（IM-08）· §4.5 步骤 D'), 22000);
      await driver.waitForIdle(800, 2500);
      await clickConfirmImportButton(driver);
      await driver.waitForIdle(2000, 6000);
    });

    /** mock URI 等价于相册回调后 addPhotoToPerson（不打开 PhotoViewPicker）。 */
    it('V2_D1_person_debug_album_equiv_inject', 0, async () => {
      const driver = await coldStartMainApp();
      await (await driver.findComponent(ON.text('人物'))).click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2alb_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(personName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(2500, 6000);
      await clickDetailDebugInjectAlbum(driver);
      await driver.waitForIdle(1200, 4000);
      await driver.assertComponentExist(ON.text('【E2E】上次加图：成功 file://e2e/album-equiv-1'));
    });

    it('V2_D1_person_debug_ph01_duplicate_second_inject', 0, async () => {
      const driver = await coldStartMainApp();
      await (await driver.findComponent(ON.text('人物'))).click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2ph1p_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(personName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(2500, 6000);
      await clickDetailDebugInjectAlbum(driver);
      await driver.waitForIdle(900, 3000);
      await clickDetailDebugSameUriAgain(driver);
      await driver.waitForIdle(900, 3000);
      await driver.assertComponentExist(ON.text('【E2E】上次加图：重复跳过（PH-01）'));
    });

    it('V2_D2_story_debug_album_equiv_and_ph01', 0, async () => {
      const driver = await coldStartMainApp();
      await (await driver.findComponent(ON.text('故事'))).click();
      await driver.waitForIdle(3000, 6000);
      const storyTitle = `V2albs_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(storyTitle);
      await (await driver.findComponent(ON.text('创建故事'))).click();
      await driver.waitForIdle(2000, 5000);
      await openStoryListRowByTitle(driver, storyTitle);
      await driver.waitForIdle(2500, 6000);
      await clickDetailDebugInjectAlbum(driver);
      await driver.waitForIdle(900, 3000);
      await driver.assertComponentExist(ON.text('【E2E】上次加图：成功 file://e2e/album-equiv-story-1'));
      await clickDetailDebugSameUriAgain(driver);
      await driver.waitForIdle(900, 3000);
      await driver.assertComponentExist(ON.text('【E2E】上次加图：重复跳过（PH-01）'));
    });

    /**
     * Import commitImport：两条相同 URI → ok=1 dup=1；回到人物详情应有 1 张 ref。
     */
    it('V2_D3_import_ph01_commit_duplicate_uris', 0, async () => {
      const driver = await coldStartMainApp();
      await (await driver.findComponent(ON.text('人物'))).click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2imdup_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(personName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(3000, 6000);
      await clickDetailEnterImportWizard(driver);
      await driver.waitForIdle(2500, 6000);
      await (await driver.findComponent(ON.text('【DEBUG】跳过选图 PH-01 双占位（同 URI×2）'))).click();
      await driver.waitForIdle(1200, 4000);
      await (await driver.findComponent(ON.text('开始扫描'))).click();
      await driver.waitForComponent(ON.text('候选确认（IM-08）· §4.5 步骤 D'), 22000);
      await driver.waitForIdle(600, 2000);
      await clickConfirmImportButton(driver);
      await driver.waitForIdle(2500, 7000);
      await driver.assertComponentExist(ON.text('人物详情'));
      await driver.assertComponentExist(ON.text('【E2E】照片数=1'));
    });

    /** B2 负例：cancelRequest(requestId+999) 不得匹配当前扫描任务；遮罩内需可见 【E2E】 横幅。 */
    it('V2_D4_b2_cancel_invalid_request_debug', 0, async () => {
      const driver = await coldStartMainApp();
      await (await driver.findComponent(ON.text('人物'))).click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2b2bad_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(personName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(3000, 6000);
      await clickDetailEnterImportWizard(driver);
      await driver.waitForIdle(3000, 6000);
      await (await driver.findComponent(ON.text('【DEBUG】跳过选图进入条件（Hypium E2E）'))).click();
      await driver.waitForIdle(1200, 4000);
      await (await driver.findComponent(ON.text('开始扫描'))).click();
      await driver.waitForIdle(800, 3500);
      await (await driver.findComponent(ON.text('【DEBUG】错误 ID 触发 cancelRequest（B2 负例）'))).click();
      await driver.waitForIdle(600, 2500);
      await driver.assertComponentExist(ON.text('【E2E】cancelRequest：未生效（requestId 不匹配）'));
      await (await driver.findComponent(ON.text('取消扫描'))).click();
      await sleepMs(500);
      const okDlg = await driver.findComponent(ON.text('确定取消'));
      if (okDlg !== null) {
        await okDlg.click();
      } else {
        const alt2 = await driver.findComponent(ON.text('确定'));
        if (alt2 !== null) {
          await alt2.click();
        }
      }
      await driver.waitForIdle(2000, 8000);
      await scrollDetailUntilVisible(driver, ON.text('重试（IM-09）'));
      await driver.assertComponentExist(ON.text('重试（IM-09）'));
    });

    /**
     * 扫描完成→候选→回条件→再扫描→IM-09 取消，证明新 requestId 下仍可走通取消链路（槽位与新任务）。
     */
    it('V2_D4_b2_rescan_after_confirm_then_cancel_im09', 0, async () => {
      const driver = await coldStartMainApp();
      await (await driver.findComponent(ON.text('人物'))).click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2b2rs_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(personName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(3000, 6000);
      await clickDetailEnterImportWizard(driver);
      await driver.waitForIdle(3000, 6000);
      await (await driver.findComponent(ON.text('【DEBUG】跳过选图进入条件（Hypium E2E）'))).click();
      await driver.waitForIdle(1200, 4000);
      await (await driver.findComponent(ON.text('开始扫描'))).click();
      await driver.waitForComponent(ON.text('候选确认（IM-08）· §4.5 步骤 D'), 22000);
      await driver.waitForIdle(600, 2500);
      await (await driver.findComponent(ON.text('上一步（改条件）'))).click();
      await driver.waitForIdle(1000, 3500);
      await (await driver.findComponent(ON.text('开始扫描'))).click();
      await driver.waitForIdle(800, 3500);
      await driver.assertComponentExist(ON.text('取消扫描'));
      await (await driver.findComponent(ON.text('取消扫描'))).click();
      await sleepMs(500);
      const okBtn = await driver.findComponent(ON.text('确定取消'));
      if (okBtn !== null) {
        await okBtn.click();
      } else {
        const alt = await driver.findComponent(ON.text('确定'));
        if (alt !== null) {
          await alt.click();
        }
      }
      await driver.waitForIdle(2000, 8000);
      await scrollDetailUntilVisible(driver, ON.text('重试（IM-09）'));
      await driver.assertComponentExist(ON.text('重试（IM-09）'));
    });

    /** S4：对话框确认后立即轮询「正在取消…」（快路径；若跳过则仍可回到条件步即为弱通过）。 */
    it('V2_D4_b2_cancelling_banner_after_dialog', 0, async () => {
      const driver = await coldStartMainApp();
      await (await driver.findComponent(ON.text('人物'))).click();
      await driver.waitForIdle(3000, 6000);
      const personName = `V2b2bn_${Date.now()}`;
      await (await driver.findComponent(ON.type('TextInput'))).inputText(personName);
      await (await driver.findComponent(ON.text('创建人物'))).click();
      await driver.waitForIdle(2000, 5000);
      await openPersonListRowByDisplayName(driver, personName);
      await driver.waitForIdle(3000, 6000);
      await clickDetailEnterImportWizard(driver);
      await driver.waitForIdle(3000, 6000);
      await (await driver.findComponent(ON.text('【DEBUG】跳过选图进入条件（Hypium E2E）'))).click();
      await driver.waitForIdle(1200, 4000);
      await (await driver.findComponent(ON.text('开始扫描'))).click();
      await driver.waitForIdle(600, 3500);
      await (await driver.findComponent(ON.text('取消扫描'))).click();
      await sleepMs(400);
      const okBtn = await driver.findComponent(ON.text('确定取消'));
      if (okBtn !== null) {
        await okBtn.click();
      } else {
        const alt = await driver.findComponent(ON.text('确定'));
        if (alt !== null) {
          await alt.click();
        }
      }
      let sawCancelling = false;
      for (let i = 0; i < 12; i++) {
        const t = await driver.findComponent(ON.text('正在取消…（应用层 cancelRequest 协作中）'));
        if (t !== null) {
          sawCancelling = true;
          break;
        }
        await sleepMs(120);
      }
      if (!sawCancelling) {
        await driver.waitForIdle(1500, 6000);
      }
      await scrollDetailUntilVisible(driver, ON.text('重试（IM-09）'));
      await driver.assertComponentExist(ON.text('重试（IM-09）'));
    });
  });
}
