import Foundation

/// A durable key/value store the page falls back to if `localStorage` is unavailable.
///
/// The page reads its scripts synchronously at startup, so the whole store is injected
/// as a seed before any page script runs; writes come back asynchronously.
final class NativeStore {
    private let fileURL: URL
    private var values: [String: String]
    private var flushScheduled = false

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("voicecue-store.json")
        let data = (try? Data(contentsOf: fileURL)) ?? Data()
        values = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    /// A JSON object literal safe to embed in a `<script>` — used to seed the page.
    var seedJSON: String {
        guard let data = try? JSONEncoder().encode(values),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }

    func set(_ key: String, _ value: String) {
        values[key] = value
        scheduleFlush()
    }

    func remove(_ key: String) {
        values.removeValue(forKey: key)
        scheduleFlush()
    }

    func clear() {
        values.removeAll()
        scheduleFlush()
    }

    private func scheduleFlush() {
        guard !flushScheduled else { return }
        flushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }
            self.flushScheduled = false
            self.flush()
        }
    }

    func flush() {
        guard let data = try? JSONEncoder().encode(values) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
