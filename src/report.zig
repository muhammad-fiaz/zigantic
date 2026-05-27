//! Report and Version Utilities
//!
//! Provides functionality for error reporting and checking for library updates.

const std = @import("std");
const builtin = @import("builtin");
const http = std.http;
const SemanticVersion = std.SemanticVersion;
const version_info = @import("version.zig");
const utils = @import("utils.zig");
const Network = @import("network.zig");

/// URL for reporting issues on GitHub.
pub const ISSUES_URL = "https://github.com/muhammad-fiaz/zigantic/issues";

/// GitHub repository owner.
const REPO_OWNER = "muhammad-fiaz";

/// GitHub repository name.
const REPO_NAME = "zigantic";

/// Current version of the library.
const CURRENT_VERSION: []const u8 = version_info.version;

/// Reports a library bug/runtime error with instructions for filing a bug report.
/// Use this ONLY for unexpected errors that indicate a bug in zigantic itself.
/// Do NOT use this for validation errors - those are expected user errors.
///
/// Example usage (inside zigantic library code):
/// ```zig
/// // For unexpected internal errors
/// report.reportInternalError("Unexpected null pointer in parser");
/// ```
pub fn reportInternalError(message: []const u8) void {
    std.debug.print("\n[ZIGANTIC ERROR] {s}\n", .{message});
    std.debug.print("\nIf you believe this is a bug in zigantic, please report it at:\n  {s}\n\n", .{ISSUES_URL});
}

/// Reports a library bug with an error value.
/// Use this ONLY for unexpected errors that indicate a bug in zigantic itself.
pub fn reportInternalErrorWithCode(err: anyerror) void {
    std.debug.print("\n[ZIGANTIC ERROR] {}\n", .{err});
    std.debug.print("\nIf you believe this is a bug in zigantic, please report it at:\n  {s}\n\n", .{ISSUES_URL});
}

// Legacy aliases (deprecated - use reportInternalError instead)
pub const reportError = reportInternalErrorWithCode;
pub const reportErrorMessage = reportInternalError;

/// Static flag to ensure update check runs only once per process.
var update_check_done = false;
var update_check_mutex: std.atomic.Mutex = .unlocked;

const stripVersionPrefix = utils.stripVersionPrefix;
const parseSemver = utils.parseSemver;

/// Represents the relationship between local and remote versions.
const VersionRelation = enum {
    local_newer,
    equal,
    remote_newer,
    unknown,
};

/// Compares the current version with the latest remote version.
fn compareVersions(latest_raw: []const u8) VersionRelation {
    const latest = stripVersionPrefix(latest_raw);
    const current = stripVersionPrefix(CURRENT_VERSION);

    if (parseSemver(current)) |cur| {
        if (parseSemver(latest)) |lat| {
            if (lat.major != cur.major) return if (lat.major > cur.major) .remote_newer else .local_newer;
            if (lat.minor != cur.minor) return if (lat.minor > cur.minor) .remote_newer else .local_newer;
            if (lat.patch != cur.patch) return if (lat.patch > cur.patch) .remote_newer else .local_newer;
            return .equal;
        }
    }

    if (std.mem.eql(u8, current, latest)) return .equal;
    return .unknown;
}

/// Fetches the latest release tag from GitHub.
fn fetchLatestTag(allocator: std.mem.Allocator, io: std.Io) ![]const u8 {
    const url = std.fmt.comptimePrint("https://api.github.com/repos/{s}/{s}/releases/latest", .{ REPO_OWNER, REPO_NAME });
    const extra_headers = [_]http.Header{
        .{ .name = "Accept", .value = "application/vnd.github+json" },
    };

    var parsed = Network.fetchJson(allocator, url, &extra_headers, io) catch return error.TagMissing;
    defer parsed.deinit();

    return switch (parsed.value) {
        .object => |obj| blk: {
            if (obj.get("tag_name")) |tag_value| {
                switch (tag_value) {
                    .string => |s| break :blk try allocator.dupe(u8, s),
                    else => break :blk error.TagMissing,
                }
            }
            break :blk error.TagMissing;
        },
        else => error.TagMissing,
    };
}

/// Checks for updates in a background thread (runs only once per process).
/// Returns a thread handle so callers can optionally join during shutdown.
/// Fails silently on errors (no internet, API limits, etc).
pub fn checkForUpdates(allocator: std.mem.Allocator) ?std.Thread {
    while (!update_check_mutex.tryLock()) {
        std.atomic.spinLoopHint();
    }
    defer update_check_mutex.unlock();

    // Prevent multiple concurrent update checks
    if (update_check_done) return null;
    update_check_done = true;

    return std.Thread.spawn(.{}, checkWorker, .{allocator}) catch null;
}

/// Worker function that performs the actual update check.
fn checkWorker(allocator: std.mem.Allocator) void {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const latest_tag = fetchLatestTag(allocator, io) catch return;
    defer allocator.free(latest_tag);

    // Use ASCII-safe indicators instead of emoji for cross-platform compatibility
    switch (compareVersions(latest_tag)) {
        .remote_newer => std.log.info("[UPDATE] A newer release of zigantic is available: {s} (current {s})", .{ latest_tag, CURRENT_VERSION }),
        .local_newer => std.log.info("[NIGHTLY] Running a dev/nightly build ahead of latest release: current {s}, latest {s}", .{ CURRENT_VERSION, latest_tag }),
        else => {},
    }
}

/// Synchronously checks for updates and returns version info.
/// Returns null if the check fails or versions are equal.
pub const UpdateInfo = struct {
    latest_version: []const u8,
    current_version: []const u8,
    update_available: bool,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *UpdateInfo) void {
        self.allocator.free(self.latest_version);
    }
};

/// Synchronously checks for updates and returns update information.
/// This is useful for applications that want to handle the update notification themselves.
pub fn checkForUpdatesSync(allocator: std.mem.Allocator) !UpdateInfo {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const latest_tag = try fetchLatestTag(allocator, io);
    errdefer allocator.free(latest_tag);

    const relation = compareVersions(latest_tag);

    return UpdateInfo{
        .latest_version = latest_tag,
        .current_version = CURRENT_VERSION,
        .update_available = relation == .remote_newer,
        .allocator = allocator,
    };
}

/// Returns the current library version.
pub fn getCurrentVersion() []const u8 {
    return CURRENT_VERSION;
}

/// Returns the GitHub issues URL.
pub fn getIssuesUrl() []const u8 {
    return ISSUES_URL;
}

test "stripVersionPrefix" {
    try std.testing.expectEqualStrings("1.0.0", stripVersionPrefix("v1.0.0"));
    try std.testing.expectEqualStrings("1.0.0", stripVersionPrefix("V1.0.0"));
    try std.testing.expectEqualStrings("1.0.0", stripVersionPrefix("1.0.0"));
    try std.testing.expectEqualStrings("", stripVersionPrefix(""));
}

test "compareVersions equal" {
    // Test with current version
    const result = compareVersions(CURRENT_VERSION);
    try std.testing.expect(result == .equal);
}

test "getCurrentVersion" {
    try std.testing.expectEqualStrings(version_info.version, getCurrentVersion());
}

test "getIssuesUrl" {
    try std.testing.expectEqualStrings("https://github.com/muhammad-fiaz/zigantic/issues", getIssuesUrl());
}
