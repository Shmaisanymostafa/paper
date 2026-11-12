// Aspect-preserving platform packaging of the owner-approved originals.
// Does not redraw, crop, recolor or change artwork.
import AppKit
let root = URL(fileURLWithPath: CommandLine.arguments[1])
func render(_ source: String, _ destination: String, _ size: Int, opaque: Bool = false) throws {
  let input = NSImage(contentsOf: root.appendingPathComponent(source))!
  let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  bitmap.size = NSSize(width: size, height: size)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  if opaque { NSColor.white.setFill(); NSRect(x: 0,y: 0,width: size,height: size).fill() }
  let ratio = min(Double(size) / input.size.width, Double(size) / input.size.height)
  let width = input.size.width * ratio, height = input.size.height * ratio
  input.draw(in: NSRect(x: (Double(size)-width)/2,y: (Double(size)-height)/2,width: width,height: height),
    from: .zero, operation: .sourceOver, fraction: 1)
  NSGraphicsContext.restoreGraphicsState()
  let target = root.appendingPathComponent(destination)
  try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
  var output = bitmap
  if opaque {
    let bytes = Data(bytes: bitmap.bitmapData!, count: bitmap.bytesPerRow * size)
    let provider = CGDataProvider(data: bytes as CFData)!
    let rgb = CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32,
      bytesPerRow: bitmap.bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
      provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    output = NSBitmapImageRep(cgImage: rgb)
  }
  try output.representation(using: .png, properties: [:])!.write(to: target)
}
for platform in ["macos", "ios"] {
  let folder = "\(platform)/Runner/Assets.xcassets/AppIcon.appiconset"
  let json = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent(folder+"/Contents.json"))) as! [String: Any]
  for entry in json["images"] as! [[String: String]] {
    guard let file = entry["filename"], let dimension = entry["size"]?.split(separator: "x").first,
      let points = Double(dimension), let scale = Double(entry["scale"]!.dropLast()) else { continue }
    try render("assets/branding/app-logo.png", folder+"/"+file, Int(points*scale), opaque: platform == "ios")
  }
}
for (density,size) in [("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)] {
  try render("assets/branding/app-logo.png", "android/app/src/main/res/mipmap-\(density)/ic_launcher.png", size)
}
try render("assets/branding/app-logo.png", "linux/packaging/technology.cave.paper.png", 512)
for size in [16,32,48,64,128,256] {
  try render("assets/branding/app-logo.png", "evidence/local/icon-packaging/app-\(size).png", size)
  try render("assets/branding/pdf-icon.png", "evidence/local/icon-packaging/pdf-\(size).png", size)
}
