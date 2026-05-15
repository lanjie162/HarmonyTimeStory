import abilityTest from './Ability.test';
import tier1RdbIntegration from './Tier1RdbIntegration.test';
import v2RegressionB2 from './V2RegressionB2.test';
import v2RegressionPerson from './V2RegressionPerson.test';
import v2RegressionStory from './V2RegressionStory.test';
import v2RegressionSuggestImport from './V2RegressionSuggestImport.test';

export default function testsuite() {
  abilityTest();
  tier1RdbIntegration();
  v2RegressionPerson();
  v2RegressionStory();
  v2RegressionSuggestImport();
  v2RegressionB2();
}
