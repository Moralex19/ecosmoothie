//  OrderDatabase.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 21/10/25.
//

import Foundation
import SQLite3

/// Maneja el almacenamiento de pedidos en SQLite
final class OrderDatabase {
    static let shared = OrderDatabase()

    private var db: OpaquePointer?

    private init() {
        openDatabase()
        createTablesIfNeeded()
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    private func openDatabase() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory,
                                                  in: .userDomainMask).first else {
            print("❌ No se encontró el directorio de documentos")
            return
        }

        let dbURL = documentsURL.appendingPathComponent("orders.sqlite")

        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            print("❌ No se pudo abrir la base de datos en \(dbURL.path)")
            db = nil
        } else {
            print("✅ Base de datos de pedidos en: \(dbURL.path)")
        }
    }

    private func createTablesIfNeeded() {
        guard let db = db else { return }

        let createOrdersSQL = """
        CREATE TABLE IF NOT EXISTS orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            total REAL NOT NULL
        );
        """

        let createItemsSQL = """
        CREATE TABLE IF NOT EXISTS order_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            product_name TEXT NOT NULL,
            base_price REAL NOT NULL,
            extras TEXT,
            extras_cost REAL NOT NULL,
            line_total REAL NOT NULL,
            FOREIGN KEY(order_id) REFERENCES orders(id)
        );
        """

        let createSalesSQL = """
        CREATE TABLE IF NOT EXISTS sales (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_identifier TEXT NOT NULL,
            created_at TEXT NOT NULL,
            total REAL NOT NULL
        );
        """

        let createProductsSQL = """
        CREATE TABLE IF NOT EXISTS products (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            image_name TEXT,
            price REAL NOT NULL,
            kind TEXT NOT NULL
        );
        """

        if sqlite3_exec(db, createOrdersSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ Error creando tabla orders")
        }

        if sqlite3_exec(db, createItemsSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ Error creando tabla order_items")
        }

        if sqlite3_exec(db, createSalesSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ Error creando tabla sales")
        }

        if sqlite3_exec(db, createProductsSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ Error creando tabla products")
        }
    }

    enum DatabaseError: Error {
        case prepare
        case insertOrder
        case insertItem
        case insertSale
        case upsertProduct
        case deleteProduct
    }

    // MARK: - Pedidos

    /// Guarda un pedido completo (encabezado + detalle) en SQLite.
    /// Se llama únicamente cuando el usuario paga y envía el pedido.
    func saveOrder(items: [CartItem], total: Double) throws {
        guard let db = db else {
            print("❌ Base de datos no inicializada")
            return
        }

        // Iniciar transacción para asegurar atomicidad
        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)

        // 1. Encabezado
        let insertOrderSQL = "INSERT INTO orders (created_at, total) VALUES (?, ?);"
        var orderStmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, insertOrderSQL, -1, &orderStmt, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            throw DatabaseError.prepare
        }

        let formatter = ISO8601DateFormatter()
        let nowString = formatter.string(from: Date())

        sqlite3_bind_text(orderStmt, 1, (nowString as NSString).utf8String, -1, nil)
        sqlite3_bind_double(orderStmt, 2, total)

        if sqlite3_step(orderStmt) != SQLITE_DONE {
            sqlite3_finalize(orderStmt)
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            throw DatabaseError.insertOrder
        }

        let orderId = sqlite3_last_insert_rowid(db)
        sqlite3_finalize(orderStmt)

        // 2. Detalle (cada batido + extras)
        let insertItemSQL = """
        INSERT INTO order_items
        (order_id, product_name, base_price, extras, extras_cost, line_total)
        VALUES (?, ?, ?, ?, ?, ?);
        """

        var itemStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertItemSQL, -1, &itemStmt, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            throw DatabaseError.prepare
        }

        for item in items {
            // 👇 AHORA usamos ingredient.name, porque IngredientCount ya no tiene `kind`
            let extrasDescription = item.ingredients
                .map { ingredient in
                    let name = ingredient.name
                    return "\(name) x\(ingredient.count)"
                }
                .joined(separator: ", ")

            let extrasCost = item.ingredients.reduce(0) { $0 + $1.subtotal }

            sqlite3_reset(itemStmt)
            sqlite3_clear_bindings(itemStmt)

            sqlite3_bind_int64(itemStmt, 1, orderId)
            sqlite3_bind_text(itemStmt, 2, (item.product.name as NSString).utf8String, -1, nil)
            sqlite3_bind_double(itemStmt, 3, item.basePrice)
            sqlite3_bind_text(itemStmt, 4, (extrasDescription as NSString).utf8String, -1, nil)
            sqlite3_bind_double(itemStmt, 5, extrasCost)
            sqlite3_bind_double(itemStmt, 6, item.total)

            if sqlite3_step(itemStmt) != SQLITE_DONE {
                sqlite3_finalize(itemStmt)
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                throw DatabaseError.insertItem
            }
        }

        sqlite3_finalize(itemStmt)
        sqlite3_exec(db, "COMMIT", nil, nil, nil)
    }

    // MARK: - Ventas

    func saveSale(for order: ServerOrder) throws {
        guard let db = db else {
            print("❌ Base de datos no inicializada")
            return
        }

        let insertSaleSQL = """
        INSERT INTO sales (order_identifier, created_at, total)
        VALUES (?, ?, ?);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSaleSQL, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepare
        }

        let formatter = ISO8601DateFormatter()
        let nowString = formatter.string(from: Date())

        sqlite3_bind_text(stmt, 1, (order.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (nowString as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 3, order.total)

        if sqlite3_step(stmt) != SQLITE_DONE {
            sqlite3_finalize(stmt)
            throw DatabaseError.insertSale
        }

        sqlite3_finalize(stmt)
        print("✅ Venta guardada para pedido \(order.id) por total \(order.total)")
    }

    // MARK: - Catálogo de productos

    func upsertProduct(_ product: Product) throws {
        guard let db = db else {
            print("❌ Base de datos no inicializada")
            return
        }

        let sql = """
        INSERT INTO products (id, name, image_name, price, kind)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            image_name = excluded.image_name,
            price = excluded.price,
            kind = excluded.kind;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepare
        }

        sqlite3_bind_text(stmt, 1, (product.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (product.name as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (product.imageName as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 4, product.price)
        sqlite3_bind_text(stmt, 5, (product.kind.rawValue as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) != SQLITE_DONE {
            sqlite3_finalize(stmt)
            throw DatabaseError.upsertProduct
        }

        sqlite3_finalize(stmt)
        print("✅ Producto guardado/actualizado: \(product.name)")
    }

    func deleteProduct(id: String) throws {
        guard let db = db else {
            print("❌ Base de datos no inicializada")
            return
        }

        let sql = "DELETE FROM products WHERE id = ?;"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepare
        }

        sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) != SQLITE_DONE {
            sqlite3_finalize(stmt)
            throw DatabaseError.deleteProduct
        }

        sqlite3_finalize(stmt)
        print("🗑️ Producto eliminado con id \(id)")
    }
}
