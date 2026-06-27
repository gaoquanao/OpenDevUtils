import Cocoa
import Foundation

func createAppIcon() {
    let size = NSSize(width: 1024, height: 1024)
    let image = NSImage(size: size)
    
    image.lockFocus()
    
    let ctx = NSGraphicsContext.current!.cgContext
    
    // Background - dark gradient
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(red: 0.11, green: 0.11, blue: 0.18, alpha: 1.0),
        CGColor(red: 0.18, green: 0.18, blue: 0.28, alpha: 1.0)
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                          start: CGPoint(x: 0, y: size.height),
                          end: CGPoint(x: 0, y: 0),
                          options: [])
    
    // Draw angle brackets < / >
    let bracketFont = CTFontCreateWithName("SF Mono Bold" as CFString, 380, nil)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: bracketFont,
        .foregroundColor: CGColor(red: 0.3, green: 0.85, blue: 0.6, alpha: 1.0)
    ]
    
    // <
    let lessStr = NSAttributedString(string: "<", attributes: attrs)
    let lessSize = lessStr.size()
    lessStr.draw(at: CGPoint(x: 120, y: 300))
    
    // >
    let greaterStr = NSAttributedString(string: ">", attributes: attrs)
    greaterStr.draw(at: CGPoint(x: size.width - lessSize.width - 120, y: 300))
    
    // Slash /
    let slashAttrs: [NSAttributedString.Key: Any] = [
        .font: bracketFont,
        .foregroundColor: CGColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
    ]
    let slashStr = NSAttributedString(string: "/", attributes: slashAttrs)
    let slashSize = slashStr.size()
    slashStr.draw(at: CGPoint(x: (size.width - slashSize.width) / 2, y: 300))
    
    // "dev" text at bottom
    let devFont = CTFontCreateWithName("SF Mono Bold" as CFString, 80, nil)
    let devAttrs: [NSAttributedString.Key: Any] = [
        .font: devFont,
        .foregroundColor: CGColor(red: 0.9, green: 0.9, blue: 0.95, alpha: 1.0)
    ]
    let devStr = NSAttributedString(string: "devUtils", attributes: devAttrs)
    let devSize = devStr.size()
    devStr.draw(at: CGPoint(x: (size.width - devSize.width) / 2, y: 120))
    
    image.unlockFocus()
    
    // Save as PNG
    let tiffData = image.tiffRepresentation!
    let bitmapRep = NSBitmapImageRep(data: tiffData)!
    let pngData = bitmapRep.representation(using: .png, properties: [:])!
    
    let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
    try! pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Icon saved to \(outputPath)")
}

createAppIcon()
