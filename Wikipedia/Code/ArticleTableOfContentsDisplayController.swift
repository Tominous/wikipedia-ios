
// Handles hide/display of article table of contents
// Manages a stack view and the associated constraints

protocol ArticleTableOfContentsDisplayControllerDelegate : TableOfContentsViewControllerDelegate {
    func tableOfContentsDisplayControllerDidRecreateTableOfContentsViewController()
    func getVisibleSection(with: @escaping (Int, String) -> Void)
}

class ArticleTableOfContentsDisplayController: Themeable {
    
    weak var delegate: ArticleTableOfContentsDisplayControllerDelegate?
    
    lazy var viewController: TableOfContentsViewController = {
        return recreateTableOfContentsViewController()
    }()
    
    var theme: Theme = .standard
    let articleView: WKWebView

    func apply(theme: Theme) {
        self.theme = theme
        separatorView.backgroundColor = theme.colors.baseBackground
        stackView.backgroundColor = theme.colors.paperBackground
        inlineContainerView.backgroundColor = theme.colors.midBackground
        viewController.apply(theme: theme)
    }
    
    func recreateTableOfContentsViewController() -> TableOfContentsViewController {
        let displaySide: TableOfContentsDisplaySide = stackView.semanticContentAttribute == .forceRightToLeft ? .right : .left
        return TableOfContentsViewController(delegate: delegate, theme: theme, displaySide: displaySide)
    }
    
    init (articleView: WKWebView, delegate: ArticleTableOfContentsDisplayControllerDelegate, theme: Theme) {
        self.delegate = delegate
        self.theme = theme
        self.articleView = articleView
        stackView.semanticContentAttribute = delegate.tableOfContentsSemanticContentAttribute
        stackView.addArrangedSubview(inlineContainerView)
        stackView.addArrangedSubview(separatorView)
        stackView.addArrangedSubview(articleView)
        NSLayoutConstraint.activate([separatorWidthConstraint])
    }

    lazy var stackView: UIStackView = {
        let stackView = UIStackView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.alignment = .fill
        return stackView
    }()

    lazy var separatorView: UIView = {
        let sv = UIView(frame: .zero)
        sv.isHidden = true
        return sv
    }()
    
    lazy var inlineContainerView: UIView = {
        let cv = UIView(frame: .zero)
        cv.isHidden = true
        return cv
    }()
    
    lazy var separatorWidthConstraint: NSLayoutConstraint = {
        return separatorView.widthAnchor.constraint(equalToConstant: 1)
    }()

    func show(animated: Bool) {
        switch viewController.displayMode {
        case .inline:
            showInline()
        case .modal:
            showModal(animated: animated)
        }
    }
    
    func hide(animated: Bool) {
       switch viewController.displayMode {
       case .inline:
           hideInline()
       case .modal:
           hideModal(animated: animated)
       }
    }
    
    func showModal(animated: Bool) {
        guard delegate?.presentedViewController == nil else {
            return
        }
        delegate?.getVisibleSection(with: { (sectionId, _) in
            self.viewController.isVisible = true
            self.selectAndScroll(to: sectionId, animated: false)
            self.delegate?.present(self.viewController, animated: animated)
        })
    }
    
    func hideModal(animated: Bool) {
        viewController.isVisible = false
        delegate?.dismiss(animated: animated)
    }
    
    var verticalOffsetPercentageToRestore: CGFloat?
    
    func restoreOffsetPercentageIfNecessary() {
        guard let verticalOffsetPercentage = verticalOffsetPercentageToRestore else {
            return
        }
        verticalOffsetPercentageToRestore = nil
        articleView.scrollView.verticalOffsetPercentage = verticalOffsetPercentage
    }
    
    func showInline() {
        let scrollView = articleView.scrollView
        let offsetPercentage = scrollView.verticalOffsetPercentage
        viewController.isVisible = true
        UserDefaults.standard.wmf_setTableOfContentsIsVisibleInline(true)
        inlineContainerView.isHidden = false
        separatorView.isHidden = false
        verticalOffsetPercentageToRestore = offsetPercentage
    }
    
    func hideInline() {
        let scrollView = articleView.scrollView
        let offsetPercentage = scrollView.verticalOffsetPercentage
        viewController.isVisible = false
        UserDefaults.standard.wmf_setTableOfContentsIsVisibleInline(false)
        inlineContainerView.isHidden = true
        separatorView.isHidden = true
        verticalOffsetPercentageToRestore = offsetPercentage
    }
    
    func setup(with traitCollection:UITraitCollection) {
        update(with: traitCollection)
        guard viewController.displayMode == .inline, UserDefaults.standard.wmf_isTableOfContentsVisibleInline() else {
            return
        }
        showInline()
    }
    
    func update(with traitCollection: UITraitCollection) {
        let isCompact = traitCollection.horizontalSizeClass == .compact
        viewController.displayMode = isCompact ? .modal : .inline
        setupTableOfContentsViewController()
    }
    
    func setupTableOfContentsViewController() {
        switch viewController.displayMode {
        case .inline:
            guard viewController.parent != delegate else {
                return
            }
            let wasVisible = viewController.isVisible
            if wasVisible {
                hideModal(animated: false)
            }
            viewController = recreateTableOfContentsViewController()
            viewController.displayMode = .inline
            delegate?.addChild(viewController)
            inlineContainerView.wmf_addSubviewWithConstraintsToEdges(viewController.view)
            viewController.didMove(toParent: delegate)
            if wasVisible {
                showInline()
            }
            delegate?.tableOfContentsDisplayControllerDidRecreateTableOfContentsViewController()
        case .modal:
            guard viewController.parent == delegate else {
                return
            }
            let wasVisible = viewController.isVisible
            viewController.displayMode = .modal
            viewController.willMove(toParent: nil)
            viewController.view.removeFromSuperview()
            viewController.removeFromParent()
            viewController = recreateTableOfContentsViewController()
            if wasVisible {
                hideInline()
                showModal(animated: false)
            }
            delegate?.tableOfContentsDisplayControllerDidRecreateTableOfContentsViewController()
        }
    }
    
    func selectAndScroll(to sectionId: Int, animated: Bool) {
        guard let index = delegate?.tableOfContentsItems.firstIndex(where: { $0.id == sectionId }) else {
            return
        }
        viewController.selectItem(at: index)
        viewController.scrollToItem(at: index)
    }

}
