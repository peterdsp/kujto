import Foundation

/// Derives sibling test files for the file the user is about to touch. Used by
/// the Studio inspector ("Tests to run") and by the CLI. Deterministic
/// heuristic, no source parsing yet: builds candidate test names from the
/// file's stem and any recognised architectural suffix, then walks the repo
/// for `.swift` files matching those names.
///
/// Examples
///   HomeReducer.swift  -> HomeReducerTests, HomeTests
///   PaymentClient.swift -> PaymentClientTests, PaymentTests
///   CheckoutFeature.swift -> CheckoutFeatureTests, CheckoutTests
public enum RelatedTests {

    /// Suffixes we recognise so `HomeReducer` maps to `Home` as well.
    private static let strippableSuffixes = ["Reducer", "Feature", "Store", "View", "Screen",
                                             "Client", "Service", "Repository", "Coordinator",
                                             "ViewModel", "Presenter", "Controller"]

    public static func testsFor(file relativePath: String, in root: URL) -> [String] {
        let stem = (relativePath as NSString).lastPathComponent
        let base = (stem as NSString).deletingPathExtension
        let candidates = candidateNames(for: base)
        if candidates.isEmpty { return [] }

        let rootPath = root.resolvingSymlinksInPath().path
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }

        var out: [String] = []
        for case let url as URL in walker {
            if RepoWalk.isHeavyDirectory(url) { walker.skipDescendants(); continue }
            guard url.pathExtension == "swift" else { continue }
            let path = url.resolvingSymlinksInPath().path
            let filename = (path as NSString).lastPathComponent
            let name = (filename as NSString).deletingPathExtension
            guard candidates.contains(name) else { continue }
            let rel = path.hasPrefix(rootPath + "/") ? String(path.dropFirst(rootPath.count + 1)) : path
            if rel == relativePath { continue }  // never report self
            out.append(rel)
            if out.count > 10 { break }
        }
        return out.sorted()
    }

    /// Test-name candidates for a stem: the stem itself with a `Tests`/`Spec`
    /// suffix, and for known architectural suffixes, the base name too.
    static func candidateNames(for stem: String) -> Set<String> {
        var out: Set<String> = [
            "\(stem)Tests",
            "\(stem)Spec",
            "\(stem)UITests",
            "\(stem)IntegrationTests"
        ]
        for suffix in strippableSuffixes where stem.hasSuffix(suffix) && stem != suffix {
            let base = String(stem.dropLast(suffix.count))
            out.insert("\(base)Tests")
            out.insert("\(base)Spec")
        }
        return out
    }
}
