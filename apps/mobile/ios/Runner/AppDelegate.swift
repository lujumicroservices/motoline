import AVFoundation
import Flutter
import Foundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let reelEncoder = ReelEncoderHost()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.motoline.motoline/reel_encoder",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.reelEncoder.handle(call: call, result: result)
    }
  }
}

final class ReelEncoderHost {
  private let queue = DispatchQueue(label: "com.motoline.reel-encoder")
  private var writer: AVAssetWriter?
  private var input: AVAssetWriterInput?
  private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
  private var width = 720
  private var height = 1280
  private var fps = 12
  private var frameIndex: Int64 = 0

  func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    queue.async {
      do {
        switch call.method {
        case "start":
          guard let args = call.arguments as? [String: Any],
                let path = args["path"] as? String else {
            throw ReelError.badArgs
          }
          self.width = args["width"] as? Int ?? 720
          self.height = args["height"] as? Int ?? 1280
          self.fps = args["fps"] as? Int ?? 12
          try self.start(path: path)
          self.ok(result)
        case "addFrame":
          let data: Data
          if let args = call.arguments as? [String: Any],
             let typed = args["bytes"] as? FlutterStandardTypedData {
            data = typed.data
          } else if let typed = call.arguments as? FlutterStandardTypedData {
            data = typed.data
          } else {
            throw ReelError.badArgs
          }
          try self.addFrame(data)
          self.ok(result)
        case "finish":
          try self.finish()
          self.ok(result)
        default:
          DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "reel", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func ok(_ result: @escaping FlutterResult) {
    DispatchQueue.main.async { result(nil) }
  }

  private func start(path: String) throws {
    finishQuiet()
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.removeItem(at: url)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let writer = try AVAssetWriter(url: url, fileType: .mp4)
    let settings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 3_500_000,
        AVVideoExpectedSourceFrameRateKey: fps,
      ],
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
      ]
    )
    writer.add(input)
    guard writer.startWriting() else {
      throw writer.error ?? ReelError.badArgs
    }
    writer.startSession(atSourceTime: .zero)
    self.writer = writer
    self.input = input
    self.adaptor = adaptor
    self.frameIndex = 0
  }

  private func addFrame(_ rgba: Data) throws {
    guard let input, let adaptor, writer != nil else {
      throw ReelError.notStarted
    }
    var spins = 0
    while !input.isReadyForMoreMediaData && spins < 200 {
      Thread.sleep(forTimeInterval: 0.01)
      spins += 1
    }
    var buffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      kCVPixelFormatType_32BGRA,
      [
        kCVPixelBufferIOSurfacePropertiesKey as String: [:],
      ] as CFDictionary,
      &buffer
    )
    guard status == kCVReturnSuccess, let pixel = buffer else {
      throw ReelError.badArgs
    }
    CVPixelBufferLockBaseAddress(pixel, [])
    defer { CVPixelBufferUnlockBaseAddress(pixel, []) }
    guard let dest = CVPixelBufferGetBaseAddress(pixel) else {
      throw ReelError.badArgs
    }
    let stride = CVPixelBufferGetBytesPerRow(pixel)
    rgba.withUnsafeBytes { raw in
      guard let src = raw.bindMemory(to: UInt8.self).baseAddress else { return }
      for y in 0..<height {
        let rowSrc = src.advanced(by: y * width * 4)
        let rowDst = dest.advanced(by: y * stride).assumingMemoryBound(to: UInt8.self)
        for x in 0..<width {
          let i = x * 4
          rowDst[i] = rowSrc[i + 2]
          rowDst[i + 1] = rowSrc[i + 1]
          rowDst[i + 2] = rowSrc[i]
          rowDst[i + 3] = rowSrc[i + 3]
        }
      }
    }
    let pts = CMTime(value: frameIndex, timescale: CMTimeScale(fps))
    if !adaptor.append(pixel, withPresentationTime: pts) {
      throw writer?.error ?? ReelError.badArgs
    }
    frameIndex += 1
  }

  private func finish() throws {
    guard let writer, let input else { return }
    input.markAsFinished()
    let sem = DispatchSemaphore(value: 0)
    var finishError: Error?
    writer.finishWriting {
      finishError = writer.error
      sem.signal()
    }
    sem.wait()
    if let finishError { throw finishError }
    self.writer = nil
    self.input = nil
    self.adaptor = nil
  }

  private func finishQuiet() {
    try? finish()
  }
}

private enum ReelError: LocalizedError {
  case badArgs
  case notStarted

  var errorDescription: String? {
    switch self {
    case .badArgs: return "bad encoder args"
    case .notStarted: return "encoder not started"
    }
  }
}
