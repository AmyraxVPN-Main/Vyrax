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
        let original=try SharedStore.load()
        defer{try? SharedStore.save(original)}
        let profile:[String:Any]=["id":"fixture-one","sourceId":"fixture-sub","name":"Germany fixture","host":"127.0.0.1","port":9,"protocol":"vless","uuid":"00000000-0000-4000-8000-000000000001","cc":"de"]
        try SharedStore.save(["profiles":[profile],"subscriptions":[["id":"fixture-sub","kind":"local","name":"iPhone test group"]],"selectedId":"fixture-one","activeSourceId":"fixture-sub","settings":["mode":"tun","preferencesVersion":1]])
        let host=WebController();let window=UIWindow(frame:UIScreen.main.bounds);window.rootViewController=host;window.makeKeyAndVisible()
        defer{window.isHidden=true}
        for _ in 0..<100 {
            try await Task.sleep(nanoseconds:100_000_000)
            if (try? await host.web.evaluateJavaScript("!!document.querySelector('.dial')")) as? Bool == true {break}
        }
        let platform=try await host.web.evaluateJavaScript("document.documentElement.dataset.platform") as? String
        XCTAssertEqual(platform,"ios")
        let uuid=try await host.web.evaluateJavaScript("crypto.randomUUID()") as? String
        XCTAssertNotNil(uuid.flatMap{UUID(uuidString:$0)})
        let controls=try await host.web.evaluateJavaScript("document.querySelectorAll('.bar-btn').length") as? Int
        let radius=try await host.web.evaluateJavaScript("getComputedStyle(document.querySelector('.shell')).borderRadius") as? String
        XCTAssertEqual(controls,0);XCTAssertEqual(radius,"0px")
        try await screenshot(host,"iphone-home")
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
        let modes=try await host.web.evaluateJavaScript("document.querySelectorAll('.prefs .seg').length") as? Int
        let text=try await host.web.evaluateJavaScript("document.querySelector('.prefs').innerText") as? String
        XCTAssertEqual(modes,0);XCTAssertNotNil(text)
        _=try await host.web.evaluateJavaScript("document.querySelector('.language-picker button[lang=fa]').click()")
        try await Task.sleep(nanoseconds:400_000_000)
        let direction=try await host.web.evaluateJavaScript("document.documentElement.dir") as? String
        XCTAssertEqual(direction,"rtl")
        try await screenshot(host,"iphone-settings-fa")
        _=try await host.web.evaluateJavaScript("document.querySelectorAll('.tabs-row button')[1].click()")
        try await Task.sleep(nanoseconds:400_000_000)
        let title=try await host.web.evaluateJavaScript("document.querySelector('.source-picker').innerText") as? String
        XCTAssertEqual(title,"iPhone test group")
        _=try await host.web.evaluateJavaScript("document.querySelector('.check-row').click();document.querySelector('.source-picker').click()")
        try await Task.sleep(nanoseconds:200_000_000)
        let disabled=try await host.web.evaluateJavaScript("document.querySelector('.subscriptions-sheet .sheet-close').disabled") as? Bool
        XCTAssertEqual(disabled,false)
        _=try await host.web.evaluateJavaScript("document.querySelector('.sub-actions button[aria-label*=Copy],.sub-actions button').click()")
        try await Task.sleep(nanoseconds:300_000_000)
        try await screenshot(host,"iphone-subscriptions-fa")
        _=try await host.web.evaluateJavaScript("document.querySelector('.subscriptions-sheet .sheet-close').click()")
        try await Task.sleep(nanoseconds:300_000_000)
        let closed=try await host.web.evaluateJavaScript("!document.querySelector('.subscriptions-sheet')") as? Bool
        XCTAssertEqual(closed,true)
        _=try await host.web.evaluateJavaScript("document.querySelectorAll('.tabs-row button')[0].click()")
        try await Task.sleep(nanoseconds:700_000_000)
        try await screenshot(host,"iphone-home-fa")
    }
    private func screenshot(_ host:WebController,_ name:String) async throws {
        let image:UIImage=try await withCheckedThrowingContinuation{continuation in
            host.web.takeSnapshot(with:nil){image,error in
                if let error{continuation.resume(throwing:error)}
                else if let image{continuation.resume(returning:image)}
                else{continuation.resume(throwing:VyraxError.code("err.core"))}
            }
        }
        let attachment=XCTAttachment(image:image);attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
    }
}
