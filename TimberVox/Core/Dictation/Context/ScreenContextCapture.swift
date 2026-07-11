import CoreGraphics
import Foundation
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers
import Vision

struct ScreenContextCaptureResult: Sendable {
  var text: String?
  var attachment: DictationContextAttachment?
}

enum ScreenContextCapture {
  static func capture(
    attachmentDirectory: URL?,
    capturedAt: Date,
    maxCharacters: Int = 12_000
  ) async -> ScreenContextCaptureResult {
    guard CGPreflightScreenCaptureAccess() else {
      return ScreenContextCaptureResult(text: nil, attachment: nil)
    }
    do {
      guard let image = try await captureImage() else {
        return ScreenContextCaptureResult(text: nil, attachment: nil)
      }
      return ScreenContextCaptureResult(
        text: recognizeText(in: image, maxCharacters: maxCharacters),
        attachment: saveImage(image, to: attachmentDirectory, capturedAt: capturedAt)
      )
    } catch {
      TimberVoxLog.dictation.error("Screen context capture failed: \(error.localizedDescription)")
      return ScreenContextCaptureResult(text: nil, attachment: nil)
    }
  }

  private static func captureImage() async throws -> CGImage? {
    let content = try await SCShareableContent.excludingDesktopWindows(
      false,
      onScreenWindowsOnly: true
    )
    guard let display = content.displays.first else { return nil }
    let filter = SCContentFilter(display: display, excludingWindows: [])
    filter.includeMenuBar = true
    let configuration = SCStreamConfiguration()
    configuration.width = display.width
    configuration.height = display.height
    configuration.showsCursor = false
    configuration.queueDepth = 1
    configuration.captureResolution = .best
    return try await SCScreenshotManager.captureImage(
      contentFilter: filter,
      configuration: configuration
    )
  }

  private static func recognizeText(in image: CGImage, maxCharacters: Int) -> String? {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .fast
    request.usesLanguageCorrection = true
    do {
      try VNImageRequestHandler(cgImage: image).perform([request])
    } catch {
      TimberVoxLog.dictation.error("Screen OCR failed: \(error.localizedDescription)")
      return nil
    }
    let text = request.results?
      .compactMap { $0.topCandidates(1).first?.string }
      .joined(separator: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let text, !text.isEmpty else { return nil }
    return String(text.prefix(maxCharacters))
  }

  private static func saveImage(
    _ image: CGImage,
    to directory: URL?,
    capturedAt: Date
  ) -> DictationContextAttachment? {
    guard let directory else { return nil }
    let filename = "screen-\(UUID().uuidString).png"
    let url = directory.appendingPathComponent(filename)
    guard
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
      )
    else { return nil }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { return nil }
    let byteCount = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
    return DictationContextAttachment(
      kind: .screenImage,
      uniformTypeIdentifier: UTType.png.identifier,
      filename: filename,
      byteCount: byteCount,
      localPath: url.path,
      capturedAt: capturedAt
    )
  }
}
