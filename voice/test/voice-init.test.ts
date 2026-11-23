import assert from "node:assert/strict";
import { spawnSync, type SpawnSyncReturns } from "node:child_process";
import { existsSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, test } from "node:test";

const SCRIPT = join(import.meta.dirname, "..", "scripts", "voice-init.ts");

let folder: string | undefined;

afterEach(() => {
    if (folder !== undefined) {
        rmSync(folder, { recursive: true, force: true });
        folder = undefined;
    }
});

// A test's output is a pipe, never a terminal, which is exactly the case
// the script must refuse: a token printed here would land in a log.
test("voice-init will not run without a terminal, and makes nothing", () => {
    folder = mkdtempSync(join(tmpdir(), "voice-init-"));

    const cases: string[][] = [[], ["--replace"], ["--days", "30"]];

    for (const args of cases) {
        const run: SpawnSyncReturns<string> = spawnSync(process.execPath, [SCRIPT, ...args], {
            env: { PATH: process.env.PATH, HOME: folder, XDG_STATE_HOME: join(folder, "state") },
            encoding: "utf8",
        });

        assert.equal(run.status, 2);
        assert.equal(run.stdout, "");
        assert.match(run.stderr, /only runs in a terminal/);
        assert.equal(existsSync(join(folder, "state")), false);
    }
});
