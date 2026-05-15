import localUnitTest from './LocalUnit.test';
import tier1RepositoryRdb from './Tier1RepositoryRdb.test';

export default function testsuite() {
  localUnitTest();
  tier1RepositoryRdb();
}