import type { IPersonService } from '../features/api/Services';
import type { IPhotoRepository } from '../infrastructure/api/InfraPorts';

export interface BootstrapContext {
  personService?: IPersonService;
  photoRepository?: IPhotoRepository;
}

export function createBootstrapContext(): BootstrapContext {
  return {};
}
