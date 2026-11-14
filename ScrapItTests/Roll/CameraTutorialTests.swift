import Foundation
import Testing
@testable import ScrapIt

/// The camera tutorial after "Let's Try It" (change 152).
@MainActor
struct CameraTutorialTests {
    private func makeStore() -> TutorialPhotoStore {
        TutorialPhotoStore(directory: FileManager.default.temporaryDirectory
            .appending(path: "CameraTutorialTests-\(UUID().uuidString)", directoryHint: .isDirectory))
    }

    @Test func tipsComeInOrderThenTryItOutThenShooting() {
        let vm = CameraTutorialViewModel(photoStore: makeStore())
        #expect(vm.shotsRemaining == 2)
        var controls: [CameraControl] = []
        while let tip = vm.currentTip {
            controls.append(tip.control)
            #expect(!vm.areControlsEnabled)
            vm.advance()
        }
        #expect(controls == [.shotsLeft, .zoom, .flash, .flip, .shutter])
        #expect(vm.step == .tryItOut)
        #expect(!vm.areControlsEnabled)
        vm.advance()
        #expect(vm.step == .shooting)
        #expect(vm.areControlsEnabled)
    }

    @Test func theShutterDoesNothingDuringTheTips() async {
        let vm = CameraTutorialViewModel(photoStore: makeStore())
        await vm.shutterTapped()
        #expect(vm.shotsRemaining == 2)
        #expect(vm.step == .tip(0))
    }

    @Test func twoShotsFinishTheTutorial() async {
        let vm = CameraTutorialViewModel(photoStore: makeStore())
        for _ in 0...CameraTutorialViewModel.tips.count { vm.advance() }
        #expect(vm.step == .shooting)
        await vm.shutterTapped()
        #expect(vm.shotsRemaining == 1)
        #expect(vm.step == .shooting)
        await vm.shutterTapped()
        #expect(vm.shotsRemaining == 0)
        #expect(vm.step == .finished)
        await vm.shutterTapped()
        #expect(vm.shotsRemaining == 0)
    }

    @Test func practicePhotosStayInTheTemporaryFolderAndTheNextTutorialClearsThem() {
        let store = makeStore()
        store.save(Data("one".utf8), index: 1)
        store.save(Data("two".utf8), index: 2)
        #expect(store.photoURLs.map(\.lastPathComponent) == ["Shot1.jpg", "Shot2.jpg"])
        #expect(store.directory.path.hasPrefix(FileManager.default.temporaryDirectory.path))
        _ = CameraTutorialViewModel(photoStore: store)
        #expect(store.photoURLs.isEmpty)
    }
}
