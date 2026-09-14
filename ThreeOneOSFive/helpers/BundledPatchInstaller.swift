import Foundation

@MainActor
extension PatchProjectStore {
    func importBundledPatchesIfNeeded() {
        let marker = "moon.place.bundled-patches.v1"
        guard !UserDefaults.standard.bool(forKey: marker), !isBusy else { return }
        guard let urls = Bundle.main.urls(
            forResourcesWithExtension: "3105",
            subdirectory: "BundledPatches"
        ), !urls.isEmpty else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                while isBusy {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                guard let data = try? Data(contentsOf: url) else { continue }
                _ = importPackage(data: data)
            }
            while isBusy {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            UserDefaults.standard.set(true, forKey: marker)
        }
    }
}
