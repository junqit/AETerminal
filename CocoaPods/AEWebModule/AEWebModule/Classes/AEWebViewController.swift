//
//  AEWebViewController.swift
//  AEWebModule
//
//  Created on 2026/09/05.
//

#if os(macOS)
import AppKit
import WebKit
import AELogProxy

public typealias AEWebViewControllerBase = NSViewController
#elseif os(iOS)
import UIKit
import WebKit
import AELogProxy

public typealias AEWebViewControllerBase = UIViewController
#endif

/// JS 桥处理协议（native <-> JS）
public protocol AEWebScriptHandler: AnyObject {

    /// JS 调用 native 时触发；return 的值回传给 JS
    func webScript(didReceive name: String, arguments: [Any]) -> Any?
}

/// 基于 WKWebView 的网页加载视图控制器（macOS + iOS）
/// caller 将 controller.view 嵌入自有视图层级，再调用 open(url:) 载入网址
public class AEWebViewController: AEWebViewControllerBase {

    // MARK: - Properties

    private var webView: WKWebView!

    #if os(macOS)
    private var topBar: NSView!
    private var progressBar: NSProgressIndicator!
    private var backButton: NSButton!
    private var forwardButton: NSButton!
    private var reloadButton: NSButton!
    #elseif os(iOS)
    private var navigationBar: UINavigationBar!
    private var progressBar: UIProgressView!
    #endif

    /// 当前加载的 URL
    public private(set) var currentURL: URL?

    /// JS 桥处理者
    public weak var scriptHandler: AEWebScriptHandler?

    /// JS 桥注册名（window.webkit.messageHandlers[name]）
    public var scriptName: String = "aeBridge"

    private var progressObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        setupWebView()
        setupChrome()
        setupObservers()
    }

    deinit {
        progressObservation?.invalidate()
        titleObservation?.invalidate()
    }

    // MARK: - WebView Setup

    private func setupWebView() {

        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(self, name: scriptName)
        config.userContentController = userContentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        view.addSubview(webView)
    }

    // MARK: - Chrome Setup

    #if os(macOS)
    private func setupChrome() {

        topBar = NSView()
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        backButton = makeButton("←", action: #selector(goBack))
        forwardButton = makeButton("→", action: #selector(goForward))
        reloadButton = makeButton("⟳", action: #selector(reload))
        topBar.addSubview(backButton)
        topBar.addSubview(forwardButton)
        topBar.addSubview(reloadButton)

        progressBar = NSProgressIndicator()
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 1
        view.addSubview(progressBar)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 30),

            backButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 8),
            backButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            forwardButton.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 4),
            forwardButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            reloadButton.leadingAnchor.constraint(equalTo: forwardButton.trailingAnchor, constant: 4),
            reloadButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            progressBar.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            webView.topAnchor.constraint(equalTo: progressBar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func makeButton(_ title: String, action: Selector) -> NSButton {

        let btn = NSButton(frame: .zero)
        btn.title = title
        btn.target = self
        btn.action = action
        btn.bezelStyle = .inline
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }
    #elseif os(iOS)
    private func setupChrome() {

        navigationBar = UINavigationBar()
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navigationBar)

        let navItem = UINavigationItem()
        navItem.leftBarButtonItems = [
            UIBarButtonItem(title: "←", style: .plain, target: self, action: #selector(goBack)),
            UIBarButtonItem(title: "→", style: .plain, target: self, action: #selector(goForward))
        ]
        navItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh, target: self, action: #selector(reload)
        )
        navigationBar.items = [navItem]

        progressBar = UIProgressView(progressViewStyle: .bar)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.tintColor = .systemBlue
        view.addSubview(progressBar)

        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            progressBar.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            webView.topAnchor.constraint(equalTo: progressBar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    #endif

    // MARK: - Observers

    private func setupObservers() {

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, change in

            guard let self = self else { return }

            let progress = Float(change.newValue ?? 0)
            DispatchQueue.main.async {
                self.setProgress(progress)
            }
        }

        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] _, change in

            guard let self = self else { return }

            DispatchQueue.main.async {
                self.setTitle(change.newValue ?? "")
            }
        }
    }

    // MARK: - Progress / Title helpers

    #if os(macOS)
    private func setProgress(_ value: Float) {

        progressBar.doubleValue = Double(value)
        progressBar.isHidden = value >= 1.0
    }

    private func setProgressHidden(_ hidden: Bool) {
        progressBar.isHidden = hidden
    }

    private func setTitle(_ title: String?) {
        view.window?.title = title ?? ""
    }
    #elseif os(iOS)
    private func setProgress(_ value: Float) {

        progressBar.setProgress(value, animated: true)
        progressBar.isHidden = value >= 1.0
    }

    private func setProgressHidden(_ hidden: Bool) {
        progressBar.isHidden = hidden
    }

    private func setTitle(_ title: String?) {
        navigationBar.topItem?.title = title
    }
    #endif

    // MARK: - Public

    /// 加载 URL
    /// - Parameter url: 要加载的网址
    public func load(url: URL) {
        currentURL = url
        var request = URLRequest(url: url)
        request.cachePolicy = .useProtocolCachePolicy
        webView.load(request)
    }

    /// 加载字符串（base URL 模式）
    public func load(htmlString: String, baseURL: URL? = nil) {
        webView.loadHTMLString(htmlString, baseURL: baseURL)
    }

    // MARK: - Navigation

    @objc public func goBack() {
        if webView.canGoBack { webView.goBack() }
    }

    @objc public func goForward() {
        if webView.canGoForward { webView.goForward() }
    }

    @objc public func reload() {
        webView.reload()
    }

    // MARK: - JS

    @discardableResult
    public func evaluateJavaScript(_ js: String) async -> Any? {
        await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(js) { result, _ in
                continuation.resume(returning: result)
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension AEWebViewController: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        setProgressHidden(false)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        setProgress(1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.setProgressHidden(true)
        }
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        AELog("⚠️ [Web] 网页加载失败，url:\(currentURL?.absoluteString ?? "")")
        setProgressHidden(true)
    }
}

// MARK: - WKScriptMessageHandler（JS 桥）

extension AEWebViewController: WKScriptMessageHandler {

    public func userContentController(_ userContentController: WKUserContentController,
                                      didReceive message: WKScriptMessage) {
        guard message.name == scriptName else { return }
        let name = message.body as? String ?? ""
        let result = scriptHandler?.webScript(didReceive: name, arguments: []) ?? ""
        if let result = result as? String {
            let js = "window.aeBridgeCallback && aeBridgeCallback('\(result)')"
            webView.evaluateJavaScript(js)
        }
    }
}
