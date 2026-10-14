import SwiftUI
import UncorkCore
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            if model.rosettaMissing {
                RosettaBanner(model: model)
            }
            RuntimeStatus(model: model)
            dropZone
            RecentList(model: model)
        }
        .padding(20)
        .task { await model.start() }
        .fileImporter(isPresented: $model.isPickingFile, allowedContentTypes: Self.programTypes, allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { model.open(urls) }
        }
        .alert("Uncork", isPresented: Binding(get: { model.alertMessage != nil }, set: { if !$0 { model.alertMessage = nil } })) {
            Button("OK") { model.alertMessage = nil }
        } message: {
            Text(model.alertMessage ?? "")
        }
    }

    private static let programTypes: [UTType] = [.exe] + [UTType(filenameExtension: "msi")].compactMap { $0 }

    private var dropZone: some View {
        VStack(spacing: 12) {
            UncorkMark(isOpen: model.isDropTargeted)
                .frame(height: 80)
                .foregroundStyle(model.isDropTargeted ? Color.accentColor : .secondary)
            Text("Drop a Windows program here")
                .font(.title3.weight(.medium))
            Text(".exe or .msi")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Choose File…") { model.isPickingFile = true }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundStyle(model.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.4))
        )
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(model.isDropTargeted ? Color.accentColor.opacity(0.08) : .clear)
        )
        .dropDestination(for: URL.self) { urls, _ in
            model.open(urls)
            return true
        } isTargeted: { model.isDropTargeted = $0 }
    }
}

private struct RosettaBanner: View {
    let model: AppModel

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text("Windows programs need Rosetta on this Mac.")
            Spacer()
            if model.rosettaInstalling {
                ProgressView().controlSize(.small)
            } else {
                Button("Install Rosetta") { Task { await model.installRosetta() } }
            }
        }
        .padding(10)
        .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct RuntimeStatus: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            switch model.runtimeState {
            case .checking:
                ProgressView().controlSize(.small)
                Text("Checking…").foregroundStyle(.secondary)
            case .missing:
                Image(systemName: "arrow.down.circle")
                Text("Wine isn't set up yet (about 185 MB). It downloads the first time you open a program.")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Set Up Now") { Task { await model.installRuntime() } }
            case .installing(let phase):
                installing(phase)
            case .ready(let runtime):
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Wine \(runtime.version) ready").foregroundStyle(.secondary)
            case .failed(let message):
                Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                Text(message).foregroundStyle(.secondary)
                Spacer()
                Button("Retry") { Task { await model.installRuntime() } }
            }
            Spacer(minLength: 0)
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func installing(_ phase: InstallPhase) -> some View {
        switch phase {
        case .resolving:
            ProgressView().controlSize(.small)
            Text("Finding the latest Wine…")
        case .downloading(let fraction):
            Text("Downloading Wine")
            if let fraction {
                ProgressView(value: fraction).frame(maxWidth: 200)
                Text(fraction, format: .percent.precision(.fractionLength(0))).monospacedDigit()
            } else {
                ProgressView().controlSize(.small)
            }
        case .verifying:
            ProgressView().controlSize(.small)
            Text("Verifying download…")
        case .extracting:
            ProgressView().controlSize(.small)
            Text("Unpacking…")
        }
    }
}

private struct RecentList: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent").font(.headline)
            if model.recent.isEmpty {
                Text("Programs you open will show up here.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.recent) { record in
                    RecentRow(model: model, record: record)
                }
                .listStyle(.inset)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

private struct RecentRow: View {
    let model: AppModel
    let record: PrefixRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.displayName).fontWeight(.medium)
                Text(record.programPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            status
            Button("Run") { model.open([record.programURL]) }
                .disabled(model.runStates[record.id] == .running)
            Menu {
                Button("Show Log") { model.revealLog(of: record) }
                Button("Show Wine Prefix in Finder") { model.revealPrefix(of: record) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var status: some View {
        switch model.runStates[record.id] {
        case .running:
            Label("Running", systemImage: "circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.caption)
                .foregroundStyle(.green)
        case .exited(let code) where code != 0:
            Text("Exited (\(code))")
                .font(.caption)
                .foregroundStyle(.red)
        default:
            EmptyView()
        }
    }
}
