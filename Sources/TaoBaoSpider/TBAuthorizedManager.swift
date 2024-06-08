//
//  TBAuthorizedManager.swift
//  NiuNiuRent
//
//  Created by Q Z on 2023/6/16.
//  参考资料 https://cloud.tencent.com/developer/ask/sof/87370
// https://www.cnblogs.com/lxlx1798/articles/14259055.html
/**
    清除WKWebView的缓存
    在磁盘缓存上。
    WKWebsiteDataTypeDiskCache,
    
    html离线Web应用程序缓存。
    WKWebsiteDataTypeOfflineWebApplicationCache,
    
    内存缓存。
    WKWebsiteDataTypeMemoryCache,
    
    本地存储。
    WKWebsiteDataTypeLocalStorage,
    
    Cookies
    WKWebsiteDataTypeCookies,
    
    会话存储
    WKWebsiteDataTypeSessionStorage,
    
    IndexedDB数据库。
    WKWebsiteDataTypeIndexedDBDatabases,
    
    查询数据库。
    WKWebsiteDataTypeWebSQLDatabases
    */
import UIKit
import WebKit
import HUD
import NNToast

public enum TBAuthorizedType {
    case password
    case qrcode
    case smsCode
}
internal let TaoBao_TenantID = "TaoBao_TenantID"
internal let TaoBao_UserID = "TaoBao_UserID"
open class TBAuthorizedManager: UIView {
    private var callback: ((Bool)->Void)?
    private var trackBlock: (([String: String])->Void)?
    private var loginType: TBAuthorizedType = .qrcode
    private var wkUController: WKUserContentController?
    public var cookieArray: [HTTPCookie] = []
    public var storage: HTTPCookieStorage {
        let storage = HTTPCookieStorage.shared
        storage.cookieAcceptPolicy = .always
        return storage
    }
    
    public var webView: WKWebView?
    public var trackId = "\(UInt64(Date().timeIntervalSince1970 * 1_000))"
    public var actionType = "我的淘宝"
    public var getAddress = false
    public var zhifubao = true
    public var taobaoHttp = true
    public var aliIndex = false
    public var scanNum = 0
    public var toTbAuth = false
    public var isAuthored = false
    public var tbFootReloadCount = 0
    // 商户ID
    public var tenantID: String?
//    // 用户ID
    public var userID: String?
    
    public let getHtmlJS = "var url = window.location.href;" +
    "var body = document.getElementsByTagName('html')[0].outerHTML;" +
    "var data = {\"url\":url,\"responseText\":body};" +
    "window.webkit.messageHandlers.showHtml.postMessage(data);"
    private let myUA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
    // MARK: Lifecycle
    deinit {
        print("TaoBaoAuthorizedManager\(#file)" + "\(#function)")
        NotificationCenter.default.removeObserver(self)
    }
    
