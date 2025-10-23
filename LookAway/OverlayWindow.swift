import AppKit

class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return false
    }

    // Tạo window borderless mà vẫn có thể key window
    override init(contentRect: NSRect,
         styleMask: NSWindow.StyleMask,
         backing: NSWindow.BackingStoreType,
         defer flag: Bool) {
        
        super.init(contentRect: contentRect,
                   styleMask: styleMask,
                   backing: backing,
                   defer: flag)
        
        // Đặt thêm thuộc tính để nó không chiếm focus hoàn toàn
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        
        // Có thể join tất cả desktop, hiện ở trên cùng, biến mất nhanh
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .transient]
        
        self.ignoresMouseEvents = false
    }
}
