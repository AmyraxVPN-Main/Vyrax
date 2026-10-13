import XCTest
import WebKit
@testable import Vyrax

@MainActor final class HostTests:XCTestCase {
    func testSecureStoreAndNativeCore() async throws {
        let fixture:[String:Any]=["profiles":[["id":"test","password":"PRIVATE_TEST_VALUE"]],"settings":["mode":"tun"]]
        try SharedStore.save(fixture,name:"test")
        let bytes=try Data(contentsOf:SharedStore.folder().appendingPathComponent("test.encrypted"))
        XCTAssertFalse(String(data:bytes,encoding:.utf8)?.contains("PRIVATE_TEST_VALUE") ?? false)
        let loaded=try SharedStore.load(name:"test")
        XCTAssertEqual((loaded["profiles"] as? [[String:Any]])?.first?["id"] as? String,"test")
        XCTAssertThrowsError(try NativeCore.invoke("start",["outbounds":[["protocol":"invalid"]]]))
        let config:[String:Any]=["log":["loglevel":"none"],"outbounds":[["protocol":"freedom","tag":"direct"]]]
        _=try NativeCore.invoke("start",config)
        _=try NativeCore.invoke("stop")
    }
    func testRealWebKitMobileUIAndBridge() async throws {
        let host=WebController();let window=UIWindow(frame:UIScreen.main.bounds);window.rootViewController=host;window.makeKeyAndVisible()
        defer{window.isHidden=true}
        for _ in 0..<100 {
            try await Task.sleep(nanoseconds:100_000_000)
            if (try? await host.web.evaluateJavaScript("!!document.querySelector('.dial')")) as? Bool == true {break}
        }
        let platform=try await host.web.evaluateJavaScript("document.documentElement.dataset.platform") as? String
        XCTAssertEqual(platform,"ios")
        XCTAssertEqual(try await host.web.evaluateJavaScript("document.querySelectorAll('.bar-btn').length") as? Int,0)
        XCTAssertEqual(try await host.web.evaluateJavaScript("getComputedStyle(document.querySelector('.shell')).borderRadius") as? String,"0px")
        let result=try await host.web.callAsyncJavaScript("""
        return await new Promise(resolve => {
          const original=window.__vyraxNativeEvent;
          window.__vyraxNativeEvent = data => { if(data.id===901){window.__vyraxNativeEvent=original;resolve(data.result)} else original(data) };
          window.webkit.messageHandlers.vyrax.postMessage({id:901,action:'validateSettings',args:{mode:'proxy',proxyShare:true,mtu:1280}});
        });
        """,arguments:[:],in:nil,contentWorld:.page) as? [String:Any]
        XCTAssertEqual(result?["mode"] as? String,"tun");XCTAssertEqual(result?["proxyShare"] as? Bool,false)
        _=try await host.web.evaluateJavaScript("document.querySelectorAll('.tabs-row button')[2].click()")
        try await Task.sleep(nanoseconds:400_000_000)
        XCTAssertEqual(try await host.web.evaluateJavaScript("document.querySelectorAll('.prefs .seg').length") as? Int,0)
        XCTAssertFalse((try await host.web.evaluateJavaScript("document.querySelector('.prefs').innerText")) as? String == nil)
    }
}
