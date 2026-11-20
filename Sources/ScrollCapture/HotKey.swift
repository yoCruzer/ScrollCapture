import AppKit
import Carbon

@MainActor
final class HotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: () -> Void = {}
    func configure(keyCode: UInt32?) -> Bool {
        if let reference { UnregisterEventHotKey(reference) }; reference = nil
        if handler == nil {
            var type = EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed))
            let pointer = Unmanaged.passUnretained(self).toOpaque()
            InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
                guard let context else { return OSStatus(eventNotHandledErr) }
                MainActor.assumeIsolated { Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue().action() }
                return noErr
            },1,&type,pointer,&handler)
        }
        guard let keyCode else { return true }
        return RegisterEventHotKey(keyCode,UInt32(cmdKey|controlKey|optionKey),EventHotKeyID(signature:0x5343524C,id:1),GetApplicationEventTarget(),0,&reference) == noErr
    }
}
