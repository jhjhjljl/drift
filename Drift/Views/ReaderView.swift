import PDFKit
import SwiftUI

private enum ReaderPaging {
    static let tapMovementThreshold: CGFloat = 15
    static let commitDistanceFraction: CGFloat = 0.28
    static let commitVelocity: CGFloat = 450
    static let rubberBandFactor: CGFloat = 0.35
}

struct ReaderView: View {
    @Environment(AppModel.self) private var appModel

    let book: Book

    @State private var session: ReaderSession?
    @State private var virtualIndex = 0
    @State private var showOverlay = false
    @State private var overlayTask: Task<Void, Never>?
    @State private var viewportSize: CGSize = .zero
    @State private var loadFailed = false
    @State private var loadedForSize: CGSize = .zero
    @State private var loadTask: Task<Void, Never>?
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var gestureStartOverlayVisible = false
    /// Saved reading position we're opening to; reader appears once this screen is paginated.
    @State private var openTargetIndex = 0

    private var canShowReader: Bool {
        guard let session else { return false }
        return session.isPageReady(at: openTargetIndex)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ReaderTheme.background.ignoresSafeArea()

                if loadFailed {
                    ReaderLoadFailedView(
                        title: book.displayTitle,
                        onLibrary: { appModel.closeReader() }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let session, canShowReader {
                    pagingSurface(session: session, size: proxy.size)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Opening…")
                            .font(.subheadline)
                            .foregroundStyle(ReaderTheme.text.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if showOverlay, !loadFailed {
                    ReaderOverlay(
                        title: book.displayTitle,
                        positionLabel: positionLabel(for: session),
                        isFixedPage: isFixedPage,
                        onLibrary: {
                            hideOverlay()
                            appModel.closeReader()
                        }
                    )
                    .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .gesture(pageDragGesture(session: session, pageHeight: proxy.size.height))
            .onAppear {
                scheduleLoad(size: proxy.size)
            }
            .onChange(of: proxy.size) { _, newSize in
                scheduleLoad(size: newSize)
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onDisappear {
            loadTask?.cancel()
            if let session, session.isReady {
                persistPosition(session: session)
            }
        }
    }

    @ViewBuilder
    private func pagingSurface(session: ReaderSession, size: CGSize) -> some View {
        let pageHeight = size.height

        ZStack {
            if virtualIndex > 0 {
                pageView(session: session, index: virtualIndex - 1, size: size)
                    .offset(y: -pageHeight + dragOffset)
            }

            pageView(session: session, index: virtualIndex, size: size)
                .offset(y: dragOffset)

            if canTurnForward(session: session) {
                pageView(session: session, index: virtualIndex + 1, size: size)
                    .offset(y: pageHeight + dragOffset)
            }
        }
        .frame(width: size.width, height: pageHeight)
        .clipped()
    }

    @ViewBuilder
    private func pageView(session: ReaderSession, index: Int, size: CGSize) -> some View {
        Group {
            if let screen = session.screen(at: index) {
                switch screen {
                case .reflow:
                    ReflowTextPage(
                        text: session.reflowText(for: screen),
                        contentSize: ReaderTheme.contentSize(for: size)
                    )
                case let .fixed(pdfIndex):
                    FixedPDFPageView(page: session.fixedPage(at: pdfIndex))
                }
            } else {
                Color.clear
            }
        }
        .frame(
            width: ReaderTheme.contentSize(for: size).width,
            height: ReaderTheme.contentSize(for: size).height,
            alignment: .topLeading
        )
        .padding(.horizontal, ReaderTheme.horizontalPadding)
        .padding(.vertical, ReaderTheme.verticalPadding)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
    }

    private var isFixedPage: Bool {
        guard let session, let screen = session.screen(at: virtualIndex) else { return false }
        if case .fixed = screen { return true }
        return false
    }

    private func positionLabel(for session: ReaderSession?) -> String? {
        guard let session else { return nil }
        return ReaderPositionLabel.text(
            currentIndex: virtualIndex,
            totalScreens: session.totalScreens,
            isComplete: session.isComplete
        )
    }

    private func pageDragGesture(session: ReaderSession?, pageHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !loadFailed, let session, session.isReady else { return }
                if !isDragging {
                    isDragging = true
                    gestureStartOverlayVisible = showOverlay
                }
                dragOffset = clampedDragOffset(
                    value.translation.height,
                    session: session,
                    pageHeight: pageHeight
                )
            }
            .onEnded { value in
                isDragging = false
                guard !loadFailed, let session, session.isReady else { return }
                handleDragEnd(value: value, session: session, pageHeight: pageHeight)
            }
    }

    private func clampedDragOffset(
        _ raw: CGFloat,
        session: ReaderSession,
        pageHeight: CGFloat
    ) -> CGFloat {
        let canPrev = virtualIndex > 0
        let canNext = canTurnForward(session: session)

        if raw > 0, !canPrev {
            return rubberBand(raw)
        }
        if raw < 0, !canNext {
            return -rubberBand(-raw)
        }
        return raw
    }

    private func rubberBand(_ distance: CGFloat) -> CGFloat {
        distance * ReaderPaging.rubberBandFactor
    }

    private func canTurnForward(session: ReaderSession) -> Bool {
        let next = virtualIndex + 1
        return next < session.totalScreens && session.isPageReady(at: next)
    }

    private func handleDragEnd(value: DragGesture.Value, session: ReaderSession, pageHeight: CGFloat) {
        let translation = value.translation.height
        let velocity = value.velocity.height

        if isStrictTap(translation: value.translation, velocity: value.velocity) {
            snapBack()
            presentOverlay()
            return
        }

        if gestureStartOverlayVisible {
            hideOverlay()
            snapBack()
            return
        }

        let commitDistance = pageHeight * ReaderPaging.commitDistanceFraction
        let wantsNext = translation < -commitDistance || velocity < -ReaderPaging.commitVelocity
        let wantsPrev = translation > commitDistance || velocity > ReaderPaging.commitVelocity

        if wantsNext, canTurnForward(session: session) {
            commitPage(forward: true, session: session, pageHeight: pageHeight)
        } else if wantsPrev, virtualIndex > 0 {
            commitPage(forward: false, session: session, pageHeight: pageHeight)
        } else {
            snapBack()
        }
    }

    private func isStrictTap(translation: CGSize, velocity: CGSize) -> Bool {
        let movement = hypot(translation.width, translation.height)
        let speed = hypot(velocity.width, velocity.height)
        return movement < ReaderPaging.tapMovementThreshold && speed < ReaderPaging.commitVelocity
    }

    private func snapBack() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            dragOffset = 0
        }
    }

    private func commitPage(forward: Bool, session: ReaderSession, pageHeight: CGFloat) {
        hideOverlay()
        let target = forward ? -pageHeight : pageHeight
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            dragOffset = target
        }

        let nextIndex = forward ? virtualIndex + 1 : virtualIndex - 1
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard nextIndex >= 0, nextIndex < session.totalScreens else {
                dragOffset = 0
                return
            }
            virtualIndex = nextIndex
            dragOffset = 0
            persistPosition(session: session)
        }
    }

    private func scheduleLoad(size: CGSize) {
        guard size.width > 50, size.height > 50 else { return }
        guard size != loadedForSize || session == nil else { return }

        loadTask?.cancel()
        loadTask = Task {
            await loadSession(size: size)
        }
    }

    private func loadSession(size: CGSize) async {
        #if DEBUG
        OpenDiagnostics.beginOpen()
        let openStart = CFAbsoluteTimeGetCurrent()
        #endif

        viewportSize = size
        loadFailed = false
        dragOffset = 0

        guard appModel.library.hasPDF(for: book) else {
            session = nil
            loadFailed = true
            return
        }

        loadedForSize = size

        do {
            #if DEBUG
            let pipelineStart = CFAbsoluteTimeGetCurrent()
            #endif
            let prepared = try await BookOpenPipeline.prepare(
                book: book,
                library: appModel.library
            )
            openTargetIndex = prepared.openTargetIndex
            virtualIndex = openTargetIndex
            session = prepared.session

            #if DEBUG
            let paginationStart = CFAbsoluteTimeGetCurrent()
            #endif
            let loaded = await BookOpenPipeline.loadPages(prepared, viewportSize: size)
            #if DEBUG
            OpenDiagnostics.log("pagination (total)", ms: OpenDiagnostics.elapsed(since: paginationStart))
            OpenDiagnostics.log("open (total)", ms: OpenDiagnostics.elapsed(since: pipelineStart))
            #endif

            guard !Task.isCancelled else {
                session = nil
                return
            }

            guard loaded else {
                session = nil
                loadFailed = true
                return
            }

            virtualIndex = BookOpenPipeline.clampedIndex(openTargetIndex, session: prepared.session)
            dragOffset = 0
        } catch {
            session = nil
            loadFailed = true
        }
    }

    private func presentOverlay() {
        withAnimation(.easeOut(duration: 0.15)) {
            showOverlay = true
        }
        overlayTask?.cancel()
        overlayTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    showOverlay = false
                }
            }
        }
    }

    private func hideOverlay() {
        overlayTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) {
            showOverlay = false
        }
    }

    private func persistPosition(session: ReaderSession) {
        let position = ReadingPosition(
            virtualPageIndex: virtualIndex,
            progress: session.progress(forVirtualIndex: virtualIndex)
        )
        appModel.library.savePosition(position, for: book.id)
        appModel.library.lastOpenedBookID = book.id
    }
}

private struct ReaderLoadFailedView: View {
    let title: String
    let onLibrary: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Couldn’t open “\(title)”")
                .font(.headline)
                .foregroundStyle(ReaderTheme.text)
                .multilineTextAlignment(.center)

            Text("The PDF may be missing or unreadable.")
                .font(.subheadline)
                .foregroundStyle(ReaderTheme.text.opacity(0.7))
                .multilineTextAlignment(.center)

            Button("Back to Library", action: onLibrary)
                .font(.body.weight(.semibold))
                .foregroundStyle(ReaderTheme.text)
        }
        .padding(24)
    }
}

private struct ReaderOverlay: View {
    let title: String
    let positionLabel: String?
    let isFixedPage: Bool
    let onLibrary: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ReaderTheme.text.opacity(0.85))
                .lineLimit(1)

            if let positionLabel {
                Text(positionLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ReaderTheme.text.opacity(0.65))
            }

            if isFixedPage {
                Text("Original page")
                    .font(.caption)
                    .foregroundStyle(ReaderTheme.text.opacity(0.55))
            }

            Button("Library", action: onLibrary)
                .font(.body.weight(.semibold))
                .foregroundStyle(ReaderTheme.text)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
