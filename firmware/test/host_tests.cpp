// Host-side unit tests for the pure-C++ parts of the firmware.
// Build & run:  g++ -std=c++17 -Wall -Wextra -I src
//     test/host_tests.cpp src/protocol.cpp src/mixer.cpp -o /tmp/host_tests && /tmp/host_tests

#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "protocol.h"
#include "mixer.h"
#include "failsafe.h"

using namespace proto;

static void test_crc_known_vector() {
    // CRC-16/CCITT-FALSE of "123456789" == 0x29B1 (canonical check value).
    const char* s = "123456789";
    assert(crc16((const uint8_t*)s, 9) == 0x29B1);
    printf("ok crc16 check value\n");
}

static void test_rc_roundtrip() {
    RcPacket p;
    p.flags = FLAG_ARMED | FLAG_INVERT;
    p.seq = 4242;
    p.ch[0] = 500; p.ch[1] = -750; p.ch[2] = 1000; p.ch[3] = 0; p.ch[4] = -1000;
    encodeRc(p);

    RcPacket q;
    assert(decodeRc((const uint8_t*)&p, kRcPacketSize, q));
    assert(q.flags == p.flags && q.seq == p.seq);
    for (int i = 0; i < kChannelCount; i++) assert(q.ch[i] == p.ch[i]);
    printf("ok rc roundtrip\n");
}

static void test_rc_rejects_bad() {
    RcPacket p;
    p.seq = 1;
    encodeRc(p);
    uint8_t* b = (uint8_t*)&p;

    RcPacket q;
    b[0] = 'X';                                   // bad magic
    assert(!decodeRc(b, kRcPacketSize, q));
    b[0] = 'R';
    b[10] ^= 0xFF;                                // corrupt channel byte -> CRC fails
    assert(!decodeRc(b, kRcPacketSize, q));
    assert(!decodeRc(b, kRcPacketSize - 1, q));   // short read
    printf("ok rc rejects corrupt/short packets\n");
}

static void test_rc_clamps() {
    RcPacket p;
    p.seq = 7;
    encodeRc(p);
    uint8_t* b = (uint8_t*)&p;
    // Overwrite ch[0] with 3000 (out of range) then fix CRC so decode passes.
    int16_t over = 3000;
    b[6] = over & 0xFF; b[7] = (over >> 8) & 0xFF;
    p.crc = crc16(b, 16);
    b[16] = p.crc & 0xFF; b[17] = p.crc >> 8;

    RcPacket q;
    assert(decodeRc(b, kRcPacketSize, q));
    assert(q.ch[0] == 1000);
    printf("ok rc clamps out-of-range channels\n");
}

static void test_seq_and_linkstats() {
    assert(seqNewer(2, 1));
    assert(!seqNewer(1, 2));
    assert(seqNewer(0, 65535));          // wraparound
    assert(!seqNewer(65535, 0));

    LinkStats ls;
    assert(ls.accept(10));               // first packet always accepted
    assert(!ls.accept(10));              // dup rejected
    assert(!ls.accept(9));               // stale rejected
    assert(ls.accept(12));               // skipped 11 -> 1 lost
    assert(ls.lost == 1);
    assert(ls.lastSeq == 12);
    printf("ok seq ordering + lost counting\n");
}

static void test_mixer() {
    DriveOutput d;

    d = mixDifferential(0, 0, false, false, 0);
    assert(d.left == 0 && d.right == 0);

    d = mixDifferential(500, 0, false, false, 0);
    assert(d.left == 500 && d.right == 500);

    d = mixDifferential(0, 500, false, false, 0);
    assert(d.left == 500 && d.right == -500);   // turn right in place

    d = mixDifferential(1000, 500, false, false, 0);
    assert(d.left == 1000 && d.right == 333);   // rescaled proportionally

    d = mixDifferential(500, 0, false, true, 0);
    assert(d.left == -500 && d.right == -500);  // inverted

    d = mixDifferential(1000, 0, true, false, 0);
    assert(d.left == 400 && d.right == 400);    // low-speed 40%

    d = mixDifferential(30, 30, false, false, 40);
    assert(d.left == 0 && d.right == 0);        // deadband

    printf("ok mixer\n");
}

static void test_failsafe() {
    Failsafe fs(300);
    assert(fs.active(0));                 // never linked = unsafe
    fs.onValidPacket(1000);
    assert(!fs.active(1000));
    assert(!fs.active(1300));             // exactly at timeout boundary = ok
    assert(fs.active(1301));              // 1 ms past = trip
    fs.reset();
    assert(fs.active(2000));
    printf("ok failsafe\n");
}

static void test_telemetry_roundtrip() {
    TelemetryPacket t;
    t.flags = TELE_LINKED | TELE_ARMED;
    t.lastSeq = 1234;
    t.batteryMv = 12400;
    t.rssiDbm = -55;
    t.rxRateX10 = 497;
    t.lost = 3;
    encodeTelemetry(t);

    TelemetryPacket u;
    assert(decodeTelemetry((const uint8_t*)&t, kTelemetryPacketSize, u));
    assert(u.flags == t.flags && u.lastSeq == t.lastSeq &&
           u.batteryMv == t.batteryMv && u.rssiDbm == t.rssiDbm &&
           u.rxRateX10 == t.rxRateX10 && u.lost == t.lost);

    uint8_t* b = (uint8_t*)&t;
    b[6] ^= 0xFF;                         // corrupt -> reject
    assert(!decodeTelemetry(b, kTelemetryPacketSize, u));
    printf("ok telemetry roundtrip + crc rejection\n");
}

int main() {
    test_crc_known_vector();
    test_rc_roundtrip();
    test_rc_rejects_bad();
    test_rc_clamps();
    test_seq_and_linkstats();
    test_mixer();
    test_failsafe();
    test_telemetry_roundtrip();
    printf("ALL TESTS PASSED\n");
    return 0;
}
