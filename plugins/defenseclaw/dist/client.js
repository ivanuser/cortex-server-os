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
import { request as httpRequest } from "node:http";
import { URL } from "node:url";
import { loadSidecarConfig } from "./sidecar-config.js";
const REQUEST_TIMEOUT_MS = 30_000;
const MAX_RESPONSE_BYTES = 10 * 1024 * 1024;
export class DaemonClient {
    baseUrl;
    token;
    timeoutMs;
    requestImpl;
    constructor(opts) {
        const cfg = loadSidecarConfig();
        this.baseUrl = opts?.baseUrl ?? cfg.baseUrl;
        this.token = opts?.token ?? cfg.token;
        this.timeoutMs = opts?.timeoutMs ?? REQUEST_TIMEOUT_MS;
        this.requestImpl = opts?.requestImpl ?? httpRequest;
    }
    async status() {
        return this.get("/status");
    }
    async submitScanResult(result) {
        return this.post("/scan/result", result);
    }
    async block(targetType, targetName, reason) {
        return this.post("/enforce/block", {
            target_type: targetType,
            target_name: targetName,
            reason,
        });
    }
    async allow(targetType, targetName, reason) {
        return this.post("/enforce/allow", {
            target_type: targetType,
            target_name: targetName,
            reason,
        });
    }
    async unblock(targetType, targetName) {
        return this.delete("/enforce/block", {
            target_type: targetType,
            target_name: targetName,
        });
    }
    async listAlerts(limit = 50) {
        return this.get(`/alerts?limit=${limit}`);
    }
    async listSkills() {
        return this.get("/skills");
    }
    async listMCPs() {
        return this.get("/mcps");
    }
    async listBlocked() {
        return this.get("/enforce/blocked");
    }
    async listAllowed() {
        return this.get("/enforce/allowed");
    }
    async logEvent(event) {
        return this.post("/audit/event", event);
    }
    async evaluatePolicy(domain, input) {
        return this.post("/policy/evaluate", {
            domain,
            input,
        });
    }
    get(path) {
        return this.doRequest("GET", path);
    }
    post(path, body) {
        return this.doRequest("POST", path, body);
    }
    delete(path, body) {
        return this.doRequest("DELETE", path, body);
    }
    doRequest(method, path, body) {
        return new Promise((resolve) => {
            const url = new URL(path, this.baseUrl);
            const payload = body !== undefined ? JSON.stringify(body) : undefined;
            const headers = {
                "Content-Type": "application/json",
                Accept: "application/json",
                "X-DefenseClaw-Client": "openclaw-plugin",
            };
            if (this.token) {
                headers["Authorization"] = `Bearer ${this.token}`;
            }
            if (payload !== undefined) {
                headers["Content-Length"] = Buffer.byteLength(payload);
            }
            const req = this.requestImpl({
                hostname: url.hostname,
                port: url.port,
                path: url.pathname + url.search,
                method,
                timeout: this.timeoutMs,
                headers,
            }, (res) => {
                const chunks = [];
                let totalBytes = 0;
                res.on("data", (chunk) => {
                    totalBytes += chunk.length;
                    if (totalBytes <= MAX_RESPONSE_BYTES) {
                        chunks.push(chunk);
                    }
                });
                res.on("end", () => {
                    const raw = Buffer.concat(chunks).toString("utf-8");
                    const status = res.statusCode ?? 0;
                    if (status >= 200 && status < 300) {
                        try {
                            const data = raw.length > 0 ? JSON.parse(raw) : undefined;
                            resolve({ ok: true, data, status });
                        }
                        catch {
                            resolve({ ok: true, data: undefined, status });
                        }
                    }
                    else {
                        resolve({ ok: false, error: raw || `HTTP ${status}`, status });
                    }
                });
                res.on("error", (err) => {
                    resolve({ ok: false, error: err.message, status: 0 });
                });
            });
            req.on("error", (err) => {
                resolve({ ok: false, error: err.message, status: 0 });
            });
            req.on("timeout", () => {
                req.destroy();
                resolve({ ok: false, error: "request timed out", status: 0 });
            });
            if (payload !== undefined) {
                req.write(payload);
            }
            req.end();
        });
    }
}
