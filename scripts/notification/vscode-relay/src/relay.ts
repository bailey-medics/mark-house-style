// The banner relay's logic, kept apart from VS Code so it can be tested.
//
// The relay runs on the Mac, inside VS Code's window process. It reads the
// banner queue on the box through VS Code's own connection, and hands the
// lines to notification-queue.py, which checks them and shows each banner
// once. These functions decide which box, which file, and which window
// does the relaying.

// The same names notification-queue.py accepts for a box: an SSH host as
// VS Code knows it, or a tunnel as "tunnel+<name>".
const BOX_PATTERN = /^(tunnel\+)?[A-Za-z0-9._][A-Za-z0-9._-]{0,99}$/;

const HOME_PATTERN = /^(\/home\/[A-Za-z0-9._-]+|\/root)(\/|$)/;

export const QUEUE_UNDER_HOME = "/.local/state/quill-notify/banners.jsonl";

// The box for the banner's click, from VS Code's remote authority:
// "ssh-remote+devbox" gives "devbox", and "tunnel+devbox-tunnel" is kept
// whole, so the click knows to look for a tunnel window.
export function boxFromAuthority(authority: string | undefined): string | undefined {
    if (authority === undefined) {
        return undefined;
    }

    let box: string;

    if (authority.startsWith("ssh-remote+")) {
        box = authority.slice("ssh-remote+".length);
    } else if (authority.startsWith("tunnel+")) {
        box = authority;
    } else {
        return undefined;
    }

    return BOX_PATTERN.test(box) ? box : undefined;
}

export function isBox(value: string): boolean {
    return BOX_PATTERN.test(value);
}

// The queue's path on the box, from the home folder of any open remote
// folder: /home/<user>/... or /root/....
export function queueFromFolders(paths: readonly string[]): string | undefined {
    for (const path of paths) {
        const match = HOME_PATTERN.exec(path);
        if (match?.[1] !== undefined) {
            return match[1] + QUEUE_UNDER_HOME;
        }
    }

    return undefined;
}

// The last `count` non-empty lines, as `tail -n` would give them.
export function lastLines(text: string, count: number): string[] {
    const lines = text.split("\n").filter((line) => line.trim() !== "");

    return lines.slice(-count);
}

// One VS Code window relays at a time: the one that wrote the lock last,
// while it keeps writing it. A lock not refreshed within `staleMs` is free.
export function mayRelay(lock: string | undefined, me: string, now: number, staleMs: number): boolean {
    if (lock === undefined) {
        return true;
    }

    const [holder, stamp] = lock.trim().split(" ");
    const written = Number(stamp);

    if (holder === me) {
        return true;
    }

    return !Number.isFinite(written) || now - written > staleMs;
}

export function lockLine(me: string, now: number): string {
    return `${me} ${now}\n`;
}

// Where the Mac keeps its record of the banners already shown. The relay
// shares it with the SSH listener, so a banner shows once even when both
// work. Quill Medical's listener, when installed, keeps its own.
export function stateFile(home: string, quillListenerInstalled: boolean): string {
    const folder = quillListenerInstalled ? "quill-notifier" : "turva-notifier";

    return `${home}/Library/Caches/${folder}/last-shown`;
}
