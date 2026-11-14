import AppKit
let root = CommandLine.arguments[1]
let folder = root + "/Prism.iconset"
try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let px = size * scale
        let image = NSImage(size: NSSize(width: px, height: px))
        image.lockFocus()
        let s = CGFloat(px)
        NSColor(calibratedRed: 11/255, green: 11/255, blue: 13/255, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: s*0.04, y:s*0.04, width:s*0.92, height:s*0.92), xRadius:s*0.21, yRadius:s*0.21).fill()
        let triangle = NSBezierPath()
        triangle.move(to: NSPoint(x:s*0.5,y:s*0.79)); triangle.line(to:NSPoint(x:s*0.2,y:s*0.23)); triangle.line(to:NSPoint(x:s*0.8,y:s*0.23)); triangle.close()
        NSColor(calibratedRed: 36/255, green:57/255, blue:1, alpha:1).setFill(); triangle.fill()
        let slash = NSBezierPath(); slash.move(to: NSPoint(x:s*0.5,y:s*0.79)); slash.line(to:NSPoint(x:s*0.5,y:s*0.23)); slash.line(to:NSPoint(x:s*0.8,y:s*0.23)); slash.close()
        NSColor(calibratedRed:241/255,green:241/255,blue:239/255,alpha:1).setFill(); slash.fill()
        image.unlockFocus()
        let rep = NSBitmapImageRep(data:image.tiffRepresentation!)!
        let suffix = scale == 2 ? "@2x" : ""
        try rep.representation(using:.png,properties:[:])!.write(to: URL(fileURLWithPath:folder+"/icon_\(size)x\(size)\(suffix).png"))
    }
}
let process = Process(); process.executableURL = URL(fileURLWithPath:"/usr/bin/iconutil")
process.arguments = ["-c","icns",folder,"-o",root+"/Prism.icns"]
try process.run(); process.waitUntilExit(); exit(process.terminationStatus)
