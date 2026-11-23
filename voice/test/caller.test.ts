import assert from "node:assert/strict";
import { test } from "node:test";
import { checkCaller, inRange, parseIPv4 } from "../src/caller.ts";

const LOOPBACK = "127.0.0.1";

test("an address inside each Anthropic range passes", () => {
    for (const caller of ["160.79.104.0", "160.79.111.255", "153.61.208.0", "153.61.223.255"]) {
        assert.deepEqual(checkCaller(LOOPBACK, caller), { allowed: true, caller });
    }
});

test("an address just outside each range is refused", () => {
    for (const caller of ["160.79.103.255", "160.79.112.0", "153.61.207.255", "153.61.224.0"]) {
        assert.equal(checkCaller(LOOPBACK, caller).allowed, false, caller);
    }
});

test("a missing, empty, repeated or malformed header is refused", () => {
    assert.equal(checkCaller(LOOPBACK, undefined).allowed, false);
    assert.equal(checkCaller(LOOPBACK, "").allowed, false);
    assert.equal(checkCaller(LOOPBACK, ["160.79.104.1", "160.79.104.2"]).allowed, false);
    assert.equal(checkCaller(LOOPBACK, "160.79.104").allowed, false);
    assert.equal(checkCaller(LOOPBACK, "160.79.104.999").allowed, false);
    assert.equal(checkCaller(LOOPBACK, "2001:db8::1").allowed, false);
});

test("the header is ignored on a connection that is not from loopback", () => {
    assert.equal(checkCaller("192.0.2.10", "160.79.104.1").allowed, false);
    assert.equal(checkCaller(undefined, "160.79.104.1").allowed, false);
});

test("IPv6 loopback forms count as loopback", () => {
    assert.equal(checkCaller("::1", "160.79.104.1").allowed, true);
    assert.equal(checkCaller("::ffff:127.0.0.1", "160.79.104.1").allowed, true);
});

test("parseIPv4 and inRange read addresses correctly", () => {
    assert.equal(parseIPv4("0.0.0.1"), 1);
    assert.equal(parseIPv4("1.2.3"), null);
    assert.equal(parseIPv4("01x.2.3.4"), null);
    assert.equal(inRange("10.0.0.1", "10.0.0.0/8"), true);
    assert.equal(inRange("11.0.0.1", "10.0.0.0/8"), false);
    assert.equal(inRange("10.0.0.1", "10.0.0.0/33"), false);
});
