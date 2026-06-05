import abilityTest from './Ability.test';
import tier1RdbIntegration from './Tier1RdbIntegration.test';
import migrationTier2 from './MigrationTier2.test';
import v2RegressionB2 from './V2RegressionB2.test';
import v2RegressionPerson from './V2RegressionPerson.test';
import v2RegressionStory from './V2RegressionStory.test';
import v2RegressionSuggestImport from './V2RegressionSuggestImport.test';
import v2RegressionShell from './V2RegressionShell.test';
import v2RegressionImportFull from './V2RegressionImportFull.test';
import l3PersonService from './L3PersonService.test';
import l3StoryService from './L3StoryService.test';
import l3LinkPhotoService from './L3LinkPhotoService.test';

export default function testsuite() {
  abilityTest();
  tier1RdbIntegration();
  migrationTier2();
  v2RegressionPerson();
  v2RegressionStory();
  v2RegressionSuggestImport();
  v2RegressionB2();
  v2RegressionShell();
  v2RegressionImportFull();
  l3PersonService();
  l3StoryService();
  l3LinkPhotoService();
}