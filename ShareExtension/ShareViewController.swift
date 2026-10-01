import SwiftData
import SwiftUI
import UIKit

@MainActor @Observable
final class ShareModel {
    enum State { case saving, saved(String), failed(String) }
    var state = State.saving
}

struct ShareConfirmation: View {
    let model: ShareModel

    var body: some View {
        VStack(spacing: 10) {
            switch model.state {
            case .saving:
                ProgressView()
                Text("Saving…")
            case .saved(let what):
                Image(systemName: "checkmark.circle.fill").font(.system(size: 40)).foregroundStyle(.green)
                Text(what).font(.headline)
                Text("We'll remind you when you're free.").font(.footnote).foregroundStyle(.secondary)
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundStyle(.orange)
                Text(message).font(.headline).multilineTextAlignment(.center)
            }
        }
        .padding(28)
        .frame(width: 260)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Receives links, screenshots and text from the iOS share sheet and drops them in the queue.
final class ShareViewController: UIViewController {
    private let model = ShareModel()
    private let container = Store.makeContainer()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        let host = UIHostingController(rootView: ShareConfirmation(model: model))
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        Task { await save() }
    }

    private func save() async {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let caption = items.compactMap { $0.attributedContentText?.string }.first { !$0.isEmpty }
        let providers = items.flatMap { $0.attachments ?? [] }
        do {
            let saved = try await ShareIngest.save(providers: providers, caption: caption, into: container.mainContext)
            model.state = saved.map { .saved($0) } ?? .failed("Nothing to save here")
        } catch {
            model.state = .failed("Couldn't save that")
        }
        try? await Task.sleep(for: .seconds(1))
        extensionContext?.completeRequest(returningItems: nil)
    }
}
