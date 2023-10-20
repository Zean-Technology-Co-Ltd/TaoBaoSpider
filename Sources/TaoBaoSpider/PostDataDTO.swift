//
//  PostDataDTO.swift
//  WKWebViewDemo
//
//  Created by Alan Ge on 2023/7/9.
//

import Foundation
import Moya

class PostDataDTO: NSObject {
    static var shared = PostDataDTO()
    static let userID = UserDefaults.standard.string(forKey: TaoBao_UserID)
    static let tenantID = UserDefaults.standard.string(forKey: TaoBao_TenantID)
    static let currentUserId = "\(userID ?? "")_\(tenantID ?? "")"
    private let provider = MoyaProvider<TBApi>()
    
    func postData(path: String, content: String, type: String? = nil, month: String? = nil) {
        var parameters = ["currentUserId": PostDataDTO.currentUserId,
                          "body": content]
        if let type = type {
            parameters["type"] = type
        }
        if let month = month {
            parameters["month"] = month
        }
        postData(path: path, parameters: parameters)
    }
    
    func postData(path: String, parameters: [String: Any]) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let `self` = self else { return }
            self.provider
                .request(.uploadData(path: path, parameters: parameters), completion: { result in
                    do {
                        let response = try result.get()
                        let value = try response.mapJSON()
                        print(value)
                        print("path:\(path) \n parameters:\(parameters)")
                    } catch {
                        let printableError = error as CustomStringConvertible
                        print("error:\(printableError.description)")
                    }
                })
        }
    }
    
    func DataToObject(_ data: Data) -> Any? {
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
            return object
        } catch {
            print(error)
        }
        return nil
    }
}

struct TBResponseModel: Codable {}


enum TBApi {
    case uploadData(path: String, parameters: [String: Any])
}

extension TBApi: TargetType {
    
    var baseURL: URL {
        return URL(string: "http://106.13.235.245/")!
    }
    
    var shouldAuthorize: Bool {
        return true
    }
    
    var method: Moya.Method {
        return .post
    }
    
    var sampleData: Data {
        return Data()
    }

    var task: Task {
        return .requestParameters(parameters: parameters!, encoding: JSONEncoding())
    }
    
    var headers: [String : String]? {
        return nil
    }
    
    var path: String{
        switch self {
        case let .uploadData(path, _):
            return "\(path)"
        }
    }
    
    var parameters: [String: Any]?{
        switch self {
        case let .uploadData(_, parameters):
            return parameters
        }
    }
    
}
