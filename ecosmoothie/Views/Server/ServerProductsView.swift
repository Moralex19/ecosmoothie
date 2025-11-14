//
//  ServerProductsView.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 22/10/25.
//

import SwiftUI
import PhotosUI
import UIKit

struct ServerProductsView: View {
    @EnvironmentObject var products: ProductsStore
    @EnvironmentObject var socket: SocketService

    // Formulario nuevo producto
    @State private var newName: String = ""
    @State private var newImageName: String = "fresa2"
    @State private var newPriceText: String = ""
    @State private var newKind: Product.Kind = .smoothie

    // Foto desde galería para nuevo producto
    @State private var newPhotoItem: PhotosPickerItem?
    @State private var newPhotoData: Data?

    // Edición
    @State private var editingProduct: Product?

    // Atajos filtrados
    private var smoothies: [Product] {
        products.products.filter { $0.kind == .smoothie }
    }

    private var ingredients: [Product] {
        products.products.filter { $0.kind == .ingredient }
    }

    var body: some View {
        List {
            // MARK: - Alta de producto / ingrediente
            Section("Nuevo producto") {
                Picker("Tipo", selection: $newKind) {
                    Text("Batido").tag(Product.Kind.smoothie)
                    Text("Ingrediente").tag(Product.Kind.ingredient)
                }
                .pickerStyle(.segmented)

                TextField(
                    newKind == .smoothie ? "Nombre del batido" : "Nombre del ingrediente",
                    text: $newName
                )

                TextField("Precio", text: $newPriceText)
                    .keyboardType(.decimalPad)

                if newKind == .smoothie {
                    // Selector de foto desde galería
                    PhotosPicker(
                        selection: $newPhotoItem,
                        matching: .images
                    ) {
                        HStack {
                            Image(systemName: "photo")
                            Text("Seleccionar foto desde galería")
                        }
                    }

                    // Preview de la foto seleccionada
                    if let data = newPhotoData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        // Fallback: escribir nombre de asset manual si quieres
                        TextField("Imagen (asset) opcional", text: $newImageName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    addProduct()
                } label: {
                    Label("Agregar", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            // MARK: - Batidos
            Section("Batidos") {
                if smoothies.isEmpty {
                    Text("No hay batidos registrados.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(smoothies) { p in
                        HStack {
                            productImageView(for: p)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name)
                                Text(String(format: "$ %.2f", p.price))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                editingProduct = p
                            } label: {
                                Image(systemName: "pencil")
                            }

                            Button(role: .destructive) {
                                deleteProduct(p)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            // MARK: - Ingredientes
            Section("Ingredientes") {
                if ingredients.isEmpty {
                    Text("No hay ingredientes registrados.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ingredients) { p in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name)
                                Text(String(format: "$ %.2f", p.price))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                editingProduct = p
                            } label: {
                                Image(systemName: "pencil")
                            }

                            Button(role: .destructive) {
                                deleteProduct(p)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        //.navigationTitle("Productos")
        .sheet(item: $editingProduct) { product in
            EditProductSheet(product: product) { updated in
                // Actualizar en memoria
                products.updateLocal(updated)

                // Guardar en SQLite
                try? OrderDatabase.shared.upsertProduct(updated)

                // Mandar catálogo actualizado a clientes
                socket.sendCatalog(products.products)
            }
        }
        // Cargar la data cuando el usuario elige una foto nueva
        .onChange(of: newPhotoItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        newPhotoData = data
                    }
                }
            }
        }
    }

    // MARK: - Acciones

    private func addProduct() {
        let price = Double(newPriceText) ?? 0
        let name = newName.isEmpty ? "Nuevo" : newName

        // 1) decidir qué imagen vamos a guardar
        var imageToStoreName: String

        if newKind == .smoothie,
           let data = newPhotoData,
           let filename = saveImageToDisk(data) {
            // Foto desde galería → guardamos en disco y usamos el nombre del archivo
            imageToStoreName = filename
        } else {
            // Fallback: texto del asset
            imageToStoreName = newImageName.isEmpty ? "fresa2" : newImageName
        }

        let product = Product(
            id: UUID().uuidString,
            name: name,
            imageName: imageToStoreName,
            price: price,
            kind: newKind
        )

        // 1) agregar localmente
        products.appendLocal(product)

        // 2) guardar en SQLite
        try? OrderDatabase.shared.upsertProduct(product)

        // 3) mandar catálogo a clientes
        socket.sendCatalog(products.products)

        // 4) limpiar formulario
        newName = ""
        newPriceText = ""
        newImageName = "fresa2"
        newKind = .smoothie
        newPhotoData = nil
        newPhotoItem = nil
    }

    private func deleteProduct(_ p: Product) {
        if let idx = products.products.firstIndex(where: { $0.id == p.id }) {
            products.removeLocal(at: IndexSet(integer: idx))
            try? OrderDatabase.shared.deleteProduct(id: p.id)
            socket.sendCatalog(products.products)
        }
    }

    /// Devuelve una `Image` para el producto, intentando primero cargar desde disco y luego como asset.
    private func productImageView(for product: Product) -> some View {
        Group {
            if let uiImage = loadImageFromDisk(named: product.imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(product.imageName)
                    .resizable()
                    .scaledToFill()
            }
        }
    }
}

// MARK: - Sheet de edición

struct EditProductSheet: View {
    @Environment(\.dismiss) private var dismiss

    let product: Product
    let onSave: (Product) -> Void

    @State private var name: String
    @State private var imageName: String
    @State private var priceText: String

    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?

    init(product: Product, onSave: @escaping (Product) -> Void) {
        self.product = product
        self.onSave = onSave

        _name = State(initialValue: product.name)
        _imageName = State(initialValue: product.imageName)
        _priceText = State(initialValue: product.price > 0 ? String(format: "%.2f", product.price) : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        product.kind == .smoothie ? "Nombre del batido" : "Nombre del ingrediente",
                        text: $name
                    )

                    TextField("Precio", text: $priceText)
                        .keyboardType(.decimalPad)

                    if product.kind == .smoothie {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Foto")
                                .font(.subheadline)

                            // Preview
                            if let data = photoData,
                               let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else if let uiImage = loadImageFromDisk(named: product.imageName) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                Image(product.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            PhotosPicker(
                                selection: $photoItem,
                                matching: .images
                            ) {
                                HStack {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("Cambiar foto desde galería")
                                }
                            }

                            TextField("Imagen (asset) opcional", text: $imageName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            //.navigationTitle("Editar producto")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let price = Double(priceText) ?? 0
                        var updated = product
                        updated.name = name
                        updated.price = price

                        if updated.kind == .smoothie {
                            if let data = photoData,
                               let filename = saveImageToDisk(data) {
                                updated.imageName = filename
                            } else {
                                updated.imageName = imageName.isEmpty ? product.imageName : imageName
                            }
                        }

                        onSave(updated)
                        dismiss()
                    }
                }
            }
            .onChange(of: photoItem) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            photoData = data
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    let store = ProductsStore()
    store._setPreviewProducts([
        Product(id: "p-maracuya", name: "Batido de maracuyá", imageName: "fresa2", price: 35, kind: .smoothie),
        Product(id: "i-gomita", name: "Gomita", imageName: "fresa2", price: 5, kind: .ingredient),
        Product(id: "i-picafresa", name: "Picafresa", imageName: "fresa2", price: 5, kind: .ingredient)
    ])

    return NavigationStack {
        ServerProductsView()
            .environmentObject(store)
            .environmentObject(SocketService())
    }
}

// MARK: - Helpers de archivos para imágenes de productos

func productImagesDirectory() -> URL {
    let fm = FileManager.default
    let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
    let dir = docs.appendingPathComponent("ProductImages", isDirectory: true)

    if !fm.fileExists(atPath: dir.path) {
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    return dir
}

func saveImageToDisk(_ data: Data) -> String? {
    let filename = UUID().uuidString + ".jpg"
    let url = productImagesDirectory().appendingPathComponent(filename)
    do {
        try data.write(to: url)
        print("✅ Imagen guardada en: \(url.path)")
        return filename
    } catch {
        print("❌ Error guardando imagen: \(error)")
        return nil
    }
}

func loadImageFromDisk(named filename: String) -> UIImage? {
    let url = productImagesDirectory().appendingPathComponent(filename)
    return UIImage(contentsOfFile: url.path)
}
