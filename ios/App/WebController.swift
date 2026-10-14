// SPDX-License-Identifier: MIT
import UIKit
import Darwin
import WebKit
import UniformTypeIdentifiers

@MainActor final class WebController:UIViewController,WKScriptMessageHandler,WKNavigationDelegate,UIDocumentPickerDelegate {
    private(set) var web:WKWebView!
    private let vpn=VPNController()
    private let free=FreeProvider()
    private var ready=false
    private var pickerReply:((Any?,Error?)->Void)?
    private var statsTimer:Timer?
    private var statsBusy=false
    private var previousUp=0,previousDown=0
    override var preferredStatusBarStyle:UIStatusBarStyle{.lightContent}
    override func viewDidLoad(){
        super.viewDidLoad()
        view.backgroundColor=UIColor(red:10/255,green:16/255,blue:18/255,alpha:1)
        let config=WKWebViewConfiguration()
        // Local custom schemes do not consistently expose secure-context-only
        // randomUUID on all supported WebKit versions. Keep UUIDs cryptographic.
        config.userContentController.addUserScript(WKUserScript(source:"""
        if (!crypto.randomUUID) Object.defineProperty(crypto, 'randomUUID', { value() {
          const b = crypto.getRandomValues(new Uint8Array(16));b[6]=(b[6]&15)|64;b[8]=(b[8]&63)|128;
          const h=Array.from(b,v=>v.toString(16).padStart(2,'0'));
          return h.slice(0,4).join('')+'-'+h.slice(4,6).join('')+'-'+h.slice(6,8).join('')+'-'+h.slice(8,10).join('')+'-'+h.slice(10).join('');
        }});
        """,injectionTime:.atDocumentStart,forMainFrameOnly:true))
        config.setURLSchemeHandler(LocalAssets(),forURLScheme:"vyrax")
        config.userContentController.add(self,name:"vyrax")
        web=WKWebView(frame:.zero,configuration:config)
        web.isOpaque=false;web.backgroundColor=view.backgroundColor
        web.scrollView.isScrollEnabled=false;web.scrollView.contentInsetAdjustmentBehavior = .never
        web.navigationDelegate=self;web.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(web)
        NSLayoutConstraint.activate([web.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),web.leadingAnchor.constraint(equalTo:view.leadingAnchor),web.trailingAnchor.constraint(equalTo:view.trailingAnchor),web.bottomAnchor.constraint(equalTo:view.keyboardLayoutGuide.topAnchor)])
        web.load(URLRequest(url:URL(string:"vyrax://app/index.html")!))
        vpn.changed={ [weak self] in Task{@MainActor in await self?.stateEvent()} }
        NotificationCenter.default.addObserver(self,selector:#selector(resume),name:UIApplication.didBecomeActiveNotification,object:nil)
        NotificationCenter.default.addObserver(self,selector:#selector(pause),name:UIApplication.didEnterBackgroundNotification,object:nil)
    }
    @objc private func resume(){
        statsTimer?.invalidate()
        statsTimer=Timer.scheduledTimer(withTimeInterval:1,repeats:true){[weak self] _ in Task{@MainActor in await self?.tick()} }
        Task{await stateEvent()}
    }
    @objc private func pause(){statsTimer?.invalidate();statsTimer=nil}
    func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!){ready=true;resume()}
    func webView(_ webView:WKWebView,decidePolicyFor navigationAction:WKNavigationAction,decisionHandler:@escaping(WKNavigationActionPolicy)->Void){
        let u=navigationAction.request.url
        decisionHandler(u?.scheme=="vyrax" && u?.host=="app" ? .allow:.cancel)
    }
    func userContentController(_ controller:WKUserContentController,didReceive message:WKScriptMessage){
        guard message.frameInfo.isMainFrame,message.frameInfo.request.url?.scheme=="vyrax",message.frameInfo.request.url?.host=="app",
              let body=message.body as? [String:Any],let id=body["id"] as? Int,let action=body["action"] as? String,
              let bytes=try? JSONSerialization.data(withJSONObject:body),bytes.count<=8*1024*1024 else{return}
        let args=body["args"] as? [String:Any] ?? [:]
        Task {
            do{let answer=try await dispatch(action,args);emit(["id":id,"result":answer])}
            catch{emit(["id":id,"error":code(error)])}
        }
    }
    func emit(_ value:[String:Any]){
        guard ready,let bytes=try? JSONSerialization.data(withJSONObject:value),let text=String(data:bytes,encoding:.utf8) else{return}
        web.evaluateJavaScript("window.__vyraxNativeEvent&&window.__vyraxNativeEvent(\(text))",completionHandler:nil)
    }
    private func stateEvent() async {
        guard ready,UIApplication.shared.applicationState != .background else{return}
        if var snapshot=try? await vpn.snapshot(){snapshot["event"]="state";snapshot["switched"]=true;emit(snapshot)}
    }
    private func tick() async {
        guard vpn.active,!statsBusy else{return};statsBusy=true;defer{statsBusy=false}
        guard let state=try? await vpn.snapshot() else{return}
        let up=state["up"] as? Int ?? 0,down=state["down"] as? Int ?? 0
        emit(["event":"stats","up":up,"down":down,"upRate":max(0,up-previousUp),"downRate":max(0,down-previousDown)])
        previousUp=up;previousDown=down
    }
    private func dispatch(_ action:String,_ args:[String:Any]) async throws -> Any {
        switch action {
        case "load":return try await Task.detached{try SharedStore.load()}.value
        case "save":
            var saved=args;saved["settings"]=try SharedStore.settings(args["settings"] as? [String:Any] ?? [:])
            let value=saved;try await Task.detached{try SharedStore.save(value)}.value;return true
        case "validateSettings":return try SharedStore.settings(args)
        case "freeCrypto":return try await Task.detached(priority:.userInitiated){try FreeCrypto.perform(args)}.value
        case "freeRequest":
            guard ["login","verify","oauth","servers"].contains(args["endpoint"] as? String ?? "") else{throw VyraxError.code("err.action")}
            if vpn.active{return try await vpn.message(action,args)}
            return try await Task.detached(priority:.utility){[free] in try free.request(args)}.value
        case "freeAccount","freeSave","freeSwitch","freeRemove","freeLogout":
            if vpn.active {
                let snapshot=try await vpn.snapshot()
                if (snapshot["profileId"] as? String ?? "").hasPrefix("firefox:"),["freeSave","freeSwitch","freeRemove","freeLogout"].contains(action) {
                    let local=try await vpn.message("freeAccount",["operation":"local"]) as? [String:Any] ?? [:]
                    if action != "freeRemove" || local["email"] as? String==args["email"] as? String {
                        var state=try await vpn.disconnect();state["event"]="state";emit(state)
                    }
                }
            }
            if vpn.active{return try await vpn.message(action,args)}
            return try await Task.detached(priority:.utility){[free] in try free.perform(action,args)}.value
        case "status":return try await vpn.snapshot()
        case "networkInfo":
            var first:UnsafeMutablePointer<ifaddrs>?
            guard getifaddrs(&first)==0,let start=first else{return ["addresses":[String]() ]}
            defer{freeifaddrs(first)}
            var addresses=[String](),cursor:UnsafeMutablePointer<ifaddrs>?=start
            while let item=cursor {
                let name=String(cString:item.pointee.ifa_name)
                if let address=item.pointee.ifa_addr,address.pointee.sa_family==UInt8(AF_INET),
                   item.pointee.ifa_flags & UInt32(IFF_UP) != 0,item.pointee.ifa_flags & UInt32(IFF_LOOPBACK)==0,
                   !name.hasPrefix("utun"),!name.hasPrefix("tun") {
                    var host=[CChar](repeating:0,count:Int(NI_MAXHOST))
                    if getnameinfo(address,socklen_t(address.pointee.sa_len),&host,socklen_t(host.count),nil,0,NI_NUMERICHOST)==0{addresses.append(String(cString:host))}
                }
                cursor=item.pointee.ifa_next
            }
            return ["addresses":addresses]
        case "ready":
            if args["config"] != nil,!vpn.active{return try await vpn.connect(args)}
            return try await vpn.snapshot()
        case "connect":
            emit(["event":"state","status":"connecting","stage":"stage.start"])
            do{let state=try await vpn.connect(args);var event=state;event["event"]="state";emit(event);return state}
            catch{emit(["event":"state","status":"disconnected"]);throw error}
        case "disconnect":let state=try await vpn.disconnect();var event=state;event["event"]="state";emit(event);return state
        case "select":let result=try await vpn.message(action,args);if var event=result as? [String:Any]{event["event"]="state";event["switched"]=true;emit(event)};return result
        case "delay","ping","subscription","checkUpdates":
            if vpn.active{return try await vpn.message(action,args)}
            let method=action=="delay" || action=="ping" ? "delay":"http"
            let payload:Any=method=="delay" ? args["outbound"] ?? [:] : action=="checkUpdates" ? ["url":"https://api.github.com/repos/AmyraxVPN-Main/Vyrax/releases/latest","update":true] : args
            return try await Task.detached(priority:.utility){[free] in
                let prepared=method=="delay" ? try free.prepare(payload as? [String:Any] ?? [:],single:true) : payload
                return try NativeCore.invoke(method,prepared)
            }.value
        case "geo":let hosts=args["hosts"] as? [String] ?? [];return try await Task.detached(priority:.utility){try Geo.lookup(hosts)}.value
        case "clipboard":return UIPasteboard.general.string ?? ""
        case "copy":guard let text=args["text"] as? String,text.utf8.count<=4*1024*1024 else{throw VyraxError.code("err.tooBig")};UIPasteboard.general.setItems([["public.utf8-plain-text":text]],options:[.localOnly:true,.expirationDate:Date().addingTimeInterval(300)]);return true
        case "file":return try await withCheckedThrowingContinuation{continuation in
            guard pickerReply==nil else{continuation.resume(throwing:VyraxError.code("err.busy"));return}
            pickerReply={value,error in if let error{continuation.resume(throwing:error)}else{continuation.resume(returning:value ?? NSNull())}}
            let picker=UIDocumentPickerViewController(forOpeningContentTypes:[.data],asCopy:true);picker.delegate=self;picker.allowsMultipleSelection=false;present(picker,animated:true)
        }
        case "openProjectLink":
            let urls=["source":"https://github.com/AmyraxVPN-Main/Vyrax","release":"https://github.com/AmyraxVPN-Main/Vyrax/releases/latest","telegram":"https://t.me/AmyraxVPN","firefoxAccount":"https://accounts.firefox.com/","firefoxHelp":"https://support.mozilla.org/en-US/kb/firefox-vpn"]
            guard let target=args["target"] as? String,let text=urls[target],let url=URL(string:text) else{throw VyraxError.code("err.action")}
            guard await UIApplication.shared.open(url) else{throw VyraxError.code("err.action")};return true
        case "language":return true
        default:throw VyraxError.code("err.action")
        }
    }
    func documentPickerWasCancelled(_ controller:UIDocumentPickerViewController){pickerReply?(nil,nil);pickerReply=nil}
    func documentPicker(_ controller:UIDocumentPickerViewController,didPickDocumentsAt urls:[URL]){
        let reply=pickerReply;pickerReply=nil
        guard let url=urls.first else{reply?(nil,nil);return}
        Task {
            do{
                let text=try await Task.detached{()->String in
                    let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}}
                    let size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? Int.max
                    guard size<=4*1024*1024 else{throw VyraxError.code("err.tooBig")}
                    let data=try Data(contentsOf:url);guard let text=String(data:data,encoding:.utf8) else{throw VyraxError.code("err.file")};return text
                }.value
                reply?(text,nil)
            }catch{reply?(nil,error)}
        }
    }
}

final class LocalAssets:NSObject,WKURLSchemeHandler {
    func webView(_ webView:WKWebView,start task:WKURLSchemeTask){
        guard let url=task.request.url,url.host=="app",let root=Bundle.main.resourceURL?.appendingPathComponent("ui") else{task.didFailWithError(VyraxError.code("err.file"));return}
        let relative=url.path.removingPercentEncoding ?? url.path
        let file=root.appendingPathComponent(String(relative.dropFirst())).standardizedFileURL
        guard file.path.hasPrefix(root.path+"/"),let bytes=try? Data(contentsOf:file) else{task.didFailWithError(VyraxError.code("err.file"));return}
        let mime=["html":"text/html","js":"text/javascript","css":"text/css","json":"application/json","svg":"image/svg+xml","png":"image/png","woff2":"font/woff2","woff":"font/woff"][file.pathExtension] ?? "application/octet-stream"
        task.didReceive(URLResponse(url:url,mimeType:mime,expectedContentLength:bytes.count,textEncodingName:mime.hasPrefix("text/") ? "utf-8":nil));task.didReceive(bytes);task.didFinish()
    }
    func webView(_ webView:WKWebView,stop task:WKURLSchemeTask){}
}
