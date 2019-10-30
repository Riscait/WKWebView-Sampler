//
//  CookieManager.swift
//  WKWebView-Sampler
//
//  Created by Muramatsu Ryunosuke on 2019/10/28.
//  Copyright © 2019 Muramatsu Ryunosuke. All rights reserved.
//

import UIKit
import WebKit

let UDCookie: String = "UDWkCookies"

extension WKProcessPool {
    static var shared = WKProcessPool()
    
    func reset(){
        WKProcessPool.shared = WKProcessPool()
    }
}

final class CookieManager: NSObject {
    
    static func saveCookieFromStorage() {
        guard let cookies = HTTPCookieStorage.shared.cookies else {
            return
        }
        let cookiesData = NSKeyedArchiver.archivedData(withRootObject: cookies)
        UserDefaults.standard.set(cookiesData, forKey: UDCookie)
        UserDefaults.standard.synchronize()
    }
    
    static func loadCookies() -> [HTTPCookie]? {
        let cookiesData = UserDefaults.standard.object(forKey: UDCookie)
        if let cookiesData = cookiesData, cookiesData is Data{
            if (cookiesData as AnyObject).length > 0 {
                let cookies = NSKeyedUnarchiver.unarchiveObject(with: cookiesData as! Data) as? NSArray
                let cookieStorage = HTTPCookieStorage.shared
                for cookie in cookies! {
                    cookieStorage.setCookie(cookie as! HTTPCookie)
                }
                return cookies as? [HTTPCookie]
            }
        }
        
        return nil
    }
    
    static func resetCookie() {
        WKProcessPool.shared.reset()
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: Date(timeIntervalSince1970: 0), completionHandler: {})
        
        let cookieStorage = HTTPCookieStorage.shared
        
        if let cookies = cookieStorage.cookies {
            for cookie in cookies {
                cookieStorage.deleteCookie(cookie)
            }
        }
        
        UserDefaults.standard.removeObject(forKey: UDCookie)
        UserDefaults.standard.synchronize()
    }
}

// =======================================================
// =======================================================
// =========== WKWebView extensions=======================
// =======================================================
// =======================================================

extension WKWebView {
    func fetchInMemoryCookies(for domain: String, completion: @escaping ([String: AnyObject]) -> ()) {
        var cookieDict = [String: AnyObject]()
        
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { (cookies) in
            for cookie in cookies {
                if domain != cookie.domain && !domain.hasSuffix(cookie.domain) && !cookie.domain.hasSuffix(domain) {
                    continue
                }
                
                cookieDict[cookie.name] = cookie.properties as AnyObject?
            }
            completion(cookieDict)
        }
    }
    
    func writeCookieToStorage(completion: (([HTTPCookie]) -> ())? ) {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { (cookies) in
            for cookie in cookies {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
            completion?(cookies)
        }
    }
    
    func loadCookieFromStorage(domain: String, completion: @escaping ()->()) {
        guard let diskCookies = HTTPCookieStorage.shared.cookies else {
            return
        }
        
        var cookieDict = [String: AnyObject]()
        for cookie in diskCookies {
            if domain != cookie.domain && !domain.hasSuffix(cookie.domain) && !cookie.domain.hasSuffix(domain) {
                continue
            }
            
            cookieDict[cookie.name] = cookie.properties as AnyObject?
        }
        
        fetchInMemoryCookies(for: domain, completion: { currentCookies in
            
            let mergedCookie = cookieDict.merging(currentCookies) { (_, new) in new }
            
            for (_, cookieConfig) in mergedCookie {
                let cookie = cookieConfig as! Dictionary<String, Any>
                
                var expire : Any? = nil
                
                if let expireTime = cookie["Expires"] as? Double{
                    expire = Date(timeIntervalSinceNow: expireTime)
                }
                
                let newCookie = HTTPCookie(properties: [
                    .domain: cookie["Domain"] as Any,
                    .path: cookie["Path"] as Any,
                    .name: cookie["Name"] as Any,
                    .value: cookie["Value"] as Any,
                    .secure: cookie["Secure"] as Any,
                    .expires: expire as Any
                    ])
                
                self.configuration.websiteDataStore.httpCookieStore.setCookie(newCookie!)
            }
            completion()
        })
    }
}
