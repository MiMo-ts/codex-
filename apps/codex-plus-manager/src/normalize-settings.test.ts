import assert from "node:assert";
import { describe, it } from "node:test";
import type { RelayProfile } from "./App.tsx";
import { normalizeSettings } from "./App.tsx";

// 类型检查：确保 RelayProfile 字段完整（与 model-windows.test.ts 保持一致）
const _profileTypeCheck: RelayProfile = {
  id: "test",
  name: "",
  model: "",
  baseUrl: "",
  upstreamBaseUrl: "",
  apiKey: "",
  protocol: "responses",
  relayMode: "official",
  officialMixApiKey: false,
  testModel: "",
  configContents: "",
  authContents: "",
  useCommonConfig: true,
  contextSelection: { mcpServers: [], skills: [], plugins: [] },
  contextSelectionInitialized: true,
  contextWindow: "",
  autoCompactLimit: "",
  modelList: "",
  modelWindows: "",
  userAgent: "",
};

void _profileTypeCheck;

type MinimalSettings = Parameters<typeof normalizeSettings>[0];

function minimalSettings(
  relayProfiles: RelayProfile[],
  activeRelayId = "default",
): MinimalSettings {
  return {
    relayProfiles,
    activeRelayId,
    aggregateRelayProfiles: [],
    activeAggregateRelayId: "",
    relayCommonConfigContents: "",
    relayContextConfigContents: "",
    relayProfilesEnabled: true,
  } as unknown as MinimalSettings;
}

function defaultRelayProfile(overrides: Partial<RelayProfile> = {}): RelayProfile {
  return {
    id: "default",
    name: "默认中转",
    model: "",
    baseUrl: "",
    upstreamBaseUrl: "",
    apiKey: "",
    protocol: "responses",
    relayMode: "official",
    officialMixApiKey: false,
    testModel: "",
    configContents: "",
    authContents: "",
    useCommonConfig: true,
    contextSelection: { mcpServers: [], skills: [], plugins: [] },
    contextSelectionInitialized: true,
    contextWindow: "",
    autoCompactLimit: "",
    modelList: "",
    modelWindows: "",
    userAgent: "",
    ...overrides,
  };
}

describe("normalizeSettings — 快泛API seed", () => {
  it("仅有「默认中转」时自动补 kuaifan（修复老用户）", () => {
    const result = normalizeSettings(minimalSettings([defaultRelayProfile()]));
    const ids = result.relayProfiles.map((p) => p.id);
    const names = result.relayProfiles.map((p) => p.name);

    assert.deepStrictEqual(ids, ["default", "kuaifan"]);
    assert.deepStrictEqual(names, ["默认中转", "快泛API"]);

    const kuaifan = result.relayProfiles.find((p) => p.id === "kuaifan");
    assert.ok(kuaifan, "应当补出 kuaifan profile");
    assert.strictEqual(kuaifan?.baseUrl, "https://kuaifanio.cn/v1");
    assert.strictEqual(kuaifan?.upstreamBaseUrl, "https://kuaifanio.cn/v1");
    assert.strictEqual(kuaifan?.protocol, "chatCompletions");
    assert.strictEqual(kuaifan?.relayMode, "pureApi");
    assert.strictEqual(kuaifan?.apiKey, "");
  });

  it("relayProfiles 为空时也补 kuaifan（新装兜底）", () => {
    const result = normalizeSettings(minimalSettings([]));
    assert.strictEqual(result.relayProfiles.length, 2);
    assert.ok(result.relayProfiles.some((p) => p.id === "kuaifan"));
    assert.ok(result.relayProfiles.some((p) => p.id === "default"));
  });

  it("用户已经存在 kuaifan (id 匹配) → 不重复添加", () => {
    const result = normalizeSettings(
      minimalSettings([
        defaultRelayProfile(),
        defaultRelayProfile({ id: "kuaifan", name: "我的快泛" }),
      ]),
    );

    const kuaifanCount = result.relayProfiles.filter((p) => p.id === "kuaifan").length;
    assert.strictEqual(kuaifanCount, 1, "不应重复添加 id=kuaifan");
    assert.strictEqual(result.relayProfiles.length, 2);
    // 用户自定义的 name 应被保留
    assert.strictEqual(
      result.relayProfiles.find((p) => p.id === "kuaifan")?.name,
      "我的快泛",
    );
  });

  it("用户改过 id 但保留 name='快泛API' → 也不重复添加", () => {
    const result = normalizeSettings(
      minimalSettings([
        defaultRelayProfile(),
        defaultRelayProfile({ id: "my-relay", name: "快泛API" }),
      ]),
    );

    const 快泛APICount = result.relayProfiles.filter((p) => p.name === "快泛API").length;
    assert.strictEqual(快泛APICount, 1, "name 匹配即视为已存在，不重复添加");
    assert.strictEqual(result.relayProfiles.length, 2);
  });

  it("normalizeSettings 是幂等的：连续跑两次结果一致", () => {
    const once = normalizeSettings(minimalSettings([defaultRelayProfile()]));
    const twice = normalizeSettings(once);

    assert.strictEqual(twice.relayProfiles.length, 2);
    assert.deepStrictEqual(
      twice.relayProfiles.map((p) => p.id),
      once.relayProfiles.map((p) => p.id),
    );
  });

  it("activeRelayId 在 seed 后仍指向用户原本激活的供应商", () => {
    const result = normalizeSettings(minimalSettings([defaultRelayProfile()], "default"));
    assert.strictEqual(result.activeRelayId, "default");
  });
});