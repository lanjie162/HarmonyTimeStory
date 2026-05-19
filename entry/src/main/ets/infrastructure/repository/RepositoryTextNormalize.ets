/**
 * 人物名 / 故事标题 / URI 等：trim 后若为空则返回 null，否则返回 trim 后的字符串。
 * 供 RepositoryImpl 与 Tier1 契约用例共用，避免 trim 规则漂移。
 */
export function requireTrimmedNonEmpty(input: string): string | null {
  const t = input.trim();
  if (t.length === 0) {
    return null;
  }
  return t;
}
