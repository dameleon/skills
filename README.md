# skills

[agentskills.io](https://agentskills.io/specification) のオープン仕様に準拠した、[@dameleon](https://github.com/dameleon) の agent skills 集。Claude Code / Codex / Gemini CLI / Cursor など、仕様互換のエージェントから利用できる。

## Skills

| スキル | 概要 |
|---|---|
| [`agent-flow`](agent-flow/) | ローカルで完結する軽量マルチエージェント実装フロー（設計 → 実装 → テスト → PR → レビュー → 修正）。 |
| [`closing`](closing/) | 作業の締め。状態を棚卸しし、引継ぎを記録し、安全が実出力で示せる片付けだけを承認なしで行う。 |
| [`codex-review`](codex-review/) | codex CLI を使ったコード / プランのレビューと、指摘に基づく修正。 |
| [`cursor-delegate`](cursor-delegate/) | 小さく明確なタスクを Cursor agent CLI へ直接委譲し(Claude の subagent を挟まない)、受入チェックの exit code で判定する。 |
| [`feature-inbox`](feature-inbox/) | epic / feature 単位の inbox issue。未決・課題・報告・引継ぎを人間とエージェントが共有し、サマリとトリアージ支援を行う。 |
| [`herdr`](herdr/) | Herdr v2 の中で、`hc --skill` / `herdr-app --skill` の最新マニュアルを読ませる入口。v1 の `herdr` コマンドは使わせない。 |
| [`incremental-commit`](incremental-commit/) | 変更を論理単位・物理単位に分割してコミットする。 |
| [`test-design`](test-design/) | 結合 / 外部結合テストのケースを設計し、独立レビューで検証する。 |

## Install

各スキルは独立したディレクトリなので、以下のいずれかで導入できる。`<skill-name>` は導入したいスキルのパスに置き換える。

グローバル（ユーザー全体）に導入:

```sh
apm install -g dameleon/skills/<skill-name>
```

プロジェクトの `apm.yml` で宣言:

```yaml
dependencies:
  apm:
    - dameleon/skills/<skill-name>
```

バージョンを固定（タグを付けてから）:

```sh
apm install -g dameleon/skills/<skill-name>#v0.1.0
```

APM を使わない場合:

```sh
npx skills add dameleon/skills --skill <skill-name>
npx degit dameleon/skills/<skill-name>
```

これらは [Agent Skills](https://agentskills.io) のオープン形式に従うため、APM なしでも仕様互換のエージェント（Claude Code, Codex, opencode, Gemini CLI, Cursor …）でそのまま使える。

## Agents

[`agents/`](agents/) に、スキルから参照される subagent 定義を置いている（Claude Code / Cursor 向け）。自動インストールされない手動導入用のサンプルで、導入手順は [`agents/README.md`](agents/README.md) を参照。

## License

[MIT](LICENSE)
