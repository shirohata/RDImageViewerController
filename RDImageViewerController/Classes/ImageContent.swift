//
//  RDImageContentData.swift
//  Pods-RDImageViewerController
//
//  Created by Akira Matsuda on 2019/04/07.
//

import UIKit

open class ImageContent: PageContent {
    static let DefaultMaximumZoomScale: CGFloat = 2.5
    
    open var maximumZoomScale: CGFloat = DefaultMaximumZoomScale
    open var landscapeMode: ImageScrollView.LandscapeMode = .aspectFit
    open var image: UIImage?
    open var imageName: String?
    
    public override init(type: PresentationType) {
        super.init(type: type)
    }
    
    public convenience init(image: UIImage) {
        self.init(type: .class(ImageScrollView.self))
        self.image = image
    }
    
    public convenience init(imageName: String, lazyLoad: Bool = false) {
        self.init(type: .class(ImageScrollView.self))
        self.imageName = imageName
        if lazyLoad == false {
            preload()
        }
    }
    
    open override func preload(completion: ((PageContent) -> Void)?) {
        if image == nil, let imageName = imageName {
            image = UIImage(named: imageName)
            if let handler = completion {
                handler(self)
            }
        }
    }
    
    override open func preload() {
        preload(completion: nil)
    }
    
    override open func isPreloadable() -> Bool {
        return true
    }
    
    @objc override open func reload(completion: ((PageContent) -> Void)?) {
        image = nil
        preload(completion: completion)
    }
    
    override open func stopPreload() {
        
    }
    
    open override func size(inRect rect: CGRect, direction: PagingView.ForwardDirection, traitCollection: UITraitCollection, isDoubleSpread: Bool) -> CGSize {
        if direction.isVertical(), let image = image {
            var scale: CGFloat {
                if isDoubleSpread {
                    return (rect.size.width / 2.0) / image.size.width
                }
                return rect.size.width / image.size.width
            }
            
            let width = image.size.width * scale
            let height = image.size.height * scale
            return CGSize(width: width, height: height)
        }
        
        return super.size(inRect: rect, direction: direction, traitCollection: traitCollection, isDoubleSpread: isDoubleSpread)
    }
}
