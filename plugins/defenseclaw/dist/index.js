/**
 * Copyright 2026 Cisco Systems, Inc. and its affiliates
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 */
import { PolicyEnforcer, runSkillScan, runCodeScan } from "./policy/enforcer.js";
import { scanPlugin } from "./scanners/plugin_scanner/index.js";
import { scanMCPServer } from "./scanners/mcp-scanner.js";
import { compareSeverity, maxSeverity } from "./types.js";
import { loadSidecarConfig } from "./sidecar-config.js";
function formatFindings(findings, limit = 15) {
    const lines = [];
    const sorted = [...findings].sort((a, b) => compareSeverity(b.severity, a.severity));
    for (const f of sorted.slice(0, limit)) {
        const loc = f.location ? ` (${f.location})` : "";
        lines.push(`- **[${f.severity}]** ${f.title}${loc}`);
    }
    if (findings.length > limit) {
        lines.push(`- ... and ${findings.length - limit} more`);
    }
    return lines;
}
export default function (api) {
    const enforcer = new PolicyEnforcer();
    // ─── Runtime: tool call interception ───
    const sidecarConfig = loadSidecarConfig();
    const SIDECAR_API = sidecarConfig.baseUrl;
    const SIDECAR_TOKEN = sidecarConfig.token;
    const INSPECT_TIMEOUT_MS = 2_000;
    async function inspectTool(payload) {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), INSPECT_TIMEOUT_MS);
        try {
            const headers = {
                "Content-Type": "application/json",
                "X-DefenseClaw-Client": "openclaw-plugin",
            };
            if (SIDECAR_TOKEN) {
                headers["Authorization"] = `Bearer ${SIDECAR_TOKEN}`;
            }
            const res = await fetch(`${SIDECAR_API}/api/v1/inspect/tool`, {
                method: "POST",
                headers,
                body: JSON.stringify(payload),
                signal: controller.signal,
            });
            return (await res.json());
        }
        catch {
            return { action: "allow", severity: "NONE", reason: "sidecar unreachable", mode: "observe" };
        }
        finally {
            clearTimeout(timer);
        }
    }
    api.on("before_tool_call", async (event) => {
        if (event.toolName === "message") {
            const content = event.params?.content || event.params?.body || "";
            if (!content)
                return;
            const verdict = await inspectTool({
                tool: "message",
                args: event.params,
                content,
                direction: "outbound",
            });
            console.log(`[defenseclaw] message-tool verdict:${verdict.action} severity:${verdict.severity}`);
            if (verdict.action === "block" && verdict.mode === "action") {
                return { block: true, blockReason: `DefenseClaw: outbound blocked — ${verdict.reason}` };
            }
            return;
        }
        const verdict = await inspectTool({
            tool: event.toolName,
            args: event.params,
        });
        console.log(`[defenseclaw] tool:${event.toolName} verdict:${verdict.action} severity:${verdict.severity}`);
        if (verdict.action === "block" && verdict.mode === "action") {
            return { block: true, blockReason: `DefenseClaw: ${verdict.reason}` };
        }
    });
    // ─── Slash command: /scan ───
    api.registerCommand({
        name: "scan",
        description: "Scan a skill, plugin, MCP config, or source code with DefenseClaw",
        args: [
            { name: "target", description: "Path to skill/plugin directory, MCP config, or source code", required: true },
            { name: "type", description: "Scan type: skill (default), plugin, mcp, code", required: false },
        ],
        handler: async ({ args }) => {
            const target = args.target;
            if (!target) {
                return { text: "Usage: /scan <path> [skill|plugin|mcp|code]" };
            }
            const scanType = (args.type ?? "skill");
            if (scanType === "plugin") {
                return handlePluginScan(target);
            }
            if (scanType === "mcp") {
                return handleMCPScan(target);
            }
            if (scanType === "code") {
                return handleCodeScan(target, SIDECAR_API);
            }
            return handleSkillScan(target);
        },
    });
    // ─── Slash command: /block ───
    api.registerCommand({
        name: "block",
        description: "Block a skill, MCP server, or plugin",
        args: [
            { name: "type", description: "Target type: skill, mcp, plugin", required: true },
            { name: "name", description: "Name of the target to block", required: true },
            { name: "reason", description: "Reason for blocking", required: false },
        ],
        handler: async ({ args }) => {
            const targetType = args.type;
            const name = args.name;
            if (!targetType || !name) {
                return { text: "Usage: /block <skill|mcp|plugin> <name> [reason]" };
            }
            const reason = args.reason || "Blocked via /block command";
            await enforcer.block(targetType, name, reason);
            return {
                text: `Blocked ${targetType} **${name}**: ${reason}`,
            };
        },
    });
    // ─── Slash command: /allow ───
    api.registerCommand({
        name: "allow",
        description: "Allow-list a skill, MCP server, or plugin",
        args: [
            { name: "type", description: "Target type: skill, mcp, plugin", required: true },
            { name: "name", description: "Name of the target to allow", required: true },
            { name: "reason", description: "Reason for allowing", required: false },
        ],
        handler: async ({ args }) => {
            const targetType = args.type;
            const name = args.name;
            if (!targetType || !name) {
                return { text: "Usage: /allow <skill|mcp|plugin> <name> [reason]" };
            }
            const reason = args.reason || "Allowed via /allow command";
            await enforcer.allow(targetType, name, reason);
            return {
                text: `Allow-listed ${targetType} **${name}**: ${reason}`,
            };
        },
    });
}
// ─── Scan handlers ───
async function handlePluginScan(target) {
    try {
        const result = await scanPlugin(target);
        return { text: formatScanOutput("Plugin", target, result) };
    }
    catch (err) {
        return {
            text: `Plugin scan failed: ${err instanceof Error ? err.message : String(err)}`,
        };
    }
}
async function handleMCPScan(target) {
    try {
        const result = await scanMCPServer(target);
        return { text: formatScanOutput("MCP", target, result) };
    }
    catch (err) {
        return {
            text: `MCP scan failed: ${err instanceof Error ? err.message : String(err)}`,
        };
    }
}
async function handleCodeScan(target, sidecarApi) {
    try {
        const result = await runCodeScan(target, sidecarApi);
        return { text: formatScanOutput("Code", target, result) };
    }
    catch (err) {
        return {
            text: `Code scan failed: ${err instanceof Error ? err.message : String(err)}`,
        };
    }
}
async function handleSkillScan(target) {
    try {
        const result = await runSkillScan(target);
        return { text: formatScanOutput("Skill", target, result) };
    }
    catch (err) {
        return {
            text: `Skill scan failed: ${err instanceof Error ? err.message : String(err)}`,
        };
    }
}
function formatScanOutput(scanType, target, result) {
    const lines = [`**DefenseClaw ${scanType} Scan: ${target}**\n`];
    if (result.findings.length === 0) {
        lines.push("Verdict: **CLEAN** — no findings");
        return lines.join("\n");
    }
    const max = maxSeverity(result.findings.map((f) => f.severity));
    lines.push(`Verdict: **${max}** (${result.findings.length} finding${result.findings.length === 1 ? "" : "s"})\n`);
    lines.push(...formatFindings(result.findings));
    return lines.join("\n");
}
