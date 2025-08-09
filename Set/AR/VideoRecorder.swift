import Foundation
import AVFoundation
import UIKit
import RealityKit

class VideoRecorder: NSObject {
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var isRecording = false
    private var startTime: CMTime?
    private var videoURL: URL?
    
    override init() {
        super.init()
        setupVideoURL()
    }
    
    private func setupVideoURL() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoName = "workout_\(Date().timeIntervalSince1970).mp4"
        videoURL = documentsPath.appendingPathComponent(videoName)
    }
    
    func startRecording(completion: @escaping (Bool) -> Void) {
        guard !isRecording, let videoURL = videoURL else {
            completion(false)
            return
        }
        
        do {
            // Create asset writer
            assetWriter = try AVAssetWriter(url: videoURL, fileType: .mp4)
            
            // Configure video settings
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1920,
                AVVideoHeightKey: 1080
            ]
            
            // Create asset writer input
            assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            assetWriterInput?.expectsMediaDataInRealTime = true
            
            // Create pixel buffer adaptor for frame capture
            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: 1920,
                kCVPixelBufferHeightKey as String: 1080
            ]
            
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: assetWriterInput!,
                sourcePixelBufferAttributes: sourcePixelBufferAttributes
            )
            
            // Add input to writer
            if assetWriter!.canAdd(assetWriterInput!) {
                assetWriter!.add(assetWriterInput!)
            }
            
            // Start writing
            assetWriter!.startWriting()
            assetWriter!.startSession(atSourceTime: .zero)
            
            isRecording = true
            startTime = .zero
            
            print("Video recording started")
            completion(true)
            
        } catch {
            print("Failed to start video recording: \(error)")
            completion(false)
        }
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard isRecording else {
            completion(nil)
            return
        }
        
        isRecording = false
        
        assetWriterInput?.markAsFinished()
        assetWriter?.finishWriting { [weak self] in
            DispatchQueue.main.async {
                if let url = self?.videoURL {
                    print("Video recording completed: \(url)")
                    completion(url)
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    func captureFrame(from arView: ARView) {
        guard isRecording,
              let assetWriterInput = assetWriterInput,
              assetWriterInput.isReadyForMoreMediaData else {
            return
        }
        
        // Capture current frame from AR view
        arView.snapshot(saveToHDR: false) { [weak self] image in
            guard let image = image else { return }
            self?.captureFrame(image: image)
        }
    }
    
    func captureFrame(image: UIImage) {
        guard isRecording,
              let assetWriterInput = assetWriterInput,
              let pixelBufferAdaptor = pixelBufferAdaptor,
              assetWriterInput.isReadyForMoreMediaData else {
            return
        }
        
        // Convert UIImage to CVPixelBuffer
        guard let pixelBuffer = imageToPixelBuffer(image) else { return }
        
        let presentationTime = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 600)
        
        pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
    }
    
    private func imageToPixelBuffer(_ image: UIImage) -> CVPixelBuffer? {
        let width = 1920
        let height = 1080
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            return nil
        }
        
        // Draw image into context
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(image.cgImage!, in: rect)
        
        return buffer
    }
} 