//
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

    // MARK: - Apertura de base de datos

    private func openDatabase() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory,
                                                  in: .userDomainMask).first else {
            print("❌ No se encontró el directorio de documentos")
            return
        }

        let dbURL = documentsURL.appendingPathComponent("orders.sqlite")

        let result = sqlite3_open(dbURL.path, &db)
        if result != SQLITE_OK {
            if let db = db, let errorMsg = sqlite3_errmsg(db) {
                print("❌ No se pudo abrir la base de datos: \(String(cString: errorMsg))")
            } else {
                print("❌ No se pudo abrir la base de datos en \(dbURL.path)")
            }
            db = nil
        } else {
            print("✅ Base de datos de pedidos en: \(dbURL.path)")
        }
    }

    // MARK: - Creación de tablas

    private func createTablesIfNeeded() {
        guard let db = db else { return }

        let createOrdersSQL = """
        CREATE TABLE IF NOT EXISTS orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            total REAL NOT NULL,
            customer_name TEXT
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
            if let errorMsg = sqlite3_errmsg(db) {
                print("❌ Error creando tabla orders: \(String(cString: errorMsg))")
            } else {
                print("❌ Error creando tabla orders")
            }
        }

        // 🔹 MIGRACIÓN: asegurar que la columna customer_name exista
        ensureCustomerNameColumn()

        if sqlite3_exec(db, createItemsSQL, nil, nil, nil) != SQLITE_OK {
            if let errorMsg = sqlite3_errmsg(db) {
                print("❌ Error creando tabla order_items: \(String(cString: errorMsg))")
            } else {
                print("❌ Error creando tabla order_items")
            }
        }
        if sqlite3_exec(db, createSalesSQL, nil, nil, nil) != SQLITE_OK {
            if let errorMsg = sqlite3_errmsg(db) {
                print("❌ Error creando tabla sales: \(String(cString: errorMsg))")
            } else {
                print("❌ Error creando tabla sales")
            }
        }
        if sqlite3_exec(db, createProductsSQL, nil, nil, nil) != SQLITE_OK {
            if let errorMsg = sqlite3_errmsg(db) {
                print("❌ Error creando tabla products: \(String(cString: errorMsg))")
            } else {
                print("❌ Error creando tabla products")
            }
        }
    }

    /// MIGRACIÓN: agrega la columna `customer_name` a `orders` si no existe
    private func ensureCustomerNameColumn() {
        guard let db = db else { return }

        let pragmaSQL = "PRAGMA table_info(orders);"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, pragmaSQL, -1, &stmt, nil) != SQLITE_OK {
            if let errorMsg = sqlite3_errmsg(db) {
                print("❌ Error en PRAGMA table_info(orders): \(String(cString: errorMsg))")
            }
            return
        }

        var hasCustomerName = false

        while sqlite3_step(stmt) == SQLITE_ROW {
            // columna 1 = name
            if let cName = sqlite3_column_text(stmt, 1) {
                let name = String(cString: cName)
                if name == "customer_name" {
                    hasCustomerName = true
                    break
                }
            }
        }

        sqlite3_finalize(stmt)

        if !hasCustomerName {
            let alterSQL = "ALTER TABLE orders ADD COLUMN customer_name TEXT;"
            if sqlite3_exec(db, alterSQL, nil, nil, nil) != SQLITE_OK {
                if let errorMsg = sqlite3_errmsg(db) {
                    print("❌ Error agregando columna customer_name: \(String(cString: errorMsg))")
                } else {
                    print("❌ Error agregando columna customer_name")
                }
            } else {
                print("✅ Columna customer_name agregada a orders")
            }
        } else {
            print("ℹ️ Columna customer_name ya existe en orders")
        }
    }

    // MARK: - Errores

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
    /// Incluye `customerName`.
    func saveOrder(items: [CartItem], total: Double, customerName: String?) throws {
        guard let db = db else {
            print("❌ Base de datos no inicializada")
            return
        }

        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)

        // 1. Encabezado
        let insertOrderSQL = """
        INSERT INTO orders (created_at, total, customer_name)
        VALUES (?, ?, ?);
        """

        var orderStmt: OpaquePointer?

        if sqlite3_prepare_v2(db, insertOrderSQL, -1, &orderStmt, nil) != SQLITE_OK {
            if let errorMsg = sqlite3_errmsg(db) {
                print("❌ Error prepare INSERT orders: \(String(cString: errorMsg))")
            }
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            throw DatabaseError.prepare
        }

        let formatter = ISO8601DateFormatter()
        let nowString = formatter.string(from: Date())

        sqlite3_bind_text(orderStmt, 1, (nowString as NSString).utf8String, -1, nil)
        sqlite3_bind_double(orderStmt, 2, total)

        let cleanName = customerName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name = cleanName, !name.isEmpty {
            sqlite3_bind_text(orderStmt, 3, (name as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(orderStmt, 3)
        }

        if sqlite3_step(orderStmt) != SQLITE_DONE {
            if let errorMsg = sqlite3_errmsg(db) {
                print("❌ Error step INSERT orders: \(String(cString: errorMsg))")
            }
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
        if sqlite3_prepare_v2(db, insertItemSQL, -1, &itemStmt, nil) != SQLITE_OK {
            if let errorMsg = sqlite3_errmsg(db) {
                print("❌ Error prepare INSERT order_items: \(String(cString: errorMsg))")
            }
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            throw DatabaseError.prepare
        }

        for item in items {
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
                if let errorMsg = sqlite3_errmsg(db) {
                    print("❌ Error step INSERT order_items: \(String(cString: errorMsg))")
                }
                sqlite3_finalize(itemStmt)
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                throw DatabaseError.insertItem
            }
        }

        sqlite3_finalize(itemStmt)
        sqlite3_exec(db, "COMMIT", nil, nil, nil)
        print("✅ Pedido guardado en SQLite (order_id = \(orderId))")
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
        if sqlite3_prepare_v2(db, insertSaleSQL, -1, &stmt, nil) != SQLITE_OK {
            if let errorMsg = sqlite3_errmsg(db) {
                print("❌ Error prepare INSERT sales: \(String(cString: errorMsg))")
            }
            throw DatabaseError.prepare
        }

        let formatter = ISO8601DateFormatter()
        let nowString = formatter.string(from: Date())

        sqlite3_bind_text(stmt, 1, (order.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (nowString as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 3, order.total)

        if sqlite3_step(stmt) != SQLITE_DONE {
            if let errorMsg = sqlite3_errmsg(db) {
                print("❌ Error step INSERT sales: \(String(cString: errorMsg))")
            }
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
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            if let errorMsg = sqlite3_errmsg(db) {
                print("❌ Error prepare UPSERT products: \(String(cString: errorMsg))")
            }
            throw DatabaseError.prepare
        }

        sqlite3_bind_text(stmt, 1, (product.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (product.name as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (product.imageName as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 4, product.price)
        sqlite3_bind_text(stmt, 5, (product.kind.rawValue as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) != SQLITE_DONE {
            if let errorMsg = sqlite3_errmsg(db) {
                print("❌ Error step UPSERT products: \(String(cString: errorMsg))")
            }
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

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            if let errorMsg = sqlite3_errmsg(db) {
                print("❌ Error prepare DELETE products: \(String(cString: errorMsg))")
            }
            throw DatabaseError.prepare
        }

        sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) != SQLITE_DONE {
            if let errorMsg = sqlite3_errmsg(db) {
                print("❌ Error step DELETE products: \(String(cString: errorMsg))")
            }
            sqlite3_finalize(stmt)
            throw DatabaseError.deleteProduct
        }

        sqlite3_finalize(stmt)
        print("🗑️ Producto eliminado con id \(id)")
    }
}
