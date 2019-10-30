//
//  ViewController.swift
//  WKWebView-Sampler
//
//  Created by Muramatsu Ryunosuke on 2019/10/28.
//  Copyright © 2019 Muramatsu Ryunosuke. All rights reserved.
//

import UIKit
import WebKit

final class ViewController: UIViewController {

    enum Mode {
        case normal
        case closeOnly
    }

    @IBOutlet private weak var toolbar: UIToolbar!
    @IBOutlet private weak var backButton: UIBarButtonItem!
    @IBOutlet private weak var forwardButton: UIBarButtonItem!
    
    @IBOutlet private weak var headerView: UIView!
    @IBOutlet private weak var headerStackView: UIStackView!
    
    @IBOutlet private weak var urlHostLabel: UILabel!
    @IBOutlet private weak var sslIconView: UIImageView!
    
    @IBOutlet private weak var progressView: UIProgressView!

    @IBOutlet private weak var webView: WKWebView!
    
    // Autolayout outlet
    @IBOutlet private weak var headerViewHeightConstraint: NSLayoutConstraint!

    // Constant value
    private let headerViewMaxHeight: CGFloat = 20
    private let headerViewMinHeight: CGFloat = 0
    private let animationDuration = 0.2
    private let scrollPaddingAnimation: CGFloat = 30.0
    private var scrollStartPoint: CGPoint = .zero
    private var observation: NSKeyValueObservation?

    
    var urlString: String? = "https://www.apple.com/"
    var mode: Mode = .normal

    static func instantiate(with urlString: String) -> ViewController {
        let vc = UIStoryboard(name: "main", bundle: nil)
            .instantiateInitialViewController() as! ViewController
        vc.urlString = urlString
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initially disable back and forward buttons.
        backButton.isEnabled = false
        forwardButton.isEnabled = false
        
        // Custom configuration.
        webView.configuration.processPool = WKProcessPool.shared
        
        // Set delegate into self.
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.scrollView.delegate = self
        
        // Enable swipe movement.
        webView.allowsBackForwardNavigationGestures = true
        // Tell that it is scrollable
        webView.scrollView.flashScrollIndicators()
        
        guard let urlString = urlString,
            let url = URL(string: urlString) else {
                DispatchQueue.main.async {
                    // Show error alert.
                }
                return
        }
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        if mode == .closeOnly {
            var items = toolbar.items
            items?.removeFirst(7)  // close button position.
            toolbar.setItems(items, animated: false)
        }
        
        // ProgressLoading処理
        observation = webView.observe(\WKWebView.estimatedProgress, options: .new) { _, _ in
            let changeValue = Float(self.webView.estimatedProgress)
            
            // Loadingバー表示
            self.progressView.alpha = 1
            
            // 読み込み状態更新
            self.progressView.setProgress(changeValue, animated: true)
            
            // 読み込み完了したらLoadingバー未表示
            if (self.webView.estimatedProgress == 1.0) {
                UIView.animate(withDuration: 0.3,
                               delay: 0,
                               options: [.curveEaseOut],
                               animations: { [weak self] in
                                self?.progressView.alpha = 0.0
                    }, completion: { _ in
                        self.progressView.setProgress(0.0, animated: false)
                })
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
//        CookieManager.saveCookieFromStorage()
    }
    // ステータスバーの背景色を黒に、文字色を白に変更する
    override var preferredStatusBarStyle: UIStatusBarStyle {
        let statusBar = UIView(frame:
            CGRect(x: 0.0, y: 0.0,
                   width: UIApplication.shared.statusBarFrame.size.width,
                   height: UIApplication.shared.statusBarFrame.size.height)
        )
        statusBar.backgroundColor = .black
        view.addSubview(statusBar)
        return .lightContent
    }
    
    deinit {
        webView.stopLoading()
        observation = nil
    }
}

// MARK: - IBAction
private extension ViewController {
    
    @IBAction func backPage(_ sender: UIBarButtonItem) {
        webView.goBack()
        backButton.isEnabled = webView.canGoBack
    }
    
    @IBAction func forwardPage(_ sender: UIBarButtonItem) {
        webView.goForward()
        forwardButton.isEnabled = webView.canGoForward
    }
    
    @IBAction func sharePage(_ sender: UIBarButtonItem) {
        let shareItems: [Any] = [
            webView.title ?? "",
            webView.url ?? ""
        ]
        let activityVC = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
        present(activityVC, animated: true, completion: nil)
    }
    
    @IBAction func reloadPage(_ sender: UIBarButtonItem) {
        webView.reload()
    }
    
    @IBAction func closePage(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - WKUIDelegate
extension ViewController: WKUIDelegate {
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // target="_blank" をWKWebViewでそのまま開くために必要
        if navigationAction.targetFrame?.isMainFrame != true {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

// MARK: - WKNavigationDelegate
extension ViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        updateURLHostAndSSL(url: webView.url)
    }
    
    // 遷移開始
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // サインインページ等は戻る進むボタンがないため
        if mode == .normal {
            // 戻る・進むボタンの有効非有効をスイッチ
            backButton.isEnabled = webView.canGoBack
            forwardButton.isEnabled = webView.canGoForward
        }
    }
    
    // 読み込み完了
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // TIPS: 必ずしもdidFinishメソッドは呼ばれない
    }
    
    // WebPageの読み込み開始時にerrorが起きた時に呼ばれる
    // 圏外や機内モードはここに入る
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    }
    
    // WebPageの読み込み途中でerrorが起きた時に呼ばれる
    // ページ読み込み中にリンクをタップして読み込みをキャンセルしたときなど
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    }
    
