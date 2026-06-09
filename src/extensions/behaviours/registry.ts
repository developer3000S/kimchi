/**
 * Bundled behaviour registry.
 *
 * Each entry pairs a markdown body (imported as text by Bun's bundler) with
 * its kind — `baseline` bodies merge into the system prompt unconditionally,
 * `triggered` bodies stay dormant until their triggers fire.
 *
 * `buildBehaviours` validates the registry at module load: every body parses,
 * every name is unique, every triggered source has at least one trigger.
 * Adding a new behaviour requires only appending another `BehaviourSource`
 * entry below.
 */

import { readFileSync } from "node:fs"
import { type BehaviourSource, buildBehaviours } from "./build.js"
import { bashInvokes, fetchesHost } from "./matchers.js"
import { any, cli, gitRemote, gitRepo, tool } from "./triggers.js"
import type { Behaviour } from "./types.js"

const load = (path: string) => readFileSync(new URL(path, import.meta.url), "utf-8")

const boundToolOutputBody = load("./bodies/bound-tool-output.md")
const ghCliBody = load("./bodies/gh-cli.md")
const gitHygieneBody = load("./bodies/git-hygiene.md")
const glabCliBody = load("./bodies/glab-cli.md")
const pythonEditBody = load("./bodies/python-edit.md")
const reReadBeforeEditBody = load("./bodies/re-read-before-edit.md")

const ghInvocation = bashInvokes("gh")
const githubFromOtherTool = fetchesHost(/(api\.)?github\.com/)
const glabInvocation = bashInvokes("glab")
const gitlabFromOtherTool = fetchesHost(/(.+\.)?gitlab\.com/)
const pythonFileEdit = any(
	tool("edit", (i) => i.path.endsWith(".py")),
	tool("write", (i) => i.path.endsWith(".py")),
)

const sources: BehaviourSource[] = [
	{ raw: boundToolOutputBody, kind: "baseline" },
	{
		raw: gitHygieneBody,
		kind: "triggered",
		triggers: { session: gitRepo() },
	},
	{
		raw: pythonEditBody,
		kind: "triggered",
		triggers: { tool: pythonFileEdit },
	},
	{ raw: reReadBeforeEditBody, kind: "baseline" },
	{
		raw: ghCliBody,
		kind: "triggered",
		triggers: {
			session: any(cli("gh"), gitRemote("github.com")),
			tool: ghInvocation,
		},
		evals: {
			observed: ghInvocation,
			violated: githubFromOtherTool,
		},
	},
	{
		raw: glabCliBody,
		kind: "triggered",
		triggers: {
			session: any(cli("glab"), gitRemote("gitlab.com")),
			tool: glabInvocation,
		},
		evals: {
			observed: glabInvocation,
			violated: gitlabFromOtherTool,
		},
	},
]

export const behaviours: readonly Behaviour[] = buildBehaviours(sources)
