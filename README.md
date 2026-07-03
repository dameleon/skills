# skills

[agentskills.io](https://agentskills.io/specification) のオープン仕様に準拠した、[@dameleon](https://github.com/dameleon) の agent skills 集。Claude Code / Codex / Gemini CLI / Cursor など、仕様互換のエージェントから利用できる。

スキルは順次追加し、追加され次第この README に一覧を載せる。

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
