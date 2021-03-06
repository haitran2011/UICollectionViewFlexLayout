#if os(iOS)
import UIKit

public let UICollectionElementKindSectionBackground = "UICollectionElementKindSectionBackground"

open class UICollectionViewFlexLayout: UICollectionViewLayout {
  private(set) var layoutAttributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]
  private(set) var backgroundAttributes: [Int: UICollectionViewLayoutAttributes] = [:]
  private(set) var cachedContentSize: CGSize = .zero

  override open func prepare() {
    guard let collectionView = self.collectionView else { return }

    let contentWidth = collectionView.frame.width
    var offset: CGPoint = .zero

    self.layoutAttributes.removeAll()
    for section in 0..<collectionView.numberOfSections {
      let sectionVerticalSpacing: CGFloat
      if section > 0 {
        sectionVerticalSpacing = self.verticalSpacing(betweenSectionAt: section - 1, and: section)
      } else {
        sectionVerticalSpacing = 0
      }
      let sectionMargin = self.margin(forSectionAt: section)
      let sectionPadding = self.padding(forSectionAt: section)

      // maximum value of (height + padding bottom + margin bottom) in current row
      var maxItemBottom: CGFloat = 0

      offset.x = sectionMargin.left + sectionPadding.left // start from left
      offset.y += sectionVerticalSpacing + sectionMargin.top + sectionPadding.top // accumulated

      for item in 0..<collectionView.numberOfItems(inSection: section) {
        let indexPath = IndexPath(item: item, section: section)
        let itemMargin = self.margin(forItemAt: indexPath)
        let itemPadding = self.padding(forItemAt: indexPath)
        let itemSize = self.size(forItemAt: indexPath)

        if item > 0 {
          offset.x += self.horizontalSpacing(betweenItemAt: IndexPath(item: item - 1, section: section), and: indexPath)
        }
        if offset.x + itemMargin.left + itemPadding.left + itemSize.width + itemPadding.right + itemMargin.right + sectionPadding.right + sectionMargin.right > contentWidth {
          offset.x = sectionMargin.left + sectionPadding.left // start from left
          offset.y += maxItemBottom // next line
          if item > 0 {
            offset.y += self.verticalSpacing(betweenItemAt: IndexPath(item: item - 1, section: section), and: indexPath)
          }
          maxItemBottom = 0
        }

        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.size = itemSize
        attributes.frame.origin.x = offset.x + itemMargin.left + itemPadding.left
        attributes.frame.origin.y = offset.y + itemMargin.top + itemPadding.top

        offset.x += itemSize.width + itemPadding.right + itemMargin.right
        maxItemBottom = max(maxItemBottom, itemMargin.top + itemPadding.top + itemSize.height + itemPadding.bottom + itemMargin.bottom)
        self.layoutAttributes[indexPath] = attributes
      }

      offset.y += maxItemBottom + sectionPadding.bottom + sectionMargin.bottom
      self.cachedContentSize = CGSize(width: contentWidth, height: offset.y)
    }

    self.backgroundAttributes.removeAll()
    for section in 0..<collectionView.numberOfSections {
      let layoutAttributes = self.layoutAttributes.lazy.filter { $0.key.section == section }.map { $0.value }
      guard let minXAttribute = layoutAttributes.min(by: { $0.frame.minX < $1.frame.minX }) else { continue }
      guard let minYAttribute = layoutAttributes.min(by: { $0.frame.minY < $1.frame.minY }) else { continue }
      guard let maxXAttribute = layoutAttributes.max(by: { $0.frame.maxX < $1.frame.maxX }) else { continue }
      guard let maxYAttribute = layoutAttributes.max(by: { $0.frame.maxY < $1.frame.maxY }) else { continue }
      let (minX, minY) = (minXAttribute.frame.minX, minYAttribute.frame.minY)
      let (maxX, maxY) = (maxXAttribute.frame.maxX, maxYAttribute.frame.maxY)
      let (width, height) = (maxX - minX, maxY - minY)
      guard width > 0 && height > 0 else { continue }

      let sectionPadding = self.padding(forSectionAt: section)
      let attributes = UICollectionViewLayoutAttributes(
        forSupplementaryViewOfKind: UICollectionElementKindSectionBackground,
        with: IndexPath(item: 0, section: section)
      )
      let itemPaddingLeft = self.padding(forItemAt: minXAttribute.indexPath).left
      let itemPaddingTop = self.padding(forItemAt: minYAttribute.indexPath).top
      let itemPaddingRight = self.padding(forItemAt: maxXAttribute.indexPath).right
      let itemPaddingBottom = self.padding(forItemAt: maxYAttribute.indexPath).bottom
      attributes.frame = CGRect(
        x: minX - sectionPadding.left - itemPaddingLeft,
        y: minY - sectionPadding.top - itemPaddingTop,
        width: width + sectionPadding.left + sectionPadding.right + itemPaddingLeft + itemPaddingRight,
        height: height + sectionPadding.top + sectionPadding.bottom + itemPaddingTop + itemPaddingBottom
      )
      attributes.zIndex = -1
      self.backgroundAttributes[section] = attributes
    }
  }

  override open var collectionViewContentSize: CGSize {
    return self.cachedContentSize
  }

  override open func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    return self.layoutAttributes.values.filter { $0.frame.intersects(rect) }
      + self.backgroundAttributes.values.filter { $0.frame.intersects(rect) }
  }

  override open func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    return self.layoutAttributes[indexPath]
  }

  override open func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    guard elementKind == UICollectionElementKindSectionBackground else { return nil }
    guard indexPath.item == 0 else { return nil }
    return self.backgroundAttributes[indexPath.section]
  }

  open func maximumWidth(forItemAt indexPath: IndexPath) -> CGFloat {
    guard let collectionView = self.collectionView else { return 0 }
    let sectionMargin = self.margin(forSectionAt: indexPath.section)
    let sectionPadding = self.padding(forSectionAt: indexPath.section)
    let itemMargin = self.margin(forItemAt: indexPath)
    let itemPadding = self.padding(forItemAt: indexPath)
    return collectionView.frame.width
      - sectionMargin.left
      - sectionPadding.left
      - itemMargin.left
      - itemPadding.left
      - itemPadding.right
      - itemMargin.right
      - sectionPadding.right
      - sectionMargin.right
  }
}

