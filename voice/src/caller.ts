// Decides whether a request to the bridge came from Anthropic, through the
// tunnel. A quick tunnel has no filter at Cloudflare's edge, so this is
// the only address check while it is in use.

// The ranges Anthropic's servers call from, as published at
// https://platform.claude.com/docs/en/api/ip-addresses. Check them again
// before each use: they can change.
export const ANTHROPIC_RANGES = ["160.79.104.0/21", "153.61.208.0/20"] as const;

// cloudflared puts the real caller's address in this header.
export const CALLER_HEADER = "cf-connecting-ip";

export type CallerVerdict =
    | { allowed: true; caller: string }
    | { allowed: false; reason: string };

// Reads a dotted IPv4 address as a number, or null if it is not one.
export function parseIPv4(address: string): number | null {
    const parts = address.split(".");
    if (parts.length !== 4) {
        return null;
    }

    let value = 0;

    for (const part of parts) {
        // No leading zeros: 010 could be read as ten or as eight.
        if (!/^(0|[1-9]\d{0,2})$/.test(part)) {
            return null;
        }

        const octet = Number(part);
        if (octet > 255) {
            return null;
        }

        value = value * 256 + octet;
    }

    return value;
}

export function inRange(address: string, cidr: string): boolean {
    const [base, bitsText] = cidr.split("/");
    const ip = parseIPv4(address);
    const start = parseIPv4(base ?? "");
    const bits = Number(bitsText);

    if (ip === null || start === null || !Number.isInteger(bits) || bits < 0 || bits > 32) {
        return false;
    }

    const size = 2 ** (32 - bits);

    return Math.floor(ip / size) === Math.floor(start / size);
}

export function isLoopback(remoteAddress: string | undefined): boolean {
    return (
        remoteAddress === "127.0.0.1" ||
        remoteAddress === "::1" ||
        remoteAddress === "::ffff:127.0.0.1"
    );
}

// The header is only believed on a connection from loopback, where
// cloudflared is the only thing that can connect. Anything unsure is
// refused.
export function checkCaller(
    remoteAddress: string | undefined,
    header: string | string[] | undefined,
): CallerVerdict {
    if (!isLoopback(remoteAddress)) {
        return { allowed: false, reason: "not a loopback connection" };
    }

    if (typeof header !== "string" || header === "") {
        return { allowed: false, reason: "no caller header" };
    }

    const caller = header.trim();
    if (parseIPv4(caller) === null) {
        return { allowed: false, reason: "caller is not an IPv4 address" };
    }

    if (!ANTHROPIC_RANGES.some((range) => inRange(caller, range))) {
        return { allowed: false, reason: "caller is outside Anthropic's ranges" };
    }

    return { allowed: true, caller };
}
