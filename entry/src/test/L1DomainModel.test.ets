/**
 * L1 单元测试：domain/model 类型定义与枚举值完整性。
 * 无需运行环境依赖，纯数据契约断言。
 */
import { describe, expect, it } from '@ohos/hypium';
import { GenderEnum } from '../../main/ets/domain/model/Models';
import { PersonTypeEnum } from '../../main/ets/domain/model/Models';
import { UriHealthStatus } from '../../main/ets/domain/model/Models';

export default function l1DomainModel(): void {
  describe('L1_domain_model_gender_enum', () => {
    it('L1_gender_values', 0, (): void => {
      expect(GenderEnum.MALE).assertEqual(0);
      expect(GenderEnum.FEMALE).assertEqual(1);
      expect(GenderEnum.UNSPECIFIED).assertEqual(2);
    });

    it('L1_gender_keys_count', 0, (): void => {
      const keys = Object.keys(GenderEnum).filter(k => isNaN(Number(k)));
      expect(keys.length).assertEqual(3);
    });
  });

  describe('L1_domain_model_person_type_enum', () => {
    it('L1_person_type_values', 0, (): void => {
      expect(PersonTypeEnum.BABY).assertEqual(0);
      expect(PersonTypeEnum.ADULT).assertEqual(1);
      expect(PersonTypeEnum.ELDER).assertEqual(2);
      expect(PersonTypeEnum.OTHER).assertEqual(3);
    });

    it('L1_person_type_keys_count', 0, (): void => {
      const keys = Object.keys(PersonTypeEnum).filter(k => isNaN(Number(k)));
      expect(keys.length).assertEqual(4);
    });
  });

  describe('L1_domain_model_uri_health_status', () => {
    it('L1_uri_health_status_values', 0, (): void => {
      expect(UriHealthStatus.UNKNOWN).assertEqual(0);
      expect(UriHealthStatus.HEALTHY).assertEqual(1);
      expect(UriHealthStatus.LOCAL_DELETED).assertEqual(2);
      expect(UriHealthStatus.CLOUD_INACCESSIBLE).assertEqual(3);
    });
  });

  describe('L1_domain_model_person_defaults', () => {
    it('L1_person_default_comment', 0, (): void => {
      expect(PersonTypeEnum.OTHER).assertEqual(3);
    });
  });
}