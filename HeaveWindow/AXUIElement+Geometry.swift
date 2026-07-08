import Cocoa

extension AXUIElement {
    var position: CGPoint? {
        guard let value = axValue(attribute: kAXPositionAttribute) else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else { return nil }
        return point
    }

    var size: CGSize? {
        guard let value = axValue(attribute: kAXSizeAttribute) else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else { return nil }
        return size
    }

    func setPosition(_ point: CGPoint) {
        var point = point
        if let value = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(self, kAXPositionAttribute as CFString, value)
        }
    }

    func setSize(_ size: CGSize) {
        var size = size
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(self, kAXSizeAttribute as CFString, value)
        }
    }

    private func axValue(attribute: String) -> AXValue? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &value) == .success,
            let value = value
        else {
            return nil
        }
        return (value as! AXValue)
    }
}
