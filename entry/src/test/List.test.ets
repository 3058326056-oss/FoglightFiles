import localUnitTest from './LocalUnit.test';
import caseEngineTest from './CaseEngine.test';
import boundaryTest from './Boundary.test';
import persistenceTest from './Persistence.test';

export default function testsuite() {
  localUnitTest();
  caseEngineTest();
  boundaryTest();
  persistenceTest();
}
