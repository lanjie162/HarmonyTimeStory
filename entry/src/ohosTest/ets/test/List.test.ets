import abilityTest from './Ability.test';
import tier1RdbIntegration from './Tier1RdbIntegration.test';
import migrationTier2 from './MigrationTier2.test';
import l3PersonService from './L3PersonService.test';
import l3StoryService from './L3StoryService.test';
import l3LinkPhotoService from './L3LinkPhotoService.test';
import l3ImportService from './L3ImportService.test';
import v2RegressionPerson from './V2RegressionPerson.test';
import v2RegressionStory from './V2RegressionStory.test';
import v2RegressionSuggestImport from './V2RegressionSuggestImport.test';
import v2RegressionB2 from './V2RegressionB2.test';
import v2RegressionShell from './V2RegressionShell.test';
import v2RegressionImportFull from './V2RegressionImportFull.test';
import v2RegressionTabs from './V2RegressionTabs.test';
import v2RegressionPhotoSwiper from './V2RegressionPhotoSwiper.test';
import v2RegressionBottomSheet from './V2RegressionBottomSheet.test';
import v2RegressionSwipeAction from './V2RegressionSwipeAction.test';
import v2RegressionImportCondition from './V2RegressionImportCondition.test';
import v2RegressionForm1 from './V2RegressionForm1.test';
import v2RegressionShellTab from './V2RegressionShellTab.test';
import v2RegressionPrivacy from './V2RegressionPrivacy.test';
import v2RegressionCascade from './V2RegressionCascade.test';
import v2RegressionGC from './V2RegressionGC.test';

/**
 * 分层串行执行顺序：L1 → L2 → L3 → E2E
 *
 * 关键设计：L3 测试通过 OhosTestRdbContext.startAbility() 启动 EntryAbility，
 * E2E 测试的 coldStartMainApp() 检测到 Ability 已在运行后直接复用 Driver，
 * 无需冷启动，将 E2E 单用例耗时从 ~5s 降至 ~2s，避免 Hypium 默认 5s 超时。
 */
export default function testsuite() {
  // ── L1: 基础集成 ──
  abilityTest();
  tier1RdbIntegration();

  // ── L2: 迁移验证 ──
  migrationTier2();

  // ── L3: Service 集成（启动 EntryAbility，为 E2E 铺路）──
  l3PersonService();
  l3StoryService();
  l3LinkPhotoService();
  l3ImportService();

  // ── E2E: UI 回归（复用 L3 已启动的 EntryAbility）──
  v2RegressionPerson();
  v2RegressionStory();
  v2RegressionSuggestImport();
  v2RegressionB2();
  v2RegressionShell();
  v2RegressionImportFull();
  v2RegressionTabs();
  v2RegressionPhotoSwiper();
  v2RegressionBottomSheet();
  v2RegressionSwipeAction();
  v2RegressionImportCondition();
  v2RegressionForm1();
  v2RegressionShellTab();
  v2RegressionPrivacy();
  v2RegressionCascade();
  v2RegressionGC();
}
