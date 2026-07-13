import SwiftUI
import SceneKit
import PhotosUI
import UIKit

struct ContentView: View {
    @State private var uiImages: [UIImage] = (0..<6).map { _ in UIImage(systemName: "photo")! }
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var autoRotate = true
    @State private var dragX: Float = 0.3
    @State private var dragY: Float = 0.6
    @State private var lastDragTranslation: CGSize = .zero

    var body: some View {
        VStack(spacing: 20) {
            Text("Photo Cube").font(.largeTitle.bold())

            CubeView(images: uiImages, autoRotate: autoRotate, dragX: dragX, dragY: dragY)
                .frame(height: 380)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(radius: 10)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            autoRotate = false
                            let deltaX = Float(value.translation.width - lastDragTranslation.width) * 0.01
                            let deltaY = Float(value.translation.height - lastDragTranslation.height) * 0.01
                            dragY += deltaX
                            dragX += deltaY
                            lastDragTranslation = value.translation
                        }
                        .onEnded { _ in
                            lastDragTranslation = .zero
                        }
                )
            
            HStack {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 6, matching:.images) {
                    Label("Choose 6 Photos", systemImage: "photo.on.rectangle.angled")
                }
                .buttonStyle(.borderedProminent)
                
                Button(autoRotate ? "Pause" : "Spin") {
                    autoRotate.toggle()
                }
                .buttonStyle(.bordered)
            }
            
            Text("Drag to rotate. Tap Spin to resume.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .onChange(of: pickerItems) { _, _ in
            Task { await loadImages() }
        }
    }
    
    func loadImages() async {
        var newImages: [UIImage] = []
        for item in pickerItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                newImages.append(img)
            }
        }
        if !newImages.isEmpty {
            var filled = newImages
            while filled.count < 6 {
                filled.append(contentsOf: newImages)
            }
            uiImages = Array(filled.prefix(6))
            autoRotate = true
        }
    }
}

struct CubeView: UIViewRepresentable {
    var images: [UIImage]
    var autoRotate: Bool
    var dragX: Float
    var dragY: Float

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.allowsCameraControl = false
        view.isUserInteractionEnabled = false
        view.autoenablesDefaultLighting = true
        view.backgroundColor = UIColor.systemBackground

        let scene = SCNScene()

        let box = SCNBox(width: 1.8, height: 1.8, length: 1.8, chamferRadius: 0.08)
        let node = SCNNode(geometry: box)
        node.name = "cube"
        scene.rootNode.addChildNode(node)

        let camera = SCNCamera()
        camera.fieldOfView = 30
        let camNode = SCNNode()
        camNode.camera = camera
        camNode.position = SCNVector3(0, 0, 5)
        scene.rootNode.addChildNode(camNode)

        view.scene = scene
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        guard let boxNode = view.scene?.rootNode.childNode(withName: "cube", recursively: false),
              let box = boxNode.geometry as? SCNBox else { return }

        box.materials = images.map { img in
            let m = SCNMaterial()
            m.diffuse.contents = img
            m.locksAmbientWithDiffuse = true
            return m
        }

        if autoRotate {
            boxNode.removeAllAnimations()
            boxNode.eulerAngles = SCNVector3(0, 0, 0)
            let spin = CABasicAnimation(keyPath: "rotation")
            spin.fromValue = NSValue(scnVector4: SCNVector4(0, 1, 0, 0))
            spin.toValue = NSValue(scnVector4: SCNVector4(0, 1, 0, Float.pi * 2))
            spin.duration = 8
            spin.repeatCount = .infinity
            boxNode.addAnimation(spin, forKey: "spin")
        } else {
            boxNode.removeAllAnimations()
            boxNode.eulerAngles.x = dragX
            boxNode.eulerAngles.y = dragY
        }
    }
}
