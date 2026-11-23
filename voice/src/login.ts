// The login: one secret token, which claude.ai sends in the Authorization
// header of every request. The box keeps only the token's hash, in a file
// outside the repository that only Mark's user can read. The token itself
// is shown once, by scripts/voice-init.ts, and never written down here.

import { createHash, randomBytes, timingSafeEqual } from "node:crypto";
import { chmodSync, lstatSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname, isAbsolute, join } from "node:path";

// 32 random bytes are 256 bits: far too many to guess, which is why a
// plain SHA-256 hash is enough and no slow password hash is needed.
export const TOKEN_BYTES = 32;

export const DEFAULT_TOKEN_DAYS = 7;
export const MAX_TOKEN_DAYS = 90;

export const LOGIN_FOLDER_NAME = "voice-bridge";
export const LOGIN_FILE_NAME = "login.json";

// The header must be exactly this: the word Bearer, one space, and the
// 43 characters that 32 bytes make in base64url.
const HEADER_PATTERN = /^Bearer ([A-Za-z0-9_-]{43})$/;
const HASH_PATTERN = /^[0-9a-f]{64}$/;
const DAY_MS = 24 * 60 * 60 * 1000;

export type LoginRecord = {
    version: 1;
    // SHA-256 of the token, as 64 lowercase hex characters.
    tokenHash: string;
    createdAt: string;
    expiresAt: string;
};

export type TokenVerdict = { ok: true } | { ok: false; reason: "missing" | "wrong" | "expired" };

export class LoginError extends Error {}

function hashToken(token: string): Buffer {
    return createHash("sha256").update(token, "utf8").digest();
}

export function issueLogin(days: number, now: Date): { token: string; record: LoginRecord } {
    if (!Number.isInteger(days) || days < 1 || days > MAX_TOKEN_DAYS) {
        throw new LoginError(`A token lasts a whole number of days, from 1 to ${MAX_TOKEN_DAYS}.`);
    }

    const token = randomBytes(TOKEN_BYTES).toString("base64url");
    const record: LoginRecord = {
        version: 1,
        tokenHash: hashToken(token).toString("hex"),
        createdAt: now.toISOString(),
        expiresAt: new Date(now.getTime() + days * DAY_MS).toISOString(),
    };

    return { token, record };
}

export function headerValue(token: string): string {
    return `Bearer ${token}`;
}

export function isExpired(record: LoginRecord, now: Date): boolean {
    return now.getTime() >= Date.parse(record.expiresAt);
}

// Checks the Authorization header against the record. Both sides are
// hashed before they are compared, and the comparison takes the same time
// whatever was sent, so its timing says nothing about the secret. Expiry
// is looked at only once the token is known to be right, so a wrong token
// always gets the same answer.
export function checkToken(record: LoginRecord, header: string | string[] | undefined, now: Date): TokenVerdict {
    if (header === undefined) {
        return { ok: false, reason: "missing" };
    }

    const sent = typeof header === "string" ? HEADER_PATTERN.exec(header)?.[1] : undefined;
    if (sent === undefined) {
        return { ok: false, reason: "wrong" };
    }

    const stored = Buffer.from(record.tokenHash, "hex");
    const presented = hashToken(sent);
    if (stored.length !== presented.length || !timingSafeEqual(presented, stored)) {
        return { ok: false, reason: "wrong" };
    }

    if (isExpired(record, now)) {
        return { ok: false, reason: "expired" };
    }

    return { ok: true };
}

export function loginFilePath(env: { XDG_STATE_HOME?: string | undefined; HOME?: string | undefined }): string {
    const stateHome = env.XDG_STATE_HOME;
    if (stateHome !== undefined && stateHome !== "") {
        if (!isAbsolute(stateHome)) {
            throw new LoginError("XDG_STATE_HOME must be a full path.");
        }

        return join(stateHome, LOGIN_FOLDER_NAME, LOGIN_FILE_NAME);
    }

    const home = env.HOME;
    if (home === undefined || !isAbsolute(home)) {
        throw new LoginError("HOME is not set, so there is nowhere to keep the login.");
    }

    return join(home, ".local", "state", LOGIN_FOLDER_NAME, LOGIN_FILE_NAME);
}

function isLoginRecord(value: unknown): value is LoginRecord {
    if (typeof value !== "object" || value === null) {
        return false;
    }

    if (!("version" in value) || !("tokenHash" in value) || !("createdAt" in value) || !("expiresAt" in value)) {
        return false;
    }

    const { version, tokenHash, createdAt, expiresAt } = value;
    if (version !== 1 || typeof tokenHash !== "string" || !HASH_PATTERN.test(tokenHash)) {
        return false;
    }

    if (typeof createdAt !== "string" || typeof expiresAt !== "string") {
        return false;
    }

    const made = Date.parse(createdAt);
    const ends = Date.parse(expiresAt);

    return Number.isFinite(made) && Number.isFinite(ends) && ends > made;
}

// Writes the record where only Mark's user can read it. The new file is
// written beside the old one and then renamed into place, so a reader
// never sees half a record.
export function saveLogin(path: string, record: LoginRecord): void {
    const folder = dirname(path);
    const temporary = `${path}.${process.pid}.tmp`;

    mkdirSync(folder, { recursive: true, mode: 0o700 });
    chmodSync(folder, 0o700);

    writeFileSync(temporary, `${JSON.stringify(record, null, 2)}\n`, { mode: 0o600, flag: "wx" });
    renameSync(temporary, path);
}

// Reads the record, and refuses anything that is not a plain file owned
// by this user and closed to every other user, in a folder that is the
// same. A failure here always means "no login": the caller must refuse,
// never let the request through.
export function loadLogin(path: string): LoginRecord {
    const owner = typeof process.getuid === "function" ? process.getuid() : undefined;

    let folderStat;
    let stat;
    try {
        folderStat = lstatSync(dirname(path));
        stat = lstatSync(path);
    } catch {
        throw new LoginError("There is no login yet. Run scripts/voice-init.ts to make one.");
    }

    if (!folderStat.isDirectory() || (folderStat.mode & 0o077) !== 0) {
        throw new LoginError("The login's folder is open to other users, or is not a folder. It must be mode 0700.");
    }

    if (!stat.isFile()) {
        throw new LoginError("The login is not a plain file.");
    }

    if ((stat.mode & 0o077) !== 0) {
        throw new LoginError("The login file can be read by other users. It must be mode 0600.");
    }

    if (owner !== undefined && (stat.uid !== owner || folderStat.uid !== owner)) {
        throw new LoginError("The login file or its folder belongs to another user.");
    }

    let parsed: unknown;
    try {
        parsed = JSON.parse(readFileSync(path, "utf8"));
    } catch {
        throw new LoginError("The login file cannot be read as JSON.");
    }

    if (!isLoginRecord(parsed)) {
        throw new LoginError("The login file does not hold a valid login.");
    }

    return parsed;
}
