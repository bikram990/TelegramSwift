//
//  PreviewSenderController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 02/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac

private enum SecretMediaTtl {
    case off
    case seconds(Int32)
}

private enum PreviewSenderType {
    case files
    case photo
    case video
    case gif
    case audio
    case media
}

fileprivate class PreviewSenderView : Control {
    fileprivate let tableView:TableView = TableView()
    fileprivate let textView:TGModernGrowingTextView = TGModernGrowingTextView(frame: NSZeroRect)
    fileprivate let sendButton = ImageButton()
    fileprivate let emojiButton = ImageButton()
    fileprivate let actionsContainerView: View = View()
    fileprivate let headerView: View = View()
    
    fileprivate let closeButton = ImageButton()
    fileprivate let title: TextView = TextView()
    
    fileprivate let photoButton = ImageButton()
    fileprivate let fileButton = ImageButton()
    
    fileprivate let textContainerView: View = View()
    fileprivate let separator: View = View()
    fileprivate weak var controller: PreviewSenderController? {
        didSet {
            let count = controller?.urls.count ?? 0
            textView.setPlaceholderAttributedString(.initialize(string: count > 1 ? tr(.previewSenderCommentPlaceholder) : tr(.previewSenderCaptionPlaceholder), color: theme.colors.grayText, font: .normal(.text)), update: false)
        }
    }
    let sendAsFile: ValuePromise<Bool> = ValuePromise(ignoreRepeated: true)
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        
        separator.backgroundColor = theme.colors.border
        
        closeButton.set(image: theme.icons.modalClose, for: .Normal)
        closeButton.sizeToFit()
        
        
        photoButton.toolTip = tr(.previewSenderMediaTooltip)
        fileButton.toolTip = tr(.previewSenderFileTooltip)
        
        photoButton.set(image: ControlStyle(highlightColor: theme.colors.grayIcon).highlight(image: theme.icons.chatAttachPhoto), for: .Normal)
        photoButton.sizeToFit()
        
        photoButton.isSelected = true
        
        photoButton.set(handler: { [weak self] _ in
            self?.sendAsFile.set(false)
            self?.fileButton.isSelected = false
            self?.photoButton.isSelected = true
        }, for: .Click)
        
        fileButton.set(handler: { [weak self] _ in
            self?.sendAsFile.set(true)
            self?.fileButton.isSelected = true
            self?.photoButton.isSelected = false
        }, for: .Click)
        
        closeButton.set(handler: { [weak self] _ in
            self?.controller?.close()
        }, for: .Click)
        
        fileButton.set(image: ControlStyle(highlightColor: theme.colors.grayIcon).highlight(image: theme.icons.chatAttachFile), for: .Normal)
        fileButton.sizeToFit()
        
        title.backgroundColor = theme.colors.background
        
        headerView.addSubview(closeButton)
        headerView.addSubview(title)
        headerView.addSubview(fileButton)
        headerView.addSubview(photoButton)
        
        title.isSelectable = false
        title.userInteractionEnabled = false
        
        sendButton.set(image: theme.icons.chatSendMessage, for: .Normal)
        sendButton.sizeToFit()
        
        emojiButton.set(image: theme.icons.chatEntertainment, for: .Normal)
        emojiButton.sizeToFit()
        
        actionsContainerView.addSubview(sendButton)
        actionsContainerView.addSubview(emojiButton)
        
        
        actionsContainerView.setFrameSize(sendButton.frame.width + emojiButton.frame.width + 40, 50)
        
        emojiButton.centerY(x: 0)
        sendButton.centerY(x: emojiButton.frame.maxX + 20)
        
        backgroundColor = theme.colors.background
        textView.background = theme.colors.background
        textView.textFont = .normal(.text)
        textView.textColor = theme.colors.text
        textView.linkColor = theme.colors.link
        textView.max_height = 120
        
        emojiButton.set(handler: { [weak self] control in
            self?.controller?.showEmoji(for: control)
        }, for: .Hover)
        
        sendButton.set(handler: { [weak self] _ in
            self?.controller?.send()
        }, for: .SingleClick)
        
        textView.setFrameSize(NSMakeSize(0, 34))

        addSubview(tableView)

        
        textContainerView.addSubview(textView)
        
        addSubview(headerView)
        addSubview(textContainerView)
        addSubview(actionsContainerView)
        
        addSubview(separator)

    }
    
    var additionHeight: CGFloat {
        return max(50, textView.frame.height + 16) + headerView.frame.height - 12
    }
    
    func updateTitle(_ medias: [Media], isFile: Bool) -> Void {
        
        
        let count = medias.count
        let type: PreviewSenderType
        if isFile {
            type = .files
        } else {
                        
            if medias.filter({$0 is TelegramMediaImage}).count == medias.count {
                type = .photo
            } else {
                let files = medias.filter({$0 is TelegramMediaFile}).map({$0 as! TelegramMediaFile})
                
                if files.filter({$0.isMusic}).count == files.count {
                    type = .audio
                } else if files.filter({$0.isVideo && !$0.isAnimated}).count == files.count {
                    type = .video
                } else if files.filter({$0.isVideo && $0.isAnimated}).count == files.count {
                    type = .gif
                } else if files.filter({!$0.isVideo || !$0.isAnimated || $0.isMusic}).count != medias.count {
                    type = .media
                } else {
                    type = .files
                }
            }
            
        }
        
        let text:String
        switch type {
        case .files:
            text = tr(.previewSenderSendFileCountable(count))
        case .photo:
            text = tr(.previewSenderSendPhotoCountable(count))
        case .video:
            text = tr(.previewSenderSendVideoCountable(count))
        case .gif:
            text = tr(.previewSenderSendGifCountable(count))
        case .audio:
            text = tr(.previewSenderSendAudioCountable(count))
        case .media:
            text = tr(.previewSenderSendMediaCountable(count))
        }
        
        let layout = TextViewLayout(.initialize(string: text, color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1)
        title.update(layout)
        needsLayout = true
        separator.isHidden = tableView.listHeight <= frame.height - additionHeight
    }
    
    func updateHeight(_ height: CGFloat, _ animated: Bool) {
        CATransaction.begin()
        textContainerView.change(size: NSMakeSize(frame.width, height + 16), animated: animated)
        textContainerView.change(pos: NSMakePoint(0, frame.height - textContainerView.frame.height), animated: animated)
        textView._change(pos: NSMakePoint(10, height == 34 ? 8 : 11), animated: animated)

        actionsContainerView.change(pos: NSMakePoint(frame.width - actionsContainerView.frame.width, frame.height - actionsContainerView.frame.height), animated: animated)

        separator.change(pos: NSMakePoint(0, textContainerView.frame.minY), animated: animated)
        separator.change(opacity: tableView.listHeight > frame.height - additionHeight ? 1.0 : 0.0, animated: animated)
        CATransaction.commit()
        
        needsLayout = true
    }
    
    func applyOptions(_ options:[PreviewOptions]) {
        fileButton.isHidden = !options.contains(.media)
        photoButton.isHidden = !options.contains(.media)
    }
    
    override func layout() {
        super.layout()
        actionsContainerView.setFrameOrigin(frame.width - actionsContainerView.frame.width, frame.height - actionsContainerView.frame.height)
        headerView.setFrameSize(frame.width, 50)
        
        
        tableView.setFrameSize(NSMakeSize(frame.width, frame.height - additionHeight))
        tableView.centerX(y: headerView.frame.maxY - 6)
        
        title.layout?.measure(width: frame.width - 100)
        title.update(title.layout)
        title.centerX()
        title.centerY()
        closeButton.centerY(x: headerView.frame.width - closeButton.frame.width - 10)
        
        photoButton.centerY(x: 10)
        fileButton.centerY(x: photoButton.frame.maxX + 10)
        
        textContainerView.setFrameSize(frame.width, textView.frame.height + 16)
        textContainerView.setFrameOrigin(0, frame.height - textContainerView.frame.height)
        textView.setFrameSize(NSMakeSize(textContainerView.frame.width - 10 - actionsContainerView.frame.width, textView.frame.height))
        textView.setFrameOrigin(10, textView.frame.height == 34 ? 8 : 11)
        
        separator.frame = NSMakeRect(0, textContainerView.frame.minY, frame.width, .borderSize)

    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PreviewSenderController: ModalViewController, TGModernGrowingDelegate {

    fileprivate let urls:[URL]
    private let account:Account
    private let chatInteraction:ChatInteraction
    private var isNeedAsFile:Bool = true
    private let disposable = MetaDisposable()
    private let emoji: EmojiViewController
    private var cachedMedia:[Bool: (media: [Media], items: [MediaPreviewRowItem])] = [:]
    
    private let isFileDisposable = MetaDisposable()
    
    override func viewClass() -> AnyClass {
        return PreviewSenderView.self
    }
    
    private var genericView:PreviewSenderView {
        return self.view as! PreviewSenderView
    }
    
    
    func makeItems(_ urls:[URL])  {
        let initialSize = atomicSize
        let account = self.account
        
        let options = takeSenderOptions(for: urls)
        genericView.applyOptions(options)
        
        let signal = genericView.sendAsFile.get() |> mapToSignal { [weak self] isFile -> Signal<([Media], [MediaPreviewRowItem], Bool), Void> in
            if let cached = self?.cachedMedia[isFile] {
                return .single((cached.media, cached.items, isFile))
            }
            return combineLatest(urls.map({Sender.generateMedia(for: MediaSenderContainer(path: $0.path, caption: "", isFile: isFile), account: account)}))
                |> map { $0.map({$0.0})}
                |> map { ($0, $0.map{MediaPreviewRowItem(initialSize.modify{$0}, media: $0, account: account)}, isFile) }
        } |> deliverOnMainQueue
        
        let animated: Atomic<Bool> = Atomic(value: false)
        
        disposable.set(signal.start(next: { [weak self] medias, items, isFile in
            if let strongSelf = self {
                strongSelf.isNeedAsFile = isFile
                strongSelf.cachedMedia[isFile] = (media: medias, items: items)
                strongSelf.genericView.updateTitle(medias, isFile: strongSelf.isNeedAsFile)
                strongSelf.genericView.tableView.beginTableUpdates()
                strongSelf.genericView.tableView.removeAll(animation: .effectFade)
                strongSelf.genericView.tableView.insert(items: items, animation: .effectFade)
                strongSelf.genericView.tableView.endTableUpdates()
                strongSelf.genericView.layout()
                
                let animated = animated.swap(true)
                
                let maxWidth = animated ? strongSelf.frame.width : max(items.map({$0.layoutSize.width}).max()! + 20, 350)
                strongSelf.updateSize(maxWidth, animated: animated)
                strongSelf.readyOnce()
            }
        }))
    }
    
    private func updateSize(_ width: CGFloat, animated: Bool) {
        if let contentSize = self.window?.contentView?.frame.size {
            self.modal?.resize(with:NSMakeSize(width, min(contentSize.height - 70, genericView.tableView.listHeight + max(genericView.additionHeight, 88))), animated: animated)
        }
    }
  
    override var dynamicSize: Bool {
        return true
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        if let currentEvent = NSApp.currentEvent {
            if FastSettings.checkSendingAbility(for: currentEvent) {
                send()
                return .invoked
            }
        }
        
        return .invokeNext
    }
    
    func send() {
        emoji.popover?.hide()
        self.modal?.close(true)
        var caption = genericView.textView.string()
        if let cached = cachedMedia[isNeedAsFile] {
            if cached.media.count > 1 && !caption.isEmpty {
                chatInteraction.forceSendMessage(caption)
                caption = ""
            }
            chatInteraction.sendMedias(cached.media, caption)
        }
    }
    
    
    override func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 70, genericView.tableView.listHeight + max(genericView.additionHeight, 88))), animated: false)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.controller = self
        genericView.textView.delegate = self
        genericView.sendAsFile.set(isNeedAsFile)
        let interactions = EntertainmentInteractions(.emoji, peerId: chatInteraction.peerId)
        
        interactions.sendEmoji = { [weak self] emoji in
            self?.genericView.textView.appendText(emoji)
        }
        
        emoji.update(with: interactions)
        
        makeItems(self.urls)
    }
    
    deinit {
        disposable.dispose()
        isFileDisposable.dispose()
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    override func firstResponder() -> NSResponder? {
        return genericView.textView
    }
    
    init(urls:[URL], account:Account, chatInteraction:ChatInteraction, asMedia:Bool = true) {
        self.urls = urls
        self.account = account
        self.emoji = EmojiViewController(account)
        self.isNeedAsFile = !asMedia
        self.chatInteraction = chatInteraction
        super.init(frame:NSMakeRect(0,0,300, 300))
        bar = .init(height: 0)
    }
    
    func showEmoji(for control: Control) {
        showPopover(for: control, with: emoji)
    }
    
    func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        
        updateSize(frame.width, animated: animated)
        
        genericView.updateHeight(height, animated)
        
    }
    
    func textViewEnterPressed(_ event: NSEvent) -> Bool {
        if FastSettings.checkSendingAbility(for: event) {
            return true
        }
        return false
    }
    
    func textViewTextDidChange(_ string: String) {
        
    }
    
    func textViewTextDidChangeSelectedRange(_ range: NSRange) {
        
    }
    
    
    
    func textViewDidReachedLimit(_ textView: Any) {
        genericView.textView.shake()
    }
    
    func textViewDidPaste(_ pasteboard: NSPasteboard) -> Bool {
        return false
    }
    
    func textViewSize() -> NSSize {
        return NSMakeSize(frame.width - 40, genericView.textView.frame.height)
    }
    
    func textViewIsTypingEnabled() -> Bool {
        return true
    }
    
    func maxCharactersLimit() -> Int32 {
        return 200
    }
    
}
