import AVFoundation
import Foundation
import Speech

protocol SpeechBridgeDelegate: AnyObject {
    /// A chunk of transcript. `isFinal` chunks are appended by the page; the non-final
    /// chunk is the live tail and replaces the previous one.
    func speechBridge(_ bridge: SpeechBridge, didProduce chunk: String, isFinal: Bool)
    /// Web Speech API error code: "not-allowed", "audio-capture", "network", "aborted".
    func speechBridge(_ bridge: SpeechBridge, didFailWith code: String)
    /// The session is over; the page may start a new one.
    func speechBridgeDidEnd(_ bridge: SpeechBridge)
}

/// Streams `SFSpeechRecognizer` output into the page's `window.__nativeSpeech` shim,
/// reshaped to match Web Speech API semantics.
///
/// `SFSpeechRecognizer` reports a cumulative transcript that it may revise near the tail,
/// while the page expects append-only finals plus one replaceable partial. The bridge
/// therefore treats everything older than the last few words as settled, emits it once as
/// a final chunk, and re-emits only the unsettled tail as the partial.
///
/// All state is owned by the main queue. The audio tap runs on a render thread and touches
/// only `lockedRequest`.
final class SpeechBridge: NSObject {
    weak var delegate: SpeechBridgeDelegate?

    /// Words kept "live" at the end of the transcript, where the recognizer still revises.
    private let unsettledTail = 5
    /// Consecutive instant, wordless task deaths before giving up on the recognizer.
    private let failureBudget = 3
    /// A task that dies this fast without a word died of a fault, not of silence.
    private let faultWindow: TimeInterval = 1.0

    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?

    private var isRunning = false
    private var tapInstalled = false
    /// Words of the current request's transcript already emitted as final.
    private var emittedWords = 0
    /// The unsettled tail last shown to the page, kept so a rotation can finalize it.
    private var pendingTail: String?
    /// Consecutive recognition tasks that died instantly without producing a word.
    private var barrenTasks = 0
    private var taskStartedAt = Date.distantPast

    /// Shared with the audio render thread; every access goes through `requestLock`.
    private var lockedRequest: SFSpeechAudioBufferRecognitionRequest?
    private let requestLock = NSLock()

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil)
    }

    // MARK: - Public control

    func start(languageTag: String) {
        guard !isRunning else { return }
        isRunning = true
        barrenTasks = 0
        authorize { [weak self] code in
            guard let self, self.isRunning else { return }
            guard let code else {
                self.beginSession(languageTag: languageTag)
                return
            }
            self.isRunning = false
            self.delegate?.speechBridge(self, didFailWith: code)
            self.delegate?.speechBridgeDidEnd(self)
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        teardown()
        delegate?.speechBridgeDidEnd(self)
    }

    // MARK: - Permissions

    private func authorize(_ completion: @escaping (String?) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async { completion("not-allowed") }
                return
            }
            Self.requestMicrophone { granted in
                DispatchQueue.main.async { completion(granted ? nil : "not-allowed") }
            }
        }
    }

    private static func requestMicrophone(_ completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: completion)
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission(completion)
        }
    }

    // MARK: - Session

    private func beginSession(languageTag: String) {
        let locale = languageTag.isEmpty ? Locale.current : Locale(identifier: languageTag)
        guard let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(),
              recognizer.isAvailable else {
            fail("network")
            return
        }
        self.recognizer = recognizer

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            fail("audio-capture")
            return
        }

        if !tapInstalled {
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                fail("audio-capture")
                return
            }
            input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
                guard let self else { return }
                self.requestLock.lock()
                self.lockedRequest?.append(buffer)
                self.requestLock.unlock()
            }
            tapInstalled = true
        }

        startTask()

        engine.prepare()
        do {
            try engine.start()
        } catch {
            fail("audio-capture")
            return
        }
    }

    /// Starts a fresh recognition request against the already-running audio tap.
    private func startTask() {
        guard let recognizer else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.addsPunctuation = false

        requestLock.lock()
        lockedRequest = request
        requestLock.unlock()

        emittedWords = 0
        pendingTail = nil
        taskStartedAt = Date()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.isRunning else { return }
                if let result {
                    self.emit(result.bestTranscription.formattedString, settled: result.isFinal)
                }
                guard error != nil || (result?.isFinal ?? false) else { return }
                // A task ending mid-session is normal — silence, or the length limit that
                // server-based recognition imposes. Keep the mic open and start another one so
                // the page never sees a gap, unless nothing is coming through at all, which
                // means the recognizer itself is unusable.
                // Distinguish a broken recognizer from a quiet room: a fault fails
                // immediately, while silence takes seconds to time out. Tearing the mic down
                // over a pause would leave the presenter deaf for a second or two.
                let heardNothing = self.emittedWords == 0 && (self.pendingTail?.isEmpty ?? true)
                let diedInstantly = Date().timeIntervalSince(self.taskStartedAt) < self.faultWindow
                if heardNothing && diedInstantly {
                    self.barrenTasks += 1
                    if self.barrenTasks >= self.failureBudget {
                        self.fail(error == nil ? "aborted" : "network")
                        return
                    }
                } else {
                    self.barrenTasks = 0
                }
                self.rotateTask()
            }
        }
    }

    /// Swaps in a new request/task without disturbing the audio tap.
    ///
    /// A task that died without delivering a final still left its last few words with the page
    /// as a replaceable partial. Settle them here, or the next task's first partial would
    /// silently erase them and the prompter would stall a line behind.
    private func rotateTask() {
        guard isRunning else { return }
        if let tail = pendingTail, !tail.isEmpty {
            delegate?.speechBridge(self, didProduce: tail, isFinal: true)
        }
        endCurrentRequest()
        startTask()
    }

    private func endCurrentRequest() {
        requestLock.lock()
        let request = lockedRequest
        lockedRequest = nil
        requestLock.unlock()
        request?.endAudio()
        task?.cancel()
        task = nil
        pendingTail = nil
    }

    private func emit(_ transcript: String, settled: Bool) {
        let words = transcript.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return }

        if settled {
            if emittedWords < words.count {
                let chunk = words[emittedWords...].joined(separator: " ")
                emittedWords = words.count
                pendingTail = nil
                delegate?.speechBridge(self, didProduce: chunk, isFinal: true)
            }
            return
        }

        let settledCount = max(0, words.count - unsettledTail)
        if settledCount > emittedWords {
            let chunk = words[emittedWords..<settledCount].joined(separator: " ")
            emittedWords = settledCount
            delegate?.speechBridge(self, didProduce: chunk, isFinal: true)
        }
        let tail = words[emittedWords...].joined(separator: " ")
        pendingTail = tail
        delegate?.speechBridge(self, didProduce: tail, isFinal: false)
    }

    // MARK: - Failure & teardown

    private func fail(_ code: String) {
        isRunning = false
        teardown()
        delegate?.speechBridge(self, didFailWith: code)
        // The page retries on `end`; hold it off briefly so a persistent audio failure
        // (a phone call, a stolen route) cannot spin into a restart loop.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            self.delegate?.speechBridgeDidEnd(self)
        }
    }

    private func teardown() {
        endCurrentRequest()
        emittedWords = 0
        barrenTasks = 0
        taskStartedAt = .distantPast
        if engine.isRunning { engine.stop() }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    @objc private func handleInterruption(_ note: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isRunning,
                  let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            self.isRunning = false
            self.teardown()
            self.delegate?.speechBridge(self, didFailWith: "aborted")
            self.delegate?.speechBridgeDidEnd(self)
        }
    }
}
