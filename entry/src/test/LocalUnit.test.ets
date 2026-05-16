import { describe, it, expect } from '@ohos/hypium';
import { ensureSchemaV1, RDB_SCHEMA_META_VERSION } from '../main/ets/infrastructure/data/RdbSchema';
import { RepositoryImpl } from '../main/ets/infrastructure/repository/RepositoryImpl';
import { requireTrimmedNonEmpty } from '../main/ets/infrastructure/repository/RepositoryTextNormalize';

export default function localUnitTest() {
  describe('tier1_dataLayer_schemaMarkers', () => {
    it('tier1_ensureSchemaV1_is_function', 0, () => {
      expect(typeof ensureSchemaV1).assertEqual('function');
    });
    it('tier1_rdb_schema_meta_version_contract', 0, () => {
      expect(RDB_SCHEMA_META_VERSION).assertEqual(1);
    });
  });

  describe('tier1_repository_singleton', () => {
    it('tier1_repository_getInstance_stable', 0, () => {
      const a = RepositoryImpl.getInstance();
      const b = RepositoryImpl.getInstance();
      expect(a).assertEqual(b);
    });
    it('tier1_repository_getInstance_not_same_as_new', 0, () => {
      const singleton = RepositoryImpl.getInstance();
      const fresh = new RepositoryImpl();
      expect(singleton).assertNotEqual(fresh);
    });
  });

  describe('tier1_repository_text_normalize', () => {
    it('tier1_trim_empty_returns_null', 0, () => {
      expect(requireTrimmedNonEmpty('') === null).assertTrue();
      expect(requireTrimmedNonEmpty('   ') === null).assertTrue();
      expect(requireTrimmedNonEmpty('\t\r\n') === null).assertTrue();
    });
    it('tier1_trim_preserves_inner_spaces', 0, () => {
      expect((requireTrimmedNonEmpty('  a b  ') ?? '')).assertEqual('a b');
    });
    it('tier1_trim_rejects_whitespace_only_after_trim', 0, () => {
      expect(requireTrimmedNonEmpty('\u3000') === null).assertTrue();
    });
  });
}