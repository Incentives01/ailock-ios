import SwiftUI
import AVFoundation

struct QRScannerView: View {
    @EnvironmentObject var homeViewModel: HomeViewModel
    @State private var scannedCode: String?
    @State private var scannerResetId = UUID()
    @State private var hasCameraPermission: Bool?

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if homeViewModel.activeSession != nil {
                    // Already clocked in
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.green)
                        Text("Already Clocked In")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Clock out first before scanning a new QR code.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if hasCameraPermission == false {
                    noCameraView
                } else if homeViewModel.showClockInConfirmation, let payload = homeViewModel.scannedPayload {
                    ClockInConfirmationView(payload: payload)
                        .environmentObject(homeViewModel)
                } else {
                    scannerView
                }
            }
            .navigationTitle("Scan QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await checkCameraPermission()
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Scanner

    private var scannerView: some View {
        VStack(spacing: 24) {
            Spacer()

            QRCameraView { code in
                guard scannedCode == nil else { return }
                scannedCode = code
                homeViewModel.processQRCode(data: code)
            }
            .id(scannerResetId)
            .frame(height: 350)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "3B82F6").opacity(0.5), lineWidth: 2)
            )
            .padding(.horizontal)

            Text("Point your camera at a location QR code")
                .font(.subheadline)
                .foregroundColor(.gray)

            if let error = homeViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)

                Button("Scan Again") {
                    scannedCode = nil
                    scannerResetId = UUID()
                    homeViewModel.errorMessage = nil
                }
                .foregroundColor(Color(hex: "3B82F6"))
            }

            Spacer()
        }
    }

    // MARK: - No Camera

    private var noCameraView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("Camera Access Required")
                .font(.headline)
                .foregroundColor(.white)
            Text("Enable camera access in Settings to scan QR codes.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .foregroundColor(Color(hex: "3B82F6"))
        }
        .padding()
    }

    private func checkCameraPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasCameraPermission = true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            hasCameraPermission = granted
        default:
            hasCameraPermission = false
        }
    }
}

// MARK: - QR Camera View (AVFoundation)

struct QRCameraView: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onCodeScanned = onCodeScanned
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            showError()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview

        captureSession = session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let session = captureSession
        DispatchQueue.global(qos: .userInitiated).async { session?.stopRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = obj.stringValue else { return }
        hasScanned = true
        captureSession?.stopRunning()
        onCodeScanned?(code)
    }

    private func showError() {
        let label = UILabel()
        label.text = "Camera not available"
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.frame = view.bounds
        view.addSubview(label)
    }
}
