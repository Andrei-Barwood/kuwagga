import Foundation

@MainActor
enum Processor {
    static func destinations(session: Session, format: ExportFormat) -> [URL] {
        guard let outputRoot = session.outputRoot else { return [] }
        return session.tracks.map { input in
            AudioIO.outputURL(
                for: input,
                inputRoot: session.inputRoot,
                outputRoot: outputRoot,
                format: format
            )
        }
    }

    static func preview(session: Session, format: ExportFormat) {
        session.preview = destinations(session: session, format: format)
        session.failures = []
        session.progress = SessionProgress(
            index: 0,
            total: session.preview.count,
            fraction: 0,
            currentName: ""
        )
    }

    static func run(
        session: Session,
        settings: RenderSettings,
        metadata: MetadataDraft,
        dryRun: Bool
    ) async {
        session.resetCancel()
        session.isRunning = true
        session.failures = []
        if dryRun {
            preview(session: session, format: settings.format)
        }

        defer {
            session.isRunning = false
            session.progress.currentName = ""
            if session.progress.total > 0 {
                session.progress.index = session.progress.total
                session.progress.fraction = 1
            }
        }

        guard let outputRoot = session.outputRoot else {
            session.failures.append(
                JobFailure(path: URL(fileURLWithPath: "/"), message: "Elige una carpeta de salida.")
            )
            return
        }

        let jobs: [(input: URL, output: URL)] = session.tracks.map { input in
            (
                input,
                AudioIO.outputURL(
                    for: input,
                    inputRoot: session.inputRoot,
                    outputRoot: outputRoot,
                    format: settings.format
                )
            )
        }
        let overwrite = session.overwrite
        let total = jobs.count

        for (i, job) in jobs.enumerated() {
            if session.cancelRequested { break }

            session.progress = SessionProgress(
                index: i + 1,
                total: total,
                fraction: Double(i) / Double(max(total, 1)),
                currentName: job.input.lastPathComponent
            )

            if dryRun {
                continue
            }

            if !overwrite, FileManager.default.fileExists(atPath: job.output.path) {
                continue
            }

            do {
                let input = job.input
                let output = job.output
                try await Task.detached(priority: .userInitiated) {
                    try Engine.render(
                        input: input,
                        settings: settings,
                        output: output,
                        metadata: metadata
                    )
                }.value
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                session.failures.append(JobFailure(path: job.input, message: message))
            }
        }
    }
}
