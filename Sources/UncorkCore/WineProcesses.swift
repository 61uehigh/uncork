import Darwin
import Foundation

/// Finds and stops Wine processes. Wine rewrites a process's name to the Windows path
/// (`C:\windows\system32\winedevice.exe`), so they're matched by their executable and environment instead.
enum WineProcesses {
    /// Processes running a Wine runtime from `runtimes` with a `WINEPREFIX` inside `prefixes`. Checking the prefix
    /// leaves alone anyone else who happens to run Wine from Uncork's runtime with their own prefix.
    static func running(fromRuntimes runtimes: URL, inPrefixes prefixes: URL) -> [pid_t] {
        let prefixRoots = Set([prefixes.path, realPath(prefixes)].compactMap { $0 }).map { $0 + "/" }
        return running(from: runtimes).filter { pid in
            guard let prefix = environmentValue("WINEPREFIX", of: pid) else { return false }
            return prefixRoots.contains { prefix.hasPrefix($0) }
        }
    }

    /// Processes whose executable is inside `directory`.
    static func running(from directory: URL) -> [pid_t] {
        guard let root = realPath(directory).map({ $0 + "/" }) else { return [] }
        // The process list can grow between the two calls, so leave some headroom.
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(estimate) + 64)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard count > 0 else { return [] }

        var path = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        return pids.prefix(Int(count)).filter { pid in
            let length = proc_pidpath(pid, &path, UInt32(path.count))
            guard pid > 0, pid != getpid(), length > 0 else { return false }
            let executable = String(decoding: path.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
            return executable.hasPrefix(root)
        }
    }

    /// Asks each process to quit, then kills whatever is still running after `grace`.
    static func stop(_ pids: [pid_t], grace: Duration = .seconds(2)) async {
        guard !pids.isEmpty else { return }
        for pid in pids { kill(pid, SIGTERM) }
        let deadline = ContinuousClock.now + grace
        var remaining = pids
        while !remaining.isEmpty, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
            remaining = remaining.filter(isAlive)
        }
        for pid in remaining { kill(pid, SIGKILL) }
    }

    static func isAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0
    }

    /// The kernel reports real paths, e.g. /private/var rather than /var. Foundation's symlink resolution strips
    /// /private again, so this uses realpath(3).
    static func realPath(_ url: URL) -> String? {
        guard let resolved = realpath(url.path, nil) else { return nil }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    /// One variable from another process's environment, read with `KERN_PROCARGS2`. Only works for the current
    /// user's processes.
    ///
    /// The buffer holds argc, the executable path, then the arguments and environment as NUL-terminated strings.
    /// Wine rewrites its arguments in place to show Windows paths, which can change how many strings there are, so
    /// rather than counting past the arguments this takes the last `key=` string, since the environment comes last.
    static func environmentValue(_ key: String, of pid: pid_t) -> String? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }

        let marker = key + "="
        return buffer[MemoryLayout<Int32>.size..<size]
            .split(separator: 0)
            .dropFirst()  // the executable path
            .map { String(decoding: $0, as: UTF8.self) }
            .last { $0.hasPrefix(marker) }
            .map { String($0.dropFirst(marker.count)) }
    }
}