    // URLの読み込みを許可するか許可しないかを判断
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        switch navigationAction.navigationType {
        // フォームの送信
        case .formSubmitted,
             .linkActivated,
             .backForward,
             .reload,
             .formResubmitted,
             .other:
            fallthrough
            
        @unknown default:
            print("\(navigationAction.navigationType): \(url.absoluteString)")
        }
        
        guard let host = url.host else {
            decisionHandler(.allow)
            return
        }
        
        // 特別に外部ブラウザで開きたいHostを指定
        if host == "www.example.com" {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                decisionHandler(.cancel)
                return
            }
        }
        
        webView.loadCookieFromStorage(domain: host) {
            decisionHandler(.allow)
            return
        }
    }
    
    // レスポンス判断
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        webView.writeCookieToStorage { _ in
            decisionHandler(.allow)
        }
    }

    /// SSLアイコンとURLHostの表示を遷移先ページのものに更新する
    private func updateURLHostAndSSL(url: URL?) {
        guard let scheme = url?.scheme,
            let host = url?.host else {
                return
        }
        sslIconView.isHidden = scheme != "https"
        urlHostLabel.text = "\(scheme)://\(host)"
    }
}

// MARK: - UIScrollViewDelegate
extension ViewController: UIScrollViewDelegate {
    // スクロールを開始する位置取る
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollStartPoint = scrollView.contentOffset
    }
    
    // WebViewのスクロールする時、方向を計算タイトルバー表示・未表示する
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let y: CGFloat = scrollView.contentOffset.y
        let yVelocity = scrollView.panGestureRecognizer.velocity(in: scrollView).y
        if abs(y - scrollStartPoint.y) >= scrollPaddingAnimation {
            if yVelocity < 0 {
                animationMoveUp()
            } else if yVelocity > 0 {
                animationMoveDown()
            }
        }
    }
    
    // タイトルバー未表示
    private func animationMoveUp() {
        UIView.animate(withDuration: animationDuration, animations: {
            self.headerViewHeightConstraint.constant = self.headerViewMinHeight
            self.urlHostLabel.alpha = 0
            self.sslIconView.alpha = 0
            self.view.layoutIfNeeded()
        })
    }
    
    // タイトルバー表示
    private func animationMoveDown() {
        UIView.animate(withDuration: animationDuration, animations: {
            self.headerViewHeightConstraint.constant = self.headerViewMaxHeight
            self.urlHostLabel.alpha = 1
            self.sslIconView.alpha = 1
            self.view.layoutIfNeeded()
        })
    }
}
