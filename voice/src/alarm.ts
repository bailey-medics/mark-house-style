// The alarm: many wrong tokens in a short time are worth Mark knowing
// about, so the bridge says so in its log. It never locks anything. A
// lock would add no safety, because nobody can guess a 256 bit token, and
// it would hand a stranger a way to shut Mark out: anyone can make
// Anthropic's servers send a wrong token to the bridge.

export const WRONG_TOKEN_ALARM_COUNT = 10;
export const WRONG_TOKEN_WINDOW_MS = 60 * 60 * 1000;

export type WrongTokenAlarm = {
    // Records one wrong token. True when the alarm should be raised, which
    // is at most once in each window, so a flood cannot fill the log with
    // alarms.
    wrong: (now: Date) => boolean;
};

export function createWrongTokenAlarm(
    count: number = WRONG_TOKEN_ALARM_COUNT,
    windowMs: number = WRONG_TOKEN_WINDOW_MS,
): WrongTokenAlarm {
    if (!Number.isInteger(count) || count < 1 || !(windowMs > 0)) {
        throw new Error("The alarm needs a count of at least 1 and a window longer than nothing.");
    }

    // Never more than `count` times are kept, however many arrive.
    let recent: number[] = [];
    let lastRaised: number | undefined;

    return {
        wrong(now: Date): boolean {
            const time = now.getTime();
            recent = recent.filter((earlier) => time - earlier < windowMs);
            recent.push(time);
            recent = recent.slice(-count);

            if (recent.length < count) {
                return false;
            }

            if (lastRaised !== undefined && time - lastRaised < windowMs) {
                return false;
            }

            lastRaised = time;

            return true;
        },
    };
}
