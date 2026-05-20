import type { PersonModel, PhotoRefModel, PhotoAddResult, StoryModel } from '../../domain/model/Models';
import { PersonTypeEnum as PT } from '../../domain/model/Models';

interface PersonStoryTuple {
  personId: number;
  storyId: number;
}

interface PhotoOwnerTuple {
  id: number;
  ownerKind: 'person' | 'story';
  ownerId: number;
  photoRefId: number;
}

function defaultPersonModel(id: number, displayName: string): PersonModel {
  return {
    id,
    displayName,
    avatarBlob: null,
    birthday: null,
    gender: null,
    remark: '',
    personType: PT.OTHER
  };
}

function defaultStoryModel(id: number, title: string): StoryModel {
  return {
    id,
    title,
    description: '',
    timeStart: null,
    timeEnd: null,
    coverUri: '',
    location: '',
    tags: []
  };
}

function clonePerson(p: PersonModel): PersonModel {
  return {
    id: p.id,
    displayName: p.displayName,
    avatarBlob: p.avatarBlob,
    birthday: p.birthday,
    gender: p.gender,
    remark: p.remark,
    personType: p.personType
  };
}

function cloneStory(s: StoryModel): StoryModel {
  return {
    id: s.id,
    title: s.title,
    description: s.description,
    timeStart: s.timeStart,
    timeEnd: s.timeEnd,
    coverUri: s.coverUri,
    location: s.location,
    tags: [...s.tags]
  };
}

/**
 * MVP 单机内存仓储（**非主路径真相**）：进程内闭环，关机即清空。
 * 主应用自 V2.1-T17 起使用 `RepositoryImpl` + RDB；本类保留供显式注入/调试，勿再经 `singletonMemoryStore` 作为生产唯一真相。
 */
export class LocalMemoryStore {
  private persons: PersonModel[] = [];
  private stories: StoryModel[] = [];
  private personStories: PersonStoryTuple[] = [];
  private photoRefs: PhotoRefModel[] = [];
  private ownerLinks: PhotoOwnerTuple[] = [];
  private nextPersonId = 1;
  private nextStoryId = 1;
  private nextPhotoId = 1;
  private nextLinkId = 1;

  listPersons(): PersonModel[] {
    const out: PersonModel[] = [];
    for (const p of this.persons) {
      out.push(clonePerson(p));
    }
    return out;
  }

  createPerson(displayName: string): number {
    const t = displayName.trim();
    if (t.length === 0) {
      return -1;
    }
    const id = this.nextPersonId++;
    this.persons.push(defaultPersonModel(id, t));
    return id;
  }

  getPerson(id: number): PersonModel | null {
    const p = this.persons.find((x): boolean => x.id === id);
    return p ? clonePerson(p) : null;
  }

  updatePerson(id: number, displayName: string): boolean {
    const t = displayName.trim();
    if (t.length === 0) {
      return false;
    }
    const p = this.persons.find((x): boolean => x.id === id);
    if (!p) {
      return false;
    }
    p.displayName = t;
    return true;
  }

  listStories(): StoryModel[] {
    return this.stories.map((s): StoryModel => cloneStory(s));
  }

  createStory(title: string): number {
    const t = title.trim();
    if (t.length === 0) {
      return -1;
    }
    const id = this.nextStoryId++;
    this.stories.push(defaultStoryModel(id, t));
    return id;
  }

  getStory(id: number): StoryModel | null {
    const s = this.stories.find((x): boolean => x.id === id);
    return s ? cloneStory(s) : null;
  }

  updateStory(id: number, title: string): boolean {
    const t = title.trim();
    if (t.length === 0) {
      return false;
    }
    const s = this.stories.find((x): boolean => x.id === id);
    if (!s) {
      return false;
    }
    s.title = t;
    return true;
  }

  linkedPersonsForStory(storyId: number): PersonModel[] {
    const ids = new Set<number>();
    for (const ps of this.personStories) {
      if (ps.storyId === storyId) {
        ids.add(ps.personId);
      }
    }
    const out: PersonModel[] = [];
    for (const p of this.persons) {
      if (ids.has(p.id)) {
        out.push(clonePerson(p));
      }
    }
    return out;
  }

  linkPersonStory(personId: number, storyId: number): void {
    if (!this.persons.some((p): boolean => p.id === personId)) {
      return;
    }
    if (!this.stories.some((s): boolean => s.id === storyId)) {
      return;
    }
    if (this.personStories.some((ps): boolean => ps.personId === personId && ps.storyId === storyId)) {
      return;
    }
    this.personStories.push({ personId, storyId });
  }

  unlinkPersonStory(personId: number, storyId: number): void {
    const idx = this.personStories.findIndex(
      (ps): boolean => ps.personId === personId && ps.storyId === storyId
    );
    if (idx >= 0) {
      this.personStories.splice(idx, 1);
    }
  }

  linkedStoriesForPerson(personId: number): StoryModel[] {
    const ids = new Set<number>();
    for (const ps of this.personStories) {
      if (ps.personId === personId) {
        ids.add(ps.storyId);
      }
    }
    const result: StoryModel[] = [];
    for (const s of this.stories) {
      if (ids.has(s.id)) {
        result.push(cloneStory(s));
      }
    }
    return result;
  }

  isPersonStoryLinked(personId: number, storyId: number): boolean {
    return this.personStories.some((ps): boolean => ps.personId === personId && ps.storyId === storyId);
  }