extension UICollectionViewFlexLayout {
  var delegate: UICollectionViewDelegateFlexLayout? {
    return self.collectionView?.delegate as? UICollectionViewDelegateFlexLayout
  }

  func size(forItemAt indexPath: IndexPath) -> CGSize {
    guard let collectionView = self.collectionView, let delegate = self.delegate else { return .zero }
    return delegate.collectionView?(collectionView, layout: self, sizeForItemAt: indexPath) ?? .zero
  }

  func verticalSpacing(betweenSectionAt section: Int, and nextSection: Int) -> CGFloat {
    guard section != nextSection else { return 0 }
    guard let collectionView = self.collectionView, let delegate = self.delegate else { return 0 }
    return delegate.collectionView?(collectionView, layout: self, verticalSpacingBetweenSectionAt: section, and: nextSection) ?? 0
  }

  func margin(forSectionAt section: Int) -> UIEdgeInsets {
    guard let collectionView = self.collectionView, let delegate = self.delegate else { return .zero }
    return delegate.collectionView?(collectionView, layout: self, marginForSectionAt: section) ?? .zero
  }

  func padding(forSectionAt section: Int) -> UIEdgeInsets {
    guard let collectionView = self.collectionView, let delegate = self.delegate else { return .zero }
    return delegate.collectionView?(collectionView, layout: self, paddingForSectionAt: section) ?? .zero
  }

  func horizontalSpacing(betweenItemAt indexPath: IndexPath, and nextIndexPath: IndexPath) -> CGFloat {
    guard indexPath != nextIndexPath else { return 0 }
    guard let collectionView = self.collectionView, let delegate = self.delegate else { return 0 }
    return delegate.collectionView?(collectionView, layout: self, horizontalSpacingBetweenItemAt: indexPath, and: nextIndexPath) ?? 0
  }

  func verticalSpacing(betweenItemAt indexPath: IndexPath, and nextIndexPath: IndexPath) -> CGFloat {
    guard indexPath != nextIndexPath else { return 0 }
    guard let collectionView = self.collectionView, let delegate = self.delegate else { return 0 }
    return delegate.collectionView?(collectionView, layout: self, verticalSpacingBetweenItemAt: indexPath, and: nextIndexPath) ?? 0
  }

  func margin(forItemAt indexPath: IndexPath) -> UIEdgeInsets {
    guard let collectionView = self.collectionView, let delegate = self.delegate else { return .zero }
    return delegate.collectionView?(collectionView, layout: self, marginForItemAt: indexPath) ?? .zero
  }

  func padding(forItemAt indexPath: IndexPath) -> UIEdgeInsets {
    guard let collectionView = self.collectionView, let delegate = self.delegate else { return .zero }
    return delegate.collectionView?(collectionView, layout: self, paddingForItemAt: indexPath) ?? .zero
  }
}
#endif
