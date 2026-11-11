import SwiftUI
import UIKit

/// Envoltorio de UIActivityViewController para compartir archivos.
struct HojaCompartir: UIViewControllerRepresentable {
    let elementos: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: elementos, applicationActivities: nil)
    }

    func updateUIViewController(_ controlador: UIActivityViewController, context: Context) {}
}

/// URL envuelta para usarla con `.sheet(item:)`.
struct ArchivoCompartido: Identifiable {
    let id = UUID()
    let url: URL
}