    public convenience init(loginType: TBAuthorizedType = .qrcode, 
                     tenantID: String,
                     userID: String,
                     callback: @escaping ((Bool)->Void),
                     trackBlock: @escaping ([String: String])->Void) {
        self.init()
        self.loginType = loginType
        self.tenantID = tenantID
        self.userID = userID
        self.callback = callback
        self.trackBlock = trackBlock
        
        UserDefaults.standard.setValue(tenantID, forKey: TaoBao_TenantID)
        UserDefaults.standard.setValue(userID, forKey: TaoBao_UserID)
        UserDefaults.standard.synchronize()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.nn_initViews()
        NotificationCenter.default.removeObserver(self)
        NotificationCenter
            .default
            .addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter
            .default
            .addObserver(self, selector: #selector(appDidEnterBackgroundNotification), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func appWillEnterForeground() {
        HUD.wait("授权中...")
    }
    
    @objc func appDidEnterBackgroundNotification() {
        HUD.dismiss()
    }
    
    private func nn_initViews (){
        // 移除所有注册的MessageHandler事件
        self.removeAllScriptMessageHandlers()
        // 手动释放所有的View以便稍后重新创建
        self.manualReleaseAllView()
        // 释放所有webView缓存并重新创建
        self.removeALLWebsiteDataStore()
    }
    
    private func addWebView (){
        let wkUController: WKUserContentController = WKUserContentController()
        wkUController.add(self, name: "ajaxDone")
        wkUController.add(self, name: "showHtml")
        wkUController.add(self, name: "upMyZfbInfo")
        wkUController.add(self, name: "tbAuthenticationName")
        wkUController.add(self, name: "trackTbUrl")
        self.wkUController = wkUController
        let config = WKWebViewConfiguration()
        config.userContentController = wkUController
        let view = WKWebView(frame: UIScreen.main.bounds, configuration: config)
        view.customUserAgent = myUA
        view.navigationDelegate = self
        self.addSubview(view)
        self.webView = view
    }
    
    private func initDatas() {
        let linkUrl = "https://login.taobao.com/"
        var request =  URLRequest(url: URL(string: linkUrl)!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        request.setValue("User-Agent", forHTTPHeaderField: myUA)
        self.webView?.load(request)
        if self.loginType == .qrcode {
            HUD.wait()
        }
    }

    // MARK: Event Response
    // MARK: Public Method
    public func updateAccount(account: String){
        if loginType != .password { return }
        let accountJs = "document.querySelector(\"#fm-login-id\").value = " + "'\(account)'"
        self.evaluateJavaScript(accountJs)
    }
    
    public func updatePassword(password: String){
        if loginType != .password { return }
        let passwordJs = "document.querySelector(\"#fm-login-password\").value = " + "'\(password)'"
        self.evaluateJavaScript(passwordJs)
    }
    
    public func loginWithPassword(){
        if loginType != .password { return }
        HUD.wait("授权中...")
        let loginJs = "document.querySelector(\"#login-form > div.fm-btn > button\").click()"
        self.evaluateJavaScript(loginJs)
    }
    
    public func updateMobile(mobile: String){
        if loginType != .smsCode { return }
        let mobileJs = "document.querySelector(\"#fm-sms-login-id\").value = " + mobile
        self.evaluateJavaScript(mobileJs)
    }
    
    public func updateSmsCode(smsCode: String){
        if loginType != .smsCode { return }
        let verificationCodeJs = "document.querySelector(\"#fm-smscode\").value = " + smsCode
        self.evaluateJavaScript(verificationCodeJs)
    }

    public func sendVerificationCode(){
        if loginType != .smsCode { return }
        let loginJs = "document.querySelector(\"#login-form > div.fm-field.fm-field-sms > div.send-btn > a\").click()"
        self.evaluateJavaScript(loginJs)
    }
    
    public func loginWithVerificationCode(){
        if loginType != .smsCode { return }
        HUD.wait("授权中...")
        let loginJs = "document.querySelector(\"#login-form > div.fm-btn > button\").click()"
        self.evaluateJavaScript(loginJs)
    }
    
    public func updateLoginType(type: TBAuthorizedType){
        self.loginType = type
        if type == .password {
            let loginJs = "document.querySelector(\"#login > div.login-content.nc-outer-box > div > div.login-blocks.login-switch-tab > a.password-login-tab-item\").click()"
            self.evaluateJavaScript(loginJs)
        } else if type == .smsCode{
            let loginJs = "document.querySelector(\"#login > div.login-content.nc-outer-box > div > div.login-blocks.login-switch-tab > a.sms-login-tab-item\").click()"
            self.evaluateJavaScript(loginJs)
        }
    }
    
    // MARK: Private Method
    // 释放所有webView缓存并重新创建
    private func removeALLWebsiteDataStore(){
        let store: WKWebsiteDataStore = WKWebsiteDataStore.default()
        let dataTypes: Set<String> = WKWebsiteDataStore.allWebsiteDataTypes()
        store.fetchDataRecords(ofTypes: dataTypes, completionHandler: { [weak self] (records: [WKWebsiteDataRecord]) in
            store.removeData(ofTypes: dataTypes, for: records, completionHandler: {})
            guard let `self` = self else { return }
            self.addWebView()
            self.initDatas()
        })
    }
    
    private func removeSomeWebsiteDataStore(){
        let websiteDataTypes = NSSet(array: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
        let date = NSDate(timeIntervalSince1970: 0)
        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes as! Set<String>, modifiedSince: date as Date, completionHandler:{ })
    }
    // 移除所有注册的MessageHandler事件
    private func removeAllScriptMessageHandlers() {
        guard let userContentController = self.wkUController else { return }
        if #available(iOS 14.0, *) {
            userContentController.removeAllScriptMessageHandlers()
        } else {
            userContentController.removeScriptMessageHandler(forName: "ajaxDone")
            userContentController.removeScriptMessageHandler(forName: "showHtml")
            userContentController.removeScriptMessageHandler(forName: "upMyZfbInfo")
            userContentController.removeScriptMessageHandler(forName: "tbAuthenticationName")
            userContentController.removeScriptMessageHandler(forName: "trackTbUrl")
        }
    }
    // 手动释放所有View
    private func manualReleaseAllView(){
        self.wkUController = nil
        self.webView = nil
    }
    
    // MARK: Set
    
    // MARK: Get
}

extension TBAuthorizedManager: WKScriptMessageHandler{
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "ajaxDone",
           let dic = message.body as? [String: Any],
           let body = dic["responseText"] as? String {
            ajaxDone(body: body)
        } else if message.name == "showHtml",
                  let dic = message.body as? [String: Any],
                  let body = dic["responseText"] as? String {
            let url = dic["url"] as? String
            showHtml(url: url, body: body)
        } else if message.name == "upMyZfbInfo",
                  let dic = message.body as? [String: Any] {
            let url = dic["url"] as? String
            let t1 = dic["t1"] as? String
            let t2 = dic["t2"] as? String
            let type = dic["type"] as? Int
            upMyZfbInfo(url: url, t1: t1 ?? "", t2: t2 ?? "", type: type ?? 0)
        } else if message.name == "tbAuthenticationName",
                  let dic = message.body as? [String: Any],
                  let name = dic["name"] as? String,
                  let idCard = dic["idCard"] as? String{
            let url = dic["url"] as? String
            tbAuthenticationName(url: url, name: name, idCard: idCard)
        } else if message.name == "trackTbUrl",
                  let dic = message.body as? [String: Any],
                  let html = dic["html"] as? String{
            let url = dic["url"] as? String
            trackTbUrl(url: url ?? "", html: html)
        }
    }
    
