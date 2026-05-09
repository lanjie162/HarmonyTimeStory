import type { PersonModel, PhotoRefModel, PhotoAddResult, StoryModel } from '../../domain/model/Models';

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

/**
 * MVP 单机内存仓储：进程内闭环人物/故事/关联/PhotoOwnerLink，关机即清空。
 * 满足 T-4 可追溯与「不落盘原文件仅引用 URI」的假数据路径。
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
    return this.persons.map((p): PersonModel => ({ id: p.id, displayName: p.displayName }));
  }

  createPerson(displayName: string): number {
    const t = displayName.trim();
    if (t.length === 0) {
      return -1;
    }
    const id = this.nextPersonId++;
    this.persons.push({ id, displayName: t });
    return id;
  }

  getPerson(id: number): PersonModel | null {
    const p = this.persons.find((x): boolean => x.id === id);
    return p ?? null;
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
    return this.stories.map((s): StoryModel => ({ id: s.id, title: s.title }));
  }

  createStory(title: string): number {
    const t = title.trim();
    if (t.length === 0) {
      return -1;
    }
    const id = this.nextStoryId++;
    this.stories.push({ id, title: t });
    return id;
  }

  getStory(id: number): StoryModel | null {
    const s = this.stories.find((x): boolean => x.id === id);
    return s ?? null;
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
        out.push({ id: p.id, displayName: p.displayName });
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
        result.push({ id: s.id, title: s.title });
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
}

let singleton: LocalMemoryStore | undefined;

export function singletonMemoryStore(): LocalMemoryStore {
  if (singleton === undefined) {
    singleton = new LocalMemoryStore();
  }
  return singleton;
}
