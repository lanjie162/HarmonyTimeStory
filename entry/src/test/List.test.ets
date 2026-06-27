import localUnitTest from './LocalUnit.test';
import l2PersonDetailLogic from './L2PersonDetailLogic.test';
import l2StoryDetailLogic from './L2StoryDetailLogic.test';
import l1DomainModel from './L1DomainModel.test';

export default function testsuite() {
  localUnitTest();
  l2PersonDetailLogic();
  l2StoryDetailLogic();
  l1DomainModel();
}