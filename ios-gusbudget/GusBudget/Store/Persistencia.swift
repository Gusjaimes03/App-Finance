import Foundation

/// Guarda y lee todo como un JSON dentro de la app. Nada sale del teléfono.
struct Persistencia {
    static let shared = Persistencia()

    let archivo: URL

    private let codificador: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decodificador: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(nombre: String = "miplata.json") {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())

        let carpeta = base.appendingPathComponent("GusBudget", isDirectory: true)
        if !FileManager.default.fileExists(atPath: carpeta.path) {
            try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        }
        archivo = carpeta.appendingPathComponent(nombre)
    }

    func cargar() -> AppData? {
        guard FileManager.default.fileExists(atPath: archivo.path) else { return nil }
        do {
            return try decodificador.decode(AppData.self, from: Data(contentsOf: archivo))
        } catch {
            // Si el archivo está dañado se aparta en vez de perderlo en silencio.
            let copia = archivo.deletingPathExtension()
                .appendingPathExtension("dañado-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: archivo, to: copia)
            return nil
        }
    }

    func guardar(_ data: AppData) throws {
        try codificador.encode(data).write(to: archivo, options: .atomic)
    }

    func archivoDeRespaldo(_ data: AppData) throws -> URL {
        let nombre = "MiPlata-respaldo-\(Self.sello.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nombre)
        try codificador.encode(data).write(to: url, options: .atomic)
        return url
    }

    func archivoCSV(_ texto: String) throws -> URL {
        let nombre = "MiPlata-\(Self.sello.string(from: Date())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nombre)
        var datos = Data([0xEF, 0xBB, 0xBF]) // BOM para que Excel respete las tildes
        datos.append(Data(texto.utf8))
        try datos.write(to: url, options: .atomic)
        return url
    }

    func importar(_ url: URL) throws -> AppData {
        let conPermiso = url.startAccessingSecurityScopedResource()
        defer { if conPermiso { url.stopAccessingSecurityScopedResource() } }
        return try decodificador.decode(AppData.self, from: Data(contentsOf: url))
    }

    static let sello: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return f
    }()
}
