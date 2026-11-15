import SwiftUI
import CaptureCore

struct RegionPreview: View {
    let raster: Raster
    @Binding var region: CGRect?
    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / CGFloat(raster.width), proxy.size.height / CGFloat(raster.height))
            let w = CGFloat(raster.width)*scale, h = CGFloat(raster.height)*scale
            ZStack(alignment: .topLeading) {
                if let image = try? raster.image() { Image(decorative: image, scale: 1).resizable().interpolation(.none).frame(width:w,height:h) }
                if let r = region {
                    Path { path in
                        path.addRect(CGRect(x: 0, y: 0, width: w, height: h))
                        path.addRect(CGRect(x: r.minX*scale, y: r.minY*scale, width: r.width*scale, height: r.height*scale))
                    }.fill(.black.opacity(0.38), style: FillStyle(eoFill: true))
                    Rectangle().fill(.clear).overlay(Rectangle().stroke(.white,lineWidth:3))
                        .overlay(Rectangle().stroke(Color.accentColor,style:StrokeStyle(lineWidth:1.5,dash:[6,3])))
                        .frame(width:r.width*scale,height:r.height*scale).offset(x:r.minX*scale,y:r.minY*scale)
                }
            }.frame(width:w,height:h).contentShape(Rectangle())
                .accessibilityLabel("截图范围预览，在画面中拖动选择正文")
                .gesture(DragGesture(minimumDistance: 2).onChanged { value in
                    let x0 = floor(max(0,min(CGFloat(raster.width),min(value.startLocation.x,value.location.x)/scale)))
                    let y0 = floor(max(0,min(CGFloat(raster.height),min(value.startLocation.y,value.location.y)/scale)))
                    let x1 = ceil(max(0,min(CGFloat(raster.width),max(value.startLocation.x,value.location.x)/scale)))
                    let y1 = ceil(max(0,min(CGFloat(raster.height),max(value.startLocation.y,value.location.y)/scale)))
                    if x1>x0 && y1>y0 { region = CGRect(x:x0,y:y0,width:x1-x0,height:y1-y0) }
                })
        }.frame(minHeight: 180, maxHeight: .infinity)
    }
}
