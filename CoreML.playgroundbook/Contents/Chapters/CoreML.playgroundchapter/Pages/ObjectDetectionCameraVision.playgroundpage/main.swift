import ARKit
import PlaygroundSupport
import UIKit
import Vision

//載入模型
let config = MLModelConfiguration()
config.allowLowPrecisionAccumulationOnGPU = true
config.computeUnits = .all
let model = try compileModel(at:  #fileLiteral(resourceName: "YOLOv3TinyInt8LUT.mlmodel"), configuration: config)

//設定模型的特徵
model.featureProvider = try MLDictionaryFeatureProvider(dictionary: [
    "iouThreshold": 0.5,
    //如上輸入0-1之間的數字, 推薦0.3
    "confidenceThreshold": ,
])

//設定模型文字顏色
let bboxColor =  #colorLiteral(red: 0.46274495124816895, green: 0.7333332896232605, blue: 0.2509804368019104, alpha: 1.0)
let textColor =  #colorLiteral(red: -1.3499370652425569e-06, green: 0.3803921639919281, blue: 0.9960785508155823, alpha: 1.0)



































// ViewControllers
final class ViewController: PreviewViewController {
    let bboxLayer = CALayer()

    lazy var request: VNCoreMLRequest = {
        let request = VNCoreMLRequest(model: model, completionHandler: self.processDetections)
        request.imageCropAndScaleOption = .scaleFill
        return request
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.arView.session.delegate = self

        self.view.layer.addSublayer(self.bboxLayer)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.bboxLayer.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
    }

    func detect(imageBuffer: CVImageBuffer, orientation: CGImagePropertyOrientation) {
        try! VNImageRequestHandler(cvPixelBuffer: imageBuffer, orientation: orientation)
            .perform([self.request])
    }

    func processDetections(for request: VNRequest, error: Error?) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)

        // Remove all bboxes
        self.bboxLayer.sublayers = nil

        request.results?
            .lazy
            .compactMap { $0 as? VNRecognizedObjectObservation }
            .forEach {
                let imgSize = self.bboxLayer.bounds.size;
                let bbox = VNImageRectForNormalizedRect($0.boundingBox, Int(imgSize.width), Int(imgSize.height))
                let cls = $0.labels[0]

                // Render a bounding box
                let shapeLayer = CALayer()
                shapeLayer.borderColor = bboxColor.cgColor
                shapeLayer.borderWidth = 2
                shapeLayer.bounds = bbox
                shapeLayer.position = CGPoint(x: bbox.midX, y: bbox.midY)

                // Render a description
                let textLayer = CATextLayer()
                textLayer.string = "\(cls.identifier): \(cls.confidence)"
                textLayer.font = UIFont.preferredFont(forTextStyle: .body)
                textLayer.bounds = CGRect(x: 0, y: 0, width: bbox.width - 10, height: bbox.height - 10)
                textLayer.position = CGPoint(x: bbox.midX, y: bbox.midY)
                textLayer.foregroundColor = textColor.cgColor
                textLayer.contentsScale = 2.0 // Retina Display
                textLayer.setAffineTransform(CGAffineTransform(scaleX: 1, y: -1))

                shapeLayer.addSublayer(textLayer)
                self.bboxLayer.addSublayer(shapeLayer)
            }

        CATransaction.commit()
    }
}

extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let imageBuffer = frame.capturedImage

        let orientation = CGImagePropertyOrientation(interfaceOrientation: UIScreen.main.orientation)

        var size = CVImageBufferGetDisplaySize(imageBuffer)
        if orientation == .right || orientation == .left {
            size = CGSize(width: size.height, height: size.width)
        }
        let scale = self.view.bounds.size / size
        let maxScale = fmax(scale.width, scale.height)
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        self.bboxLayer.setAffineTransform(CGAffineTransform(scaleX: maxScale, y: -maxScale))
        self.bboxLayer.bounds = CGRect(origin: .zero, size: size)
        self.bboxLayer.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        CATransaction.commit()

        self.detect(imageBuffer: imageBuffer, orientation: orientation)
    }
}

PlaygroundPage.current.wantsFullScreenLiveView = true
PlaygroundPage.current.liveView = ViewController()
