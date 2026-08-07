// CoopLog implementation. See CoopLog.h for rationale.
//
// VS2010 (v100) compatible: Win32 CRITICAL_SECTION + GetLocalTime, plain stdio.

#define _CRT_SECURE_NO_WARNINGS 1

#include "CoopLog.h"

#include <windows.h>
#include <cstdio>
#include <algorithm>
#include <string>
#include <vector>

namespace coop {
namespace {

FILE*            g_fp   = 0;
CRITICAL_SECTION g_cs;
bool             g_init = false;
char             g_tag[16] = { 0 };
volatile long    g_fakeSkewMs = 0;

void writeLine(const char* level, const char* msg) {
    if (!g_init) return;
    EnterCriticalSection(&g_cs);
    if (g_fp) {
        // Derive the stamp from wallClockMs() (real clock + injected skew) so
        // log timestamps and the wire time-sync share one clock.
        unsigned long ms = wallClockMs();
        unsigned long hh = (ms / 3600000ul) % 24ul;
        unsigned long mm = (ms / 60000ul) % 60ul;
        unsigned long ss = (ms / 1000ul) % 60ul;
        unsigned long mmm = ms % 1000ul;
        std::fprintf(g_fp, "[%02lu:%02lu:%02lu.%03lu] [%s] %s: %s\n",
                     hh, mm, ss, mmm,
                     g_tag, level, msg ? msg : "");
        std::fflush(g_fp);
    }
    LeaveCriticalSection(&g_cs);
}

} // namespace

unsigned long wallClockMs() {
    SYSTEMTIME st;
    GetLocalTime(&st);
    long ms = (long)((((unsigned long)st.wHour * 60ul + st.wMinute) * 60ul + st.wSecond) * 1000ul
                     + st.wMilliseconds);
    ms += g_fakeSkewMs;
    // Wrap into [0, 24h) so a skew across midnight still formats sanely.
    const long DAY = 24l * 3600l * 1000l;
    ms %= DAY;
    if (ms < 0) ms += DAY;
    return (unsigned long)ms;
}

void logSetFakeSkewMs(long skewMs) { g_fakeSkewMs = skewMs; }

void logInit(const char* path, const char* modeTag) {
    if (g_init) return;
    InitializeCriticalSection(&g_cs);
    g_init = true;

    if (modeTag) {
        size_t i = 0;
        for (; modeTag[i] && i < sizeof(g_tag) - 1; ++i) g_tag[i] = modeTag[i];
        g_tag[i] = '\0';
    }

    if (path && path[0]) {
        // Preserve the PREVIOUS run before truncating. Opening "w" wipes it, so
        // any crash's log was destroyed by the very next launch - which is how
        // three separate crash investigations lost their evidence, including two
        // where the dump was captured but the matching log was already gone.
        //
        // This used to keep ONE generation as "<path>.prev", on the assumption
        // that the run you want is always the one immediately before the
        // relaunch. That assumption broke on 2026-08-06: diagnosing a save-list
        // problem took several quick relaunches in a row, and each one rotated
        // the single .prev slot, so a 12.7 MB session log - the only record of
        // an invisible-player report - was gone before it could be read.
        // Timestamped archives survive a burst of relaunches; keep a few and
        // prune the rest so the folder cannot grow without bound.
        //
        // The ".log" tail is deliberate: SHARE_LOG.cmd globs KenshiCoop_*.log,
        // so archives are collected for diagnosis automatically.
        {
            const unsigned KEEP = 4;
            SYSTEMTIME st;
            GetLocalTime(&st);
            char arch[600];
            _snprintf(arch, sizeof(arch) - 1,
                      "%s.%04u%02u%02u-%02u%02u%02u.prev.log", path,
                      (unsigned)st.wYear, (unsigned)st.wMonth, (unsigned)st.wDay,
                      (unsigned)st.wHour, (unsigned)st.wMinute, (unsigned)st.wSecond);
            arch[sizeof(arch) - 1] = '\0';
            std::rename(path, arch); // no-op on a first run

            // Prune oldest archives. Names sort chronologically (the timestamp
            // is fixed-width and zero-padded), so plain lexical order is age
            // order - no need to stat anything.
            char dir[512], pat[600];
            size_t plen = 0;
            while (path[plen] && plen < sizeof(dir) - 1) ++plen;
            size_t cut = plen;
            while (cut > 0 && path[cut - 1] != '\\' && path[cut - 1] != '/') --cut;
            for (size_t i = 0; i < cut; ++i) dir[i] = path[i];
            dir[cut] = '\0';
            _snprintf(pat, sizeof(pat) - 1, "%s*.prev.log", path);
            pat[sizeof(pat) - 1] = '\0';

            std::vector<std::string> found;
            WIN32_FIND_DATAA fd;
            HANDLE h = FindFirstFileA(pat, &fd);
            if (h != INVALID_HANDLE_VALUE) {
                do {
                    if (!(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY))
                        found.push_back(std::string(fd.cFileName));
                } while (FindNextFileA(h, &fd));
                FindClose(h);
            }
            if (found.size() > KEEP) {
                std::sort(found.begin(), found.end());
                for (size_t i = 0; i + KEEP < found.size(); ++i) {
                    std::string full = std::string(dir) + found[i];
                    std::remove(full.c_str());
                }
            }
        }
        g_fp = std::fopen(path, "w"); // fresh file each run
    }
    writeLine("INFO", "log opened (previous run preserved as *.log.prev)");
}

void logLine(const char* msg)    { writeLine("INFO",  msg); }
void logErrLine(const char* msg) { writeLine("ERROR", msg); }

void logClose() {
    if (!g_init) return;
    EnterCriticalSection(&g_cs);
    if (g_fp) {
        std::fflush(g_fp);
        std::fclose(g_fp);
        g_fp = 0;
    }
    LeaveCriticalSection(&g_cs);
}

} // namespace coop
