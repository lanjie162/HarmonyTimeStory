import { relationalStore } from '@kit.ArkData';
import { ensureSchemaV1 } from '../../../../main/ets/infrastructure/data/RdbSchema';
import { resolveRdbCapableContext } from '../OhosTestRdbContext';

export class TestDbHelper {
  private store: relationalStore.RdbStore | undefined;
  readonly dbName: string;

  constructor() {
    this.dbName = `TestDb_${Date.now()}_${Math.random().toString(36).slice(2, 8)}.db`;
  }

  async setup(): Promise<relationalStore.RdbStore> {
    const ctx = await resolveRdbCapableContext();
    const cfg: relationalStore.StoreConfig = {
      name: this.dbName,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    const s = await relationalStore.getRdbStore(ctx, cfg);
    ensureSchemaV1(s);
    this.store = s;
    return s;
  }

  async teardown(): Promise<void> {
    if (this.store !== undefined) {
      this.store.close();
      this.store = undefined;
    }
    try {
      const ctx = await resolveRdbCapableContext();
      await relationalStore.deleteRdbStore(ctx, this.dbName);
    } catch (_e) {
    }
  }

  getStore(): relationalStore.RdbStore {
    if (this.store === undefined) {
      throw new Error('TestDbHelper: store not initialized, call setup() first');
    }
    return this.store;
  }
}