    func ajaxDone(body: String) {
        let content = body.toDictionary()
        if let content = content?["content"] as? [String: Any] {
            if let data = content["data"] as? [String: Any],
               let ck = data["ck"] as? String {
                let linkUrl = "taobao://login.taobao.com/qrcodeCheck.htm?lgToken=\(ck)&tbScanOpenType=Notification"
                guard let url = URL(string: linkUrl) else { return }
                HUD.wait("授权中...")
                self.toTbAuth = true
                UIApplication.shared.open(url)
            }
        }
    }
}

extension TBAuthorizedManager: WKNavigationDelegate{
  
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let absoluteString = webView.url?.absoluteString
        if loginType == .qrcode {
            self.clickTBQrcode(webView: webView)
        }
    
        print("webViewDidFinish:\(absoluteString ?? "")")
        // [步骤1]，扫码成功后，进入了淘宝首页
        DispatchQueue.global().async { [weak self] in
            if absoluteString?.hasPrefix("https://i.taobao.com/my_taobao.htm") == true {
                self?.actionType = "我的淘宝"
                if self?.getAddress == true {
                    self?.actionType = "跳转支付宝"
                    Thread.sleep(forTimeInterval: 0.1)
                    // 所有操作都完成后，进行跳转支付宝
                    let removeBlankJS = "var a = document.getElementsByTagName('a');for(var i=0;i<a.length;i++){a[i].setAttribute('target','_self');}"
                    
                    self?.evaluateJavaScript(removeBlankJS )
                    Thread.sleep(forTimeInterval: 0.5)
                    // [步骤5] 从淘宝，跳转到 支付宝
                    let gotoAliJS = "document.querySelector(\"#J_MyAlipayInfo > span > a\").click()"
                    self?.evaluateJavaScript(gotoAliJS)
                } else {
                    self?.getTbBasicsMsg(webView, absoluteString: absoluteString)
                    self?.toTbAuth = false
                }
            }
            
            if absoluteString?.hasPrefix("https://login.taobao.com/member/login_unusual.htm") == true {
                Toast.showInfo("请打开淘宝进行二次授权", clearTime: 5)
            }
                
            // 二次验证处理
            if self?.toTbAuth == true, absoluteString?.hasPrefix("https://www.taobao.com/") == true {
                self?.getTbBasicsMsg(webView, absoluteString: absoluteString)
                self?.toTbAuth = false
            }
            
            // 我的足迹
            if absoluteString?.hasPrefix("https://member1.taobao.com/member/fresh/deliver_address.htm") == true{
                self?.actionType = "收获地址"
                
                let addressJS = "var url = window.location.href;" +
                "var address = document.getElementsByClassName(\"next-table-body\")[0].outerHTML;" +
                "var data = {\"url\":url,\"responseText\":address};" +
                "window.webkit.messageHandlers.showHtml.postMessage(data);"
                Thread.sleep(forTimeInterval: 0.5)
                self?.evaluateJavaScript(addressJS)
                // [步骤3] 从 收货地址界面  跳转到   足迹界面
                self?.loadUrlStr("https://www.taobao.com/markets/footmark/tbfoot")
            }
            // 重新跳转到淘宝个人界面
            if absoluteString?.hasPrefix("https://www.taobao.com/markets/footmark/tbfoot") == true{
                self?.actionType = "我的足迹"
                
                let addressJS = "var url = window.location.href;" +
                "var address = document.getElementsByClassName('J_ModContainer')[1].outerHTML;" +
                "var data = {\"url\":url,\"responseText\":address};" +
                "window.webkit.messageHandlers.showHtml.postMessage(data);"
     
                self?.evaluateJavaScript(addressJS)
                // [步骤4] 重新跳转到淘宝个人界面
                self?.loadUrlStr("https://i.taobao.com/my_taobao.htm")
            }
            // 淘宝快捷登录
            if absoluteString?.hasPrefix("https://login.taobao.com/member/login.jhtml?redirectURL=") == true{
                self?.actionType = "快捷登录"
                
                let addressJS = "document.querySelector(\"#login > div.login-content.nc-outer-box > div > div.fm-btn > button\").click();"
                self?.evaluateJavaScript(addressJS)
            }
            
            /*====================== 支付宝信息 start ======================*/
            //商家平台
            if absoluteString?.hasPrefix("https://b.alipay.com/page/home") == true{
                self?.actionType = "商家平台首页"
                for idx in 1...10 {
                    print("商家平台首页\(idx)")
                    Thread.sleep(forTimeInterval: 0.5)
                    if idx <= 5 {
                        self?.loadUrlStr("https://shanghu.alipay.com/home/switchPersonal.htm")
                    } else {
                        self?.loadUrlStr("https://uemprod.alipay.com/home/switchPersonal.htm")
                    }
                }
            }
            //企业版
            if absoluteString?.hasPrefix("https://uemprod.alipay.com/user/associatedAccount/admin.htm") == true{
                self?.actionType = "企业版"
                print("企业版")
                let js = "document.querySelector(\"#J_header > div > div.welcome\").click()"
                self?.evaluateJavaScript(js)
            }
            // 支付宝信息
            if absoluteString?.hasPrefix("https://my.alipay.com/portal/i.htm") == true || absoluteString?.hasPrefix("https://personalweb.alipay.com/portal/i.htm") == true{
                self?.actionType = "进入支付宝成功"
                print("进入支付宝成功")
                HUD.clear()
                self?.callback?(true)
                /// 支付宝余额
                self?.getPageData(webView: webView, type: .yebPurchaseURL)
                Thread.sleep(forTimeInterval: 0.25)
                /// 阿里代扣
                self?.getPageData(webView: webView, type: .mdeductAndTokenURL)
                Thread.sleep(forTimeInterval: 0.25)
                /// 支付宝实名基本信息
                self?.getPageData(webView: webView, type: .aliAccountIndexURL)
                Thread.sleep(forTimeInterval: 0.25)
                /// 支付宝消息列表
                self?.getPageData(webView: webView, type: .messageURL)
                /// 回收站
                self?.getTrashPageList(webView: webView, absoluteString: absoluteString)
                Thread.sleep(forTimeInterval: 0.5)
                /// 应用授权
                self?.getAuthTokenManageList(webView: webView, absoluteString: absoluteString)
                Thread.sleep(forTimeInterval: 0.5)
                // [步骤6] 点击花呗余额
                
                // [步骤7] 获取用户绑卡列表
                self?.loadUrlStr("https://zht.alipay.com/asset/bankList.htm")
            }
            // 绑卡信息
            if absoluteString?.hasPrefix("https://zht.alipay.com/asset/bankList.htm") == true {
                self?.actionType = "绑卡信息"
                print("绑卡信息")
                Thread.sleep(forTimeInterval: 0.5)
                let bankJS = "var url = window.location.href;" +
                "var body = document.getElementsByClassName(\"card-box-list\")[0].outerHTML;" +
                "var data = {\"url\":url,\"responseText\":body};" +
                "window.webkit.messageHandlers.showHtml.postMessage(data);"
                self?.evaluateJavaScript(bankJS)
                self?.loadUrlStr("https://loan.mybank.cn/loan/profile.htm")
            }
            
            /*====================== 网商信息 start ======================*/
            // 网商登录
            if absoluteString?.hasPrefix("https://login.mybank.cn/login/loginhome.htm") == true{
                self?.actionType = "网商登录"
                print("网商登录")
                
                let WSMsg = "document.getElementsByClassName(\"userName___1vTUS\")[0].getElementsByTagName(\"span\")[0].click();\n" +
                "setTimeout(function () {\n" +
                "\tdocument.getElementsByClassName(\"logoLoad___78Syr\")[0].click();\n" +
                "},3000);"
                self?.evaluateJavaScript(WSMsg)
            }
            // 网商个人信息
            if absoluteString?.hasPrefix("https://loan.mybank.cn/loan/profile.htm") == true || absoluteString?.hasPrefix("https://loanweb.mybank.cn/loan.html") == true{
                self?.actionType = "网商贷"
                self?.evaluateJavaScript(self?.getHtmlJS)
                print("网商登录成功，进入个人信息")
                self?.loadUrlStr("https://loanweb.mybank.cn/repay/home.html")
            }
            // 网商还款信息
            if absoluteString?.hasPrefix("https://loanweb.mybank.cn/repay/home.html") == true{
                self?.actionType = "网商还款信息"
                
                self?.evaluateJavaScript(self?.getHtmlJS)
                print("网商个人信息，进入还款信息")
                self?.loadUrlStr("https://loanweb.mybank.cn/repay/record.html")
            }
            // 网商借款信息
            if absoluteString?.hasPrefix("https://loanweb.mybank.cn/repay/record.html") == true{
                self?.actionType = "网商借款信息"
                self?.evaluateJavaScript(self?.getHtmlJS)
            }
            /*====================== 支付宝错误信息处理 ======================*/
            /// 需要支付宝登录
            if absoluteString?.contains(find: "alipay.com/login/trustLoginResultDispatch.htm") == true || absoluteString?.contains(find: "https://authea179.alipay.com/error.htm?exceptionCode=TRUST_SECURITY_NEED_CHECK") == true{
                print("需要支付宝登录")
                self?.actionType = "需要支付宝登录"
                self?.webViewGoBack()
            }
            
            // 支付宝加载失败
            if absoluteString?.hasPrefix("https://auth.alipay.com/error") == true || absoluteString?.hasPrefix("https://render.alipay.com/p/s/alipay_site/wait") == true  {
                print("支付宝加载失败")
                self?.actionType = "支付宝加载失败"
                self?.webViewGoBack()
            }
            
            // 出现支付宝扫码
            if absoluteString?.hasPrefix("https://consumeprod.alipay.com/errorSecurity.htm") == true || absoluteString?.hasPrefix("https://consumeprod.alipay.com/record/checkSecurity.htm") == true  {
                guard let `self` = self else { return }
                print("出现支付宝扫码")
                self.actionType = "出现支付宝扫码"
                self.scanNum += 1
                if self.scanNum <= 3 {
                    Thread.sleep(forTimeInterval: 0.5)
                    self.webViewGoBack()
                } else {
                    self.actionType = "网商贷"
                    self.loadUrlStr("https://loan.mybank.cn/loan/profile.htm")
                }
            }
            
            if absoluteString?.hasPrefix("https://authstl.alipay.com/login/trustLoginResultDispatch.htm") == true{
                self?.actionType = "需要点击蓝色按钮"
                for idx in 1...10 {
                    print("蓝色按钮\(idx)")
                    let gotoAliJS = "document.getElementById(\"J-submit-cert-check\").click()"
                    self?.evaluateJavaScript(gotoAliJS)
                    Thread.sleep(forTimeInterval: 0.5)
                    if idx == 10 {
                        self?.trackTbUrl(url: "https://authstl.alipay.com/login/trustLoginResultDispatch.htm", html: "document.getElementById(\"J-submit-cert-check\").click()")
                        self?.webViewGoBack()
                    }
                }
            }
            
            // 若未开通余额宝，直接获取阿里基本信息
            if absoluteString?.contains(find: "https://yebprod.alipay.com/yeb/showContract.htm") == true {
                self?.loadUrlStr("https://custweb.alipay.com/account/index.htm")
            }
            
            self?.getTBHtml()
        }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(WKNavigationActionPolicy.allow)
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.actionType = "错误日志"
        trackTbUrl(url: webView.url?.absoluteString ?? "", html: error.localizedDescription)
    }
    
    public func trackTbUrl(url: String, html: String){
        DispatchQueue.global().async { [weak self] in
            guard let `self` = self else { return }
            let property = ["html": html,
                            "url": url,
                            "msg": self.actionType,
                            "trackId": self.trackId,
                            "userId": "\(self.userID ?? "")_\(self.tenantID ?? "")"
            ]
            self.trackBlock?(property)
        }
    }
    
    private func getTbBasicsMsg(_ webView: WKWebView, absoluteString: String?){
        DispatchQueue.main.async { [weak self] in
            self?.isAuthored = true
            // 协议获取淘宝个人信息
            self?.getTBMemberInfoAndRealName(webView: webView, absoluteString: absoluteString)
            // 协议获取订单信息
            self?.getOrders(webView: webView, absoluteString: absoluteString)
            // [步骤2] 跳转到收货地址信息
            self?.getAddress(webView: webView, absoluteString: absoluteString)
        }
    }
}

extension String {
    func toDictionary() -> Dictionary<String, AnyObject>? {
       if let data = self.data(using: String.Encoding.utf8) {
           do {
               return try JSONSerialization.jsonObject(with: data, options: []) as?  Dictionary<String, AnyObject>
           } catch let error as NSError {
               print(error)
           }
       }
       return nil
   }
}
