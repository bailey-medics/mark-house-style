// Checks on a message arriving at the channel's socket, kept apart so the
// tests can reach them without a socket.

// The longest message the channel accepts, in characters. A spoken turn
// is rarely more than a few hundred.
export const MAX_TEXT_LENGTH = 2000;

// The most bytes read from one connection before its first newline. Text
// can be up to four bytes a character in UTF-8, and the JSON around it
// adds a little more.
export const MAX_LINE_BYTES = MAX_TEXT_LENGTH * 4 + 256;

export type ParsedMessage =
    | { ok: true; text: string }
    | { ok: false; reason: string };

// Reads one line of JSON, {"text": "..."}, and says whether it is a
// message the channel should pass on.
export function parseMessage(line: string): ParsedMessage {
    let data: unknown;

    try {
        data = JSON.parse(line);
    } catch {
        return { ok: false, reason: "not valid JSON" };
    }

    if (typeof data !== "object" || data === null || !("text" in data)) {
        return { ok: false, reason: "no text" };
    }

    const text = data.text;
    if (typeof text !== "string") {
        return { ok: false, reason: "text is not a string" };
    }

    if (text.trim() === "") {
        return { ok: false, reason: "text is empty" };
    }

    if (text.length > MAX_TEXT_LENGTH) {
        return { ok: false, reason: `text is longer than ${MAX_TEXT_LENGTH} characters` };
    }

    return { ok: true, text };
}
