import AppKit

// Independent native NSScrollView displaying an immutable sRGB bitmap oracle.
// This renderer does not import CaptureCore or know the production matcher/ledger.
@MainActor
final class OracleView: NSView {
    let source: NSImage
    init(image: NSImage) { source=image; super.init(frame:NSRect(origin:.zero,size:image.size)) }
    required init?(coder:NSCoder) { fatalError() }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect:NSRect) {
        source.draw(in:bounds,from:.zero,operation:.copy,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.none])
    }
}
@MainActor
final class OracleDelegate:NSObject,NSApplicationDelegate {
    var window:NSWindow!
    var scroll:NSScrollView!
    func applicationDidFinishLaunching(_ notification:Notification) {
        let url=Bundle.main.url(forResource:"oracle",withExtension:"png")!
        guard let rep=NSBitmapImageRep(data:try! Data(contentsOf:url)),let cg=rep.cgImage else { fatalError("invalid oracle") }
        let image=NSImage(cgImage:cg,size:NSSize(width:rep.pixelsWide,height:rep.pixelsHigh))
        window=NSWindow(contentRect:NSRect(x:160,y:140,width:760,height:560),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        scroll=NSScrollView(frame:NSRect(x:0,y:0,width:760,height:560));scroll.hasVerticalScroller=false
        scroll.documentView=OracleView(image:image);scroll.contentView.postsBoundsChangedNotifications=true
        window.contentView=scroll
        NotificationCenter.default.addObserver(self,selector:#selector(changed),name:NSView.boundsDidChangeNotification,object:scroll.contentView)
        changed();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    @objc func changed() { window.title="ScrollCapture Native Oracle · y=\(Int(scroll.contentView.bounds.minY))" }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {true}
}
@main
struct Host {
 @MainActor static func main() {
  let delegate=OracleDelegate(), app=NSApplication.shared
  app.setActivationPolicy(.regular);app.delegate=delegate;app.run()
 }
}
