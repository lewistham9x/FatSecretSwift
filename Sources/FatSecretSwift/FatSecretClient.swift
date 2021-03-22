import Foundation
import CryptoSwift

/**
 The HTTP error

 - invalidKey: Key provided does not exist or is invalid
 - invalidSignature: The signature generated does not match
 */

private enum HTTPError: LocalizedError {
    case invalidKey
    case invalidSignature
    case unknown

    public var errorDescription: String? {
        switch self {
        case .invalidKey:
            return NSLocalizedString("Error: Invalid key", comment: "error")
        case .invalidSignature:
            return NSLocalizedString("Error: Invalid signature", comment: "error")
        default:
            return NSLocalizedString("Error: Unknown", comment: "error")
        }
    }
}

/** HTTP Method: POST
 - URL: http://platform.fatsecret.com/rest/server.api
 */

/** List of all required request parameters

 - Parameter format: The return format type(JSON)
 - Parameter oauth_consumer_key: Users personal consumer key
 - Parameter oauth_signature_method: HMAC-SHA1
 - Parameter oauth_timestamp: Generated timestamp
 - Parameter oauth_nonce: Generate nonce
 - Parameter oauth_version: 1.0
 - Parameter oauth_signature: OAuth signature generated by encryption
 */

open class FatSecretClient {
    private var timestamp: String {
        get { return String(Int(Date().timeIntervalSince1970)) }
    }

    private var nonce: String {
        get {
            var string: String = ""
            let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            let char = Array(letters)

            for _ in 1...7 { string.append(char[Int(arc4random()) % char.count]) }

            return string
        }
    }

    /** Search
     - Description: Search for a food by name
     */
    public func searchFood(name: String, completion: @escaping (_ foods: Search) -> ()) {
        FatSecretParams.fatSecret = ["format":"json", "method":"foods.search", "search_expression":name] as Dictionary

        let components = generateSignature()
        fatSecretRequest(with: components) { data in
            guard let data = data else { return }
            let model = self.retrieve(data: data, type: [String: Search].self)
            let search = model!["foods"]
            completion(search!)
        }
    }
    
    /** Autocomplete
     - Description: Autocomplete for a food by query
     */
    public func searchFood(search: String, completion: @escaping (_ foods: Autocomplete) -> ()) {
        FatSecretParams.fatSecret = ["format":"json", "method":"foods.autocomplete", "expression":search] as Dictionary

        let components = generateSignature()
        fatSecretRequest(with: components) { data in
            guard let data = data else { return }
            let model = self.retrieve(data: data, type: [String: Autocomplete].self)
            let search = model!["suggestions"]
            completion(search!)
        }
    }

    /** Food
     - Description: Get a food item by id
     */
    public func getFood(id: String, completion: @escaping (_ foods: Food) -> ()) {
        FatSecretParams.fatSecret = ["format":"json", "method":"food.get", "food_id":id] as Dictionary

        let components = generateSignature()
        fatSecretRequest(with: components) { data in
            guard let data = data else { return }
            let model = self.retrieve(data: data, type: [String:Food].self)
            let food = model!["food"]
            completion(food!)
        }
    }

    public init() {}
}

extension FatSecretClient {
    fileprivate func fatSecretRequest(with components: URLComponents, completion: @escaping (_ data: Data?)-> ()) {
        var request = URLRequest(url: URL(string: String(describing: components).replacingOccurrences(of: "+", with: "%2B"))!)
        request.httpMethod = FatSecretParams.httpType

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let data = data {
                do {
                    let model = self.retrieve(data: data, type: [String:FSError].self)
                    if model != nil {
                        let error = model!["error"]
                        try self.checkForError(with: error!.code)
                    }

                    completion(data)
                } catch let error as NSError {
                    print(error.localizedDescription)
                }
            } else if let error = error {
                print(error.localizedDescription)
            }
        }
        task.resume()
    }

    fileprivate func retrieve<T: Decodable>(data: Data, type: T.Type) -> T? {
        let decoder = JSONDecoder()
        do {
            let model = try decoder.decode(type, from: data)
            return model
        } catch {
            return nil
        }
    }

    fileprivate func generateSignature() -> URLComponents {
        FatSecretParams.oAuth.updateValue(self.timestamp, forKey: "oauth_timestamp")
        FatSecretParams.oAuth.updateValue(self.nonce, forKey: "oauth_nonce")

        var oauthComponents = URLComponents(string: FatSecretParams.url)!
        oauthComponents.componentsForOAuthSignature(from: Array<String>().parameters)

        let parameters = oauthComponents.getURLParameters()
        let encodedURL = FatSecretParams.url.addingPercentEncoding(withAllowedCharacters: CharacterSet().percentEncoded)!
        let encodedParameters = parameters.addingPercentEncoding(withAllowedCharacters: CharacterSet().percentEncoded)!
        let signatureBaseString = "\(FatSecretParams.httpType)&\(encodedURL)&\(encodedParameters)"
        let signature = String().getSignature(key: FatSecretParams.key, params: signatureBaseString)

        var urlComponents = URLComponents(string: FatSecretParams.url)!
        urlComponents.componentsForURL(from: Array<String>().parameters)
        urlComponents.queryItems?.append(URLQueryItem(name: "oauth_signature", value: signature))
        return urlComponents
    }

    fileprivate func checkForError(with code: Int) throws {
        switch code {
        case 5:
            throw HTTPError.invalidKey
        case 8:
            throw HTTPError.invalidSignature
        default:
            throw HTTPError.unknown
        }
    }
}
