import { Callout, Card, CardBody, Divider, Grid, H1, H2, Pill, Row, Stack, Stat, Table, Text, useHostTheme } from 'cursor/canvas';

const VERSIONS = [
  { name: 'V1 \u5E95\u5EA7\u7248', progress: 100, status: 'completed' as const, note: '' },
  { name: 'V2 \u529F\u80FD\u4E3B\u94FE\u7248', progress: 85, status: 'partial' as const, note: '\u7F3A\u5220\u9664\u64CD\u4F5C' },
  { name: 'V2.1 \u6301\u4E45\u5316\u95F8\u95E8\u7248', progress: 95, status: 'completed' as const, note: '\u6709\u6761\u4EF6\u901A\u8FC7' },
  { name: 'V3 \u98CE\u9669\u6536\u53E3\u7248', progress: 0, status: 'pending' as const, note: '\u5F85\u542F\u52A8' },
  { name: 'V4 \u9A8C\u6536\u53D1\u7248\u7248', progress: 0, status: 'pending' as const, note: '\u5F85\u542F\u52A8' },
];

const STATUS_PILL = {
  done: <Pill tone="success" active size="sm">Done</Pill>,
  missing: <Pill tone="danger" active size="sm">Missing</Pill>,
  partial: <Pill tone="warning" active size="sm">Partial</Pill>,
  pending: <Pill tone="info" size="sm">Pending</Pill>,
} as const;

function StatusPill({ status }: { status: keyof typeof STATUS_PILL }) {
  return STATUS_PILL[status];
}

function ProgressBar({ value, color }: { value: number; color: string }) {
  const theme = useHostTheme();
  return (
    <div
      style={{
        width: '100%',
        height: 8,
        borderRadius: 4,
        background: theme.fill.tertiary,
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          width: `${value}%`,
          height: '100%',
          borderRadius: 4,
          background: color,
          transition: 'width 0.3s ease',
        }}
      />
    </div>
  );
}

