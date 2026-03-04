import Foundation
import Observation

@Observable @MainActor final class TimelineViewModel {
    var moments: [Moment] = []
    var isLoading: Bool = false
    var isLoadingMore: Bool = false
    var error: AppError?

    private var currentPage: Int = 1
    private var hasNextPage: Bool = false
    private var isFetchingNextPage: Bool = false

    let store: SettingsStore
    private let api = MomentsAPIService()

    init(store: SettingsStore) {
        self.store = store
    }

    func loadInitialOrCached() async {
        if let cached = loadFromCache(), moments.isEmpty {
            moments = cached
        }
        isLoading = moments.isEmpty
        await fetchPage(1, replacing: true)
        isLoading = false
    }

    func refresh() async {
        await fetchPage(1, replacing: true)
    }

    func loadNextPageIfNeeded(currentItem: Moment) async {
        guard currentItem.id == moments.last?.id,
              hasNextPage,
              !isFetchingNextPage else { return }
        await fetchPage(currentPage + 1, replacing: false)
    }

    private func fetchPage(_ page: Int, replacing: Bool) async {
        guard store.isConfigured else { return }
        isFetchingNextPage = true
        if !replacing { isLoadingMore = true }

        do {
            let response = try await api.fetchTimeline(
                page: page,
                serverURL: store.serverURL,
                token: store.personalAccessToken
            )
            if replacing {
                moments = response.data
            } else {
                moments.append(contentsOf: response.data)
            }
            currentPage = page
            hasNextPage = response.links.next != nil
            if page == 1 {
                saveToCache(moments)
            }
            error = nil
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .networkError(error as? URLError ?? URLError(.unknown))
        }

        isFetchingNextPage = false
        isLoadingMore = false
    }

    func updateMoment(_ moment: Moment) {
        if let idx = moments.firstIndex(where: { $0.id == moment.id }) {
            moments[idx] = moment
        }
    }

    func removeMoment(withID id: Int) {
        moments.removeAll { $0.id == id }
    }

    func deleteMoment(_ moment: Moment) async {
        do {
            try await api.deleteMoment(id: moment.id, serverURL: store.serverURL, token: store.personalAccessToken)
            removeMoment(withID: moment.id)
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error as? URLError ?? URLError(.unknown))
        }
    }

    // MARK: - Cache

    private var cacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("timeline_page1.json")
    }

    private func saveToCache(_ moments: [Moment]) {
        guard let url = cacheURL else { return }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(moments) {
            try? data.write(to: url)
        }
    }

    private func loadFromCache() -> [Moment]? {
        guard let url = cacheURL,
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode([Moment].self, from: data)
    }
}
