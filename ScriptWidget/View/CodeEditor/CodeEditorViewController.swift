//
//  CodeEditorViewController.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/10/28.
//

import UIKit
import SnapKit
import Combine

class CodeEditorViewController: UIViewController {
    var file: ScriptWidgetFile?
    
    public static let changeFileNotification = Notification.Name("CodeEditorViewControllerChangeFileNotification")
    public static let needSaveFileNotification = Notification.Name("CodeEditorViewControllerNeedSaveFileNotification")

    
    @IBOutlet var toolBar: UIToolbar!
    
    let textStorage = CodeAttributedString()
    var textView : UITextView!
    var highlightr : Highlightr!
    var bottomView: UIView!
    
    var lastSaveTextContent = ""
    
    var cancellables = [Cancellable]()
    
    let throttler = Throttler(minimumDelay: 1)

    @IBAction func onToolBarDoneTapped(_ sender: Any) {
        textView.resignFirstResponder()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bottomView = UIView()
        bottomView.backgroundColor = UIColor.blue
        self.view.addSubview(bottomView)
        bottomView.snp.makeConstraints { (make) in
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(0)
        }
        
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        textStorage.language = "javascript"
        highlightr = textStorage.highlightr
        
        let textContainer = NSTextContainer(size: view.bounds.size)
        layoutManager.addTextContainer(textContainer)
        
        textView = UITextView(frame: UIScreen.main.bounds, textContainer: textContainer)
        textView.autocorrectionType = UITextAutocorrectionType.no
        textView.autocapitalizationType = UITextAutocapitalizationType.none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.textColor = UIColor(white: 0.8, alpha: 1.0)
        textView.inputAccessoryView = toolBar
        self.view.addSubview(textView)
        textView.snp.makeConstraints { (make) in
            make.left.equalToSuperview()
            make.top.equalToSuperview()
            make.right.equalToSuperview()
            make.bottom.equalTo(bottomView.snp.top)
        }
        textView.isEditable = true

        textView.delegate = self
        
        updateTheme()
        
        setupObservers()
        
        reloadFile()
    }
    
    func reloadFile() {
        // save current
        saveFile()
        
        // load file content
        if let file = self.file {
            textView.text = file.readFile() ?? ""
            lastSaveTextContent = textView.text
        } else {
            textView.text = ""
        }
    }
    
    func setupObservers() {
        
        let cancellableWillResign = NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { (notification) in
                self.saveFile()
            }
        self.cancellables.append(cancellableWillResign)
        
        
        let cancellableChangeFile = NotificationCenter.default.publisher(for: CodeEditorViewController.changeFileNotification)
            .sink { (notification) in
                guard let newFile = notification.userInfo?["file"] as? ScriptWidgetFile else { return }

                self.file = newFile
                self.reloadFile()
            }
        self.cancellables.append(cancellableChangeFile)
        
        
        let cancellableNeedSaveFile = NotificationCenter.default.publisher(for: CodeEditorViewController.needSaveFileNotification)
            .sink { (notification) in
                print("need save file notification received")
                self.saveFile()
            }
        self.cancellables.append(cancellableNeedSaveFile)
    }
    
    deinit {
        for cancellable in self.cancellables {
            cancellable.cancel()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        saveFile()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        saveFile()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        updateTheme()
    }
    
    func updateTheme() {
        if self.traitCollection.userInterfaceStyle == .dark {
            highlightr.setTheme(to: "atom-one-dark")
        } else {
            highlightr.setTheme(to: "atelier-heath-light")
        }
        textView.backgroundColor = highlightr.theme.themeBackgroundColor
        self.view.backgroundColor = textView.backgroundColor
    }
    
    func triggerSave() {
        // save with debounce
        throttler.throttle {
            self.saveFile()
        }
    }
    
    
    func saveFile() {
        guard let file = self.file else { return }
        
        if file.isBundle {
            // no save for bundle files
            return
        }
        
        guard let currentTextContent = self.textView.text else { return }
        
        // check modification
        if self.lastSaveTextContent == currentTextContent {
            print("content not change")
            return
        }
        
        if file.writeFile(content: currentTextContent) {
            
            self.lastSaveTextContent = currentTextContent
            
            print("save file succeed :)")
        } else {
            print("save file failed -_-")
        }
    }
}



extension CodeEditorViewController : UITextViewDelegate {
    
    func textViewDidChange(_ textView: UITextView) {
        triggerSave()
    }
}