export default function MVPDemandEvaluation() {
  const theme = useHostTheme();

  const versionBarColor = (progress: number) => {
    if (progress >= 100) return theme.accent.primary;
    if (progress >= 80) return '#4caf50';
    if (progress > 0) return '#ff9800';
    return theme.fill.tertiary;
  };

  const mvpScopeRows = [
    ['\u4EBA\u7269\uFF1A\u5217\u8868\u3001\u65B0\u5EFA\u3001\u7F16\u8F91', <StatusPill status="done" />],
    ['\u4EBA\u7269\uFF1A\u5220\u9664', <StatusPill status="missing" />],
    ['\u6545\u4E8B\uFF1A\u5217\u8868\u3001\u65B0\u5EFA\u3001\u7F16\u8F91', <StatusPill status="done" />],
    ['\u6545\u4E8B\uFF1A\u5220\u9664', <StatusPill status="missing" />],
    ['\u4EBA\u7269\u2194\u6545\u4E8B\u591A\u5BF9\u591A\u5173\u8054', <StatusPill status="done" />],
    ['PhotoPicker \u9009\u56FE', <StatusPill status="done" />],
    ['StoryPhoto/PersonPhoto \u72EC\u7ACB', <StatusPill status="done" />],
    ['\u540C\u4E00 PhotoRef \u591A\u6302', <StatusPill status="done" />],
    ['\u5BFC\u5165\u4E09\u5F62\u6001', <StatusPill status="partial" />],
    ['\u9690\u79C1\u8BF4\u660E\u9875', <StatusPill status="missing" />],
    ['\u5931\u6548\u6001\u5904\u7406', <StatusPill status="missing" />],
    ['\u5D29\u6E83\u4E0A\u62A5', <StatusPill status="missing" />],
    ['\u6DF1\u8272/\u6D45\u8272\u4E3B\u9898', <StatusPill status="partial" />],
  ];

  const personFieldRows = [
    ['\u663E\u793A\u540D(\u5FC5\u586B)', <StatusPill status="done" />],
    ['\u7C7B\u578B(\u679A\u4E3E)', <StatusPill status="missing" />],
    ['\u5934\u50CF(\u53EF\u9009)', <StatusPill status="missing" />],
    ['\u751F\u65E5(\u53EF\u9009)', <StatusPill status="missing" />],
    ['\u6027\u522B(\u53EF\u9009)', <StatusPill status="missing" />],
    ['\u5907\u6CE8(\u53EF\u9009)', <StatusPill status="missing" />],
  ];

  const storyFieldRows = [
    ['\u6807\u9898(\u5FC5\u586B)', <StatusPill status="done" />],
    ['\u63CF\u8FF0(\u53EF\u9009)', <StatusPill status="missing" />],
    ['\u65F6\u95F4\u8303\u56F4', <StatusPill status="missing" />],
    ['\u5C01\u9762', <StatusPill status="missing" />],
    ['\u5730\u70B9(\u53EF\u9009)', <StatusPill status="missing" />],
    ['\u81EA\u5B9A\u4E49\u6807\u7B7E(\u53EF\u9009)', <StatusPill status="missing" />],
  ];

  const gapRows = [
    ['PE-01', '\u5217\u8868\u3001\u65B0\u5EFA\u3001\u7F16\u8F91\u3001\u5220\u9664', <Pill tone="warning" active size="sm">Missing delete</Pill>],
    ['PE-02', '\u00A76.1 \u5168\u5B57\u6BB5', <Pill tone="danger" active size="sm">Only displayName</Pill>],
    ['PE-05', '\u79FB\u9664\u7167\u7247', <StatusPill status="missing" />],
    ['ST-01', '\u5217\u8868\u3001\u65B0\u5EFA\u3001\u7F16\u8F91\u3001\u5220\u9664', <Pill tone="warning" active size="sm">Missing delete</Pill>],
    ['ST-02', '\u00A76.1 \u5168\u5B57\u6BB5', <Pill tone="danger" active size="sm">Only title</Pill>],
    ['ST-05', '\u79FB\u9664\u7167\u7247', <StatusPill status="missing" />],
    ['ST-07', '1000\u5F20\u4E0A\u9650', <StatusPill status="done" />],
    ['IM-03', '\u5F62\u6001\u4E09', <Pill tone="warning" active size="sm">Skeleton</Pill>],
    ['IM-04', '\u65F6\u95F4\u6761\u4EF6', <Pill tone="warning" active size="sm">Placeholder</Pill>],
    ['IM-05', '\u5730\u70B9\u6761\u4EF6', <Pill tone="warning" active size="sm">Placeholder</Pill>],
    ['IM-06', '\u4EBA\u8138\u65CF+\u53C2\u8003\u56FE', <StatusPill status="missing" />],
    ['IM-07', 'AND\u6761\u4EF6', <Pill tone="warning" active size="sm">Placeholder</Pill>],
    ['IM-08', '\u5019\u9009\u7F51\u683C', <StatusPill status="done" />],
    ['IM-09', '\u957F\u4EFB\u52A1\u8FDB\u5EA6/\u53D6\u6D88', <StatusPill status="done" />],
    ['IM-10', '\u4EBA\u8138\u5F00\u5173', <StatusPill status="missing" />],
    ['IX-02', '\u4F4E\u7AEF\u673A\u964D\u7EA7', <StatusPill status="missing" />],
    ['ER-01', '\u5931\u6548\u6001\u5904\u7406', <StatusPill status="missing" />],
    ['PR-01', '\u9690\u79C1\u8BF4\u660E\u9875', <StatusPill status="missing" />],
    ['PR-02', '\u4EBA\u8138\u7F13\u5B58\u6E05\u7406', <StatusPill status="missing" />],
  ];

  const p0MissingItems = [
    'Person/Story \u5220\u9664\u64CD\u4F5C',
    'Person \u7F3A\u5931 5 \u4E2A\u5B57\u6BB5',
    'Story \u7F3A\u5931 5 \u4E2A\u5B57\u6BB5',
    '\u79FB\u9664\u7167\u7247',
    'PhotoRef \u5B64\u513F GC',
    '\u5931\u6548\u6001\u5904\u7406',
    '\u9690\u79C1\u8BF4\u660E\u9875',
    '\u5D29\u6E83\u4E0A\u62A5',
    '\u4EBA\u8138\u529F\u80FD',
    '\u4F4E\u7AEF\u673A\u964D\u7EA7',
    '\u5F62\u6001\u4E09\u975E\u9AA8\u67B6',
  ];

  const p0PlaceholderItems = [
    '\u5BFC\u5165\u6761\u4EF6\u9875\uFF1A\u65F6\u95F4/\u5730\u70B9/\u4EBA\u8138\u5360\u4F4D\u65E0\u903B\u8F91',
    '\u5F62\u6001\u4E09 SuggestPage \u786C\u7F16\u7801',
  ];

  return (
    <Stack gap={20}>
      {/* Header */}
      <Stack gap={4}>
        <H1>MVP \u9700\u6C42\u5B8C\u6210\u5EA6\u8BC4\u4F30\u62A5\u544A</H1>
        <Text tone="secondary" size="small">
          \u5BAA\u6CD5\u6587\u6863: \u65F6\u5149\u6545\u4E8B-MVP\u9700\u6C42\u8BF4\u660E-v4.md V4.4
        </Text>
        <Text tone="secondary" size="small">
          \u8BC4\u4F30\u65E5\u671F: 2026-05-20
        </Text>
      </Stack>

      <Divider />

      {/* Summary Stats */}
      <H2>\u6982\u89C8</H2>
      <Grid columns={4} gap={16}>
        <Stat value="2" label="\u5B8C\u6210\u7248\u672C" tone="success" />
        <Stat value="1" label="\u90E8\u5206\u5B8C\u6210" tone="warning" />
        <Stat value="2" label="\u5F85\u542F\u52A8" tone="info" />
        <Stat value="11" label="P0 \u7F3A\u5931\u9879" tone="danger" />
      </Grid>

      <Divider />

      {/* Version Progress */}
      <H2>\u7248\u672C\u5B8C\u6210\u72B6\u6001</H2>

      <Card>
        <CardBody>
          <Stack gap={12}>
            {VERSIONS.map((v) => (
              <Stack key={v.name} gap={4}>
                <Row gap={8} align="center" justify="space-between">
                  <Row gap={8} align="center">
                    <Text weight="semibold" size="small">{v.name}</Text>
                    {(v.status === 'completed') && <Pill tone="success" active size="sm">Done</Pill>}
                    {(v.status === 'partial') && <Pill tone="warning" active size="sm">Partial</Pill>}
                    {(v.status === 'pending') && <Pill tone="info" size="sm">Pending</Pill>}
                  </Row>
                  <Row gap={8} align="center">
                    <Text weight="bold" size="small" tone="secondary">{v.progress}%</Text>
                    {v.note && <Text size="small" tone="tertiary">{v.note}</Text>}
                  </Row>
                </Row>
                <ProgressBar value={v.progress} color={versionBarColor(v.progress)} />
              </Stack>
            ))}
          </Stack>
        </CardBody>
      </Card>

      <Divider />

      {/* Section 1: MVP Scope */}
      <Stack gap={4}>
        <H2>\u4E00\u3001\u00A75.1 MVP \u5305\u542B\u8303\u56F4</H2>
        <Text size="small" tone="secondary">\u5171 13 \u9879\u9700\u6C42</Text>
      </Stack>
      <Table
        headers={['\u9700\u6C42\u9879', '\u72B6\u6001']}
        rows={mvpScopeRows}
        columnAlign={['left', 'center']}
        striped
      />

      <Divider />

      {/* Section 2: Person Fields */}
      <Stack gap={4}>
        <H2>\u4E8C\u3001Person \u5B57\u6BB5</H2>
        <Text size="small" tone="secondary">6 \u4E2A\u5B57\u6BB5\uFF0C\u4EC5 1 \u4E2A\u5B9E\u73B0</Text>
      </Stack>
      <Table
        headers={['\u5B57\u6BB5', '\u72B6\u6001']}
        rows={personFieldRows}
        columnAlign={['left', 'center']}
        striped
      />

      <Divider />

      {/* Section 3: Story Fields */}
      <Stack gap={4}>
        <H2>\u4E09\u3001Story \u5B57\u6BB5</H2>
        <Text size="small" tone="secondary">6 \u4E2A\u5B57\u6BB5\uFF0C\u4EC5 1 \u4E2A\u5B9E\u73B0</Text>
      </Stack>
      <Table
        headers={['\u5B57\u6BB5', '\u72B6\u6001']}
        rows={storyFieldRows}
        columnAlign={['left', 'center']}
        striped
      />

      <Divider />

      {/* Section 4: Functional Requirements Gaps */}
      <Stack gap={4}>
        <H2>\u56DB\u3001\u529F\u80FD\u9700\u6C42\u7F3A\u53E3\u5217\u8868</H2>
        <Text size="small" tone="secondary">\u4EC5\u663E\u793A\u672A\u5B8C\u5168\u5B9E\u73B0\u7684\u9700\u6C42</Text>
      </Stack>
      <Table
        headers={['ID', '\u9700\u6C42', '\u72B6\u6001']}
        rows={gapRows}
        columnAlign={['left', 'left', 'center']}
        striped
      />

      <Divider />

      {/* Section 5: Key Gap Summary */}
      <H2>\u4E94\u3001\u5173\u952E\u7F3A\u53E3\u6C47\u603B</H2>

      <Callout tone="danger" title="P0 \u2014 Missing / Not Implemented (11 items)">
        <Stack gap={6} style={{ marginTop: 4 }}>
          {p0MissingItems.map((item, i) => (
            <Row key={i} gap={8} align="center">
              <Text
                size="small"
                weight="semibold"
                style={{
                  width: 24,
                  minWidth: 24,
                  color: theme.text.tertiary,
                }}
              >
                {i + 1}
              </Text>
              <Text size="small">{item}</Text>
            </Row>
          ))}
        </Stack>
      </Callout>

      <Callout tone="warning" title="P0 \u2014 Placeholder / Skeleton (2 items)">
        <Stack gap={6} style={{ marginTop: 4 }}>
          {p0PlaceholderItems.map((item, i) => (
            <Row key={i} gap={8} align="center">
              <Text
                size="small"
                weight="semibold"
                style={{
                  width: 24,
                  minWidth: 24,
                  color: theme.text.tertiary,
                }}
              >
                {i + 12}
              </Text>
              <Text size="small">{item}</Text>
            </Row>
          ))}
        </Stack>
      </Callout>

      <Divider />

      <Text size="small" tone="tertiary">
        Report generated from MVP demand specification v4.4 \u00B7 Evaluation date: 2026-05-20
      </Text>
    </Stack>
  );
}