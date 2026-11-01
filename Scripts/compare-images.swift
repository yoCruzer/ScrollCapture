import Foundation
import AppKit
import CryptoKit

// Independent image oracle CLI; does not import CaptureCore or its registration/crop code.
// Usage: swift Scripts/compare-images.swift actual.png expected.png x y width height
let args = CommandLine.arguments
guard args.count == 7, let x=Int(args[3]), let y=Int(args[4]), let w=Int(args[5]), let h=Int(args[6]),
      let actual=NSBitmapImageRep(contentsOfFile:args[1]), let expected=NSBitmapImageRep(contentsOfFile:args[2]),
      actual.pixelsWide == w, actual.pixelsHigh == h, x>=0, y>=0, w>0, h>0,
      x+w<=expected.pixelsWide, y+h<=expected.pixelsHigh else { fatalError("usage/dimensions mismatch") }
var total=0.0, maximum=0.0, bad=0, badRows=0
for row in 0..<h {
    var rowBad=false
    for column in 0..<w {
        guard let a=actual.colorAt(x:column,y:row)?.usingColorSpace(.sRGB),
              let b=expected.colorAt(x:x+column,y:y+row)?.usingColorSpace(.sRGB) else { fatalError("decode failure") }
        for d in [abs(a.redComponent-b.redComponent),abs(a.greenComponent-b.greenComponent),abs(a.blueComponent-b.blueComponent)] {
            let delta=Double(d)*255; total+=delta; maximum=max(maximum,delta)
            if delta>2.01 { bad+=1;rowBad=true }
        }
    }
    if rowBad { badRows+=1 }
}
let result:[String:Any] = ["width":w,"height":h,"referenceX":x,"referenceY":y,"maxChannelError":maximum,"meanChannelError":total/Double(w*h*3),"channelsOver2":bad,"badRows":badRows,"passed":bad==0]
print(String(data:try JSONSerialization.data(withJSONObject:result,options:[.sortedKeys,.prettyPrinted]),encoding:.utf8)!)
exit(bad==0 ? 0 : 1)
