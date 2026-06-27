import type { IAppDataStore } from '../../../../main/ets/infrastructure/api/AppDataStore';
import { RepositoryImpl } from '../../../../main/ets/infrastructure/repository/RepositoryImpl';
import { TestDbHelper } from './TestDbHelper';
import { relationalStore } from '@kit.ArkData';

export class ServiceTestContext<T> {
  private store: relationalStore.RdbStore | undefined;
  private repo: RepositoryImpl | undefined;
  private service: T | undefined;
  private dbHelper: TestDbHelper | undefined;
  private readonly factory: (repo: IAppDataStore) => T;

  constructor(factory: (repo: IAppDataStore) => T) {
    this.factory = factory;
  }

  async setup(): Promise<void> {
    this.dbHelper = new TestDbHelper();
    this.store = await this.dbHelper.setup();
    this.repo = new RepositoryImpl();
    this.repo.attachRdb(this.store);
    this.service = this.factory(this.repo);
  }

  async teardown(): Promise<void> {
    this.service = undefined;
    this.repo = undefined;
    if (this.dbHelper !== undefined) {
      await this.dbHelper.teardown();
    }
    this.store = undefined;
  }

  getService(): T {
    if (this.service === undefined) {
      throw new Error('ServiceTestContext: service not initialized');
    }
    return this.service;
  }

  getRepo(): RepositoryImpl {
    if (this.repo === undefined) {
      throw new Error('ServiceTestContext: repo not initialized');
    }
    return this.repo;
  }

  getStore(): relationalStore.RdbStore {
    if (this.store === undefined) {
      throw new Error('ServiceTestContext: store not initialized');
    }
    return this.store;
  }
}