  photosForPerson(personId: number): PhotoRefModel[] {
    const refIds = new Set<number>();
    for (const l of this.ownerLinks) {
      if (l.ownerKind === 'person' && l.ownerId === personId) {
        refIds.add(l.photoRefId);
      }
    }
    const out: PhotoRefModel[] = [];
    for (const pr of this.photoRefs) {
      if (refIds.has(pr.id)) {
        out.push({ id: pr.id, uri: pr.uri });
      }
    }
    return out;
  }

  addPhotoForPerson(personId: number, uri: string): PhotoAddResult {
    if (!this.persons.some((p): boolean => p.id === personId)) {
      return { success: false, duplicate: false };
    }
    const trimmed = uri.trim();
    if (trimmed.length === 0) {
      return { success: false, duplicate: false };
    }
    const existingForPerson = this.photosForPerson(personId);
    if (existingForPerson.some((p): boolean => p.uri === trimmed)) {
      return { success: false, duplicate: true };
    }
    const prId = this.nextPhotoId++;
    this.photoRefs.push({ id: prId, uri: trimmed });
    this.ownerLinks.push({
      id: this.nextLinkId++,
      ownerKind: 'person',
      ownerId: personId,
      photoRefId: prId
    });
    return { success: true, duplicate: false };
  }

  photosForStory(storyId: number): PhotoRefModel[] {
    const refIds = new Set<number>();
    for (const l of this.ownerLinks) {
      if (l.ownerKind === 'story' && l.ownerId === storyId) {
        refIds.add(l.photoRefId);
      }
    }
    const out: PhotoRefModel[] = [];
    for (const pr of this.photoRefs) {
      if (refIds.has(pr.id)) {
        out.push({ id: pr.id, uri: pr.uri });
      }
    }
    return out;
  }

  addPhotoForStory(storyId: number, uri: string): PhotoAddResult {
    if (!this.stories.some((s): boolean => s.id === storyId)) {
      return { success: false, duplicate: false };
    }
    const trimmed = uri.trim();
    if (trimmed.length === 0) {
      return { success: false, duplicate: false };
    }
    const existingForStory = this.photosForStory(storyId);
    if (existingForStory.some((p): boolean => p.uri === trimmed)) {
      return { success: false, duplicate: true };
    }
    const prId = this.nextPhotoId++;
    this.photoRefs.push({ id: prId, uri: trimmed });
    this.ownerLinks.push({
      id: this.nextLinkId++,
      ownerKind: 'story',
      ownerId: storyId,
      photoRefId: prId
    });
    return { success: true, duplicate: false };
  }

  deletePerson(id: number): boolean {
    const idx = this.persons.findIndex((p): boolean => p.id === id);
    if (idx < 0) {
      return false;
    }
    // Remove person-story links
    this.personStories = this.personStories.filter((ps): boolean => ps.personId !== id);
    // Remove person-side photo owner links
    const keepLinks: PhotoOwnerTuple[] = [];
    for (const l of this.ownerLinks) {
      if (!(l.ownerKind === 'person' && l.ownerId === id)) {
        keepLinks.push(l);
      }
    }
    this.ownerLinks = keepLinks;
    // Remove person
    this.persons.splice(idx, 1);
    return true;
  }

  deleteStory(id: number): boolean {
    const idx = this.stories.findIndex((s): boolean => s.id === id);
    if (idx < 0) {
      return false;
    }
    // Remove person-story links
    this.personStories = this.personStories.filter((ps): boolean => ps.storyId !== id);
    // Remove story-side photo owner links
    const keepLinks: PhotoOwnerTuple[] = [];
    for (const l of this.ownerLinks) {
      if (!(l.ownerKind === 'story' && l.ownerId === id)) {
        keepLinks.push(l);
      }
    }
    this.ownerLinks = keepLinks;
    // Remove story
    this.stories.splice(idx, 1);
    return true;
  }

  removePhotoForPerson(personId: number, photoRefId: number): boolean {
    return this.removePhotoForOwner('person', personId, photoRefId);
  }

  removePhotoForStory(storyId: number, photoRefId: number): boolean {
    return this.removePhotoForOwner('story', storyId, photoRefId);
  }

  private removePhotoForOwner(ownerKind: string, ownerId: number, photoRefId: number): boolean {
    const idx = this.ownerLinks.findIndex(
      (l): boolean => l.ownerKind === ownerKind && l.ownerId === ownerId && l.photoRefId === photoRefId
    );
    if (idx < 0) {
      return false;
    }
    this.ownerLinks.splice(idx, 1);
    return true;
  }

  gcOrphanPhotoRefs(): number {
    const linkedRefIds = new Set<number>();
    for (const l of this.ownerLinks) {
      linkedRefIds.add(l.photoRefId);
    }
    const before = this.photoRefs.length;
    this.photoRefs = this.photoRefs.filter((pr): boolean => linkedRefIds.has(pr.id));
    const deleted = before - this.photoRefs.length;
    console.info('T-27-GC', `memory orphan GC: before=${before}, deleted=${deleted}`);
    return deleted;
  }
}

let singleton: LocalMemoryStore | undefined;

export function singletonMemoryStore(): LocalMemoryStore {
  if (singleton === undefined) {
    singleton = new LocalMemoryStore();
  }
  return singleton;
}