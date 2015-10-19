import XCTest
@testable import ExpressiveFoundation

class MyEmitter: EmitterType {
    let _listenerStorage = ListenerStorage()

    struct DidChange: EventType {
        let newValue: Int
    }

    var value: Int = 1

    func change() {
        ++value
        emit(DidChange(newValue: value))
    }

}

class ObservationTests: XCTestCase {

    func testEventObservingForInstance() {
        let e1 = expectationWithDescription("Instance")

        let me = MyEmitter()
        var o = Observation()

        o.on(MyEmitter.DidChange.self, from: me) { (sender, event) in
            XCTAssertEqual(event.newValue, 2)
            e1.fulfill()
        }

        me.change()

        waitForExpectationsWithTimeout(0.1, handler: nil)
    }

}
