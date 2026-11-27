// When a banner clears itself, kept apart from VS Code so it can be tested.
//
// A banner names its worktree. Once that worktree's window has been in
// front for a few seconds, and the banner has been up as long, the banner
// has been seen, so the relay asks notification-dismiss.sh to take it back.
// notification-show.sh leaves a note per banner group to say one is up.

// The same group names notification-show.sh will leave a note for.
const GROUP_PATTERN = /^[A-Za-z0-9_][A-Za-z0-9._-]{0,99}$/;

// The banner group for a worktree's folder, worked out as notification.sh
// on the box works it out: the folder's name, with Juttu's folders, which
// carry the repository's full name, shortened to the session's. The two
// must agree, or a window clears nothing.
export function groupForFolder(path: string): string | undefined {
    const folder = path.replace(/\/+$/, "").split("/").pop() ?? "";
    let name = folder;

    if (folder === "juttu-messaging") {
        name = "juttu";
    } else if (/^juttu-messaging-[1-9]/.test(folder)) {
        name = `juttu-${folder.slice(folder.lastIndexOf("-") + 1)}`;
    }

    const group = `turva-claude-${name}`;

    return name !== "" && GROUP_PATTERN.test(group) ? group : undefined;
}

// Each group once, for every folder open in the window.
export function groupsForFolders(paths: readonly string[]): string[] {
    const groups = paths.map(groupForFolder).filter((group): group is string => group !== undefined);

    return [...new Set(groups)];
}

export function noteFile(home: string, group: string): string {
    return `${home}/Library/Caches/turva-notifier/banners/${group}`;
}

// Clear a banner once the window has been in front, and the banner up, for
// `waitMs` each. Times are in milliseconds; undefined means the window is
// not in front, or there is no banner.
export function shouldDismiss(
    focusedSince: number | undefined,
    bannerShown: number | undefined,
    now: number,
    waitMs: number,
): boolean {
    if (focusedSince === undefined || bannerShown === undefined) {
        return false;
    }

    return now - focusedSince >= waitMs && now - bannerShown >= waitMs;
}
