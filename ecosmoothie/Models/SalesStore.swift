//
//  SalesStore.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 22/10/25.
//

// SalesStore.swift
import Foundation
import SQLite3
import Combine

public struct SaleRecord: Identifiable, Hashable {
    public let id: Int64
    public let amount: Double
    public let date: Date
}

@MainActor
final class SalesStore: ObservableObject {
    // Publicación para UI
    @Published private(set) var recentSales: [SaleRecord] = []
    @Published private(set) var totalToday: Double = 0
    @Published private(set) var totalThisWeek: Double = 0

    // Ruta de la DB y handle
    private let dbPath: String
    private var db: OpaquePointer?

    // Conveniencia para inyectar en otros stores si quieres
    static var shared: SalesStore?

    // MARK: - Init / Lifecycle

    /// Crea (o abre) la BD en Documents/sales.sqlite3 por defecto.
    init(path: String? = nil) {
        // Ruta por defecto en Documents
        if let path {
            self.dbPath = path
        } else {
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.dbPath = dir.appendingPathComponent("sales.sqlite3").path
        }

        Self.shared = self

        do {
            try openDB()
            try createTableIfNeeded()
            try loadRecent(limit: 200)
            try refreshAggregates()
        } catch {
            print("SalesStore init error:", error.localizedDescription)
        }
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    // MARK: - Public API

    /// Registra una venta (monto en la moneda actual) con fecha opcional (default: ahora).
    func logSale(amount: Double, date: Date = Date()) {
        do {
            let id = try insert(amount: amount, date: date)
            // Optimista: actualiza UI sin recargar todo
            let record = SaleRecord(id: id, amount: amount, date: date)
            recentSales.insert(record, at: 0)

            try refreshAggregates()
        } catch {
            print("logSale error:", error.localizedDescription)
            // Como fallback, recarga todo
            try? loadRecent(limit: 200)
            try? refreshAggregates()
        }
    }

    /// Recarga la lista de ventas recientes desde SQLite (para listas/tabla).
    func reload() {
        do {
            try loadRecent(limit: 200)
            try refreshAggregates()
        } catch {
            print("reload error:", error.localizedDescription)
        }
    }

    /// Elimina TODAS las ventas (útil para pruebas).
    func resetAll() {
        do {
            try deleteAll()
            recentSales.removeAll()
            totalToday = 0
            totalThisWeek = 0
        } catch {
            print("resetAll error:", error.localizedDescription)
        }
    }

    // MARK: - SQLite (privado)

    private func openDB() throws {
        var handle: OpaquePointer?
        if sqlite3_open(dbPath, &handle) == SQLITE_OK {
            db = handle
        } else {
            throw NSError(domain: "SQLite", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No se pudo abrir la BD en \(dbPath)"])
        }
    }

    private func createTableIfNeeded() throws {
        guard let db else { throw Self.makeError("DB no abierta") }
        let sql = """
        CREATE TABLE IF NOT EXISTS sales(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            ts REAL NOT NULL
        );
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            throw Self.makeError("No se pudo crear la tabla 'sales'")
        }
    }

    @discardableResult
    private func insert(amount: Double, date: Date) throws -> Int64 {
        guard let db else { throw Self.makeError("DB no abierta") }
        let sql = "INSERT INTO sales(amount, ts) VALUES(?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw Self.makeError("INSERT prepare falló")
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, amount)
        sqlite3_bind_double(stmt, 2, date.timeIntervalSince1970)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw Self.makeError("INSERT step falló")
        }
        return sqlite3_last_insert_rowid(db)
    }

    private func loadRecent(limit: Int) throws {
        guard let db else { throw Self.makeError("DB no abierta") }
        let sql = "SELECT id, amount, ts FROM sales ORDER BY ts DESC LIMIT ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw Self.makeError("SELECT prepare falló")
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(limit))

        var rows: [SaleRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id   = sqlite3_column_int64(stmt, 0)
            let amt  = sqlite3_column_double(stmt, 1)
            let ts   = sqlite3_column_double(stmt, 2)
            rows.append(SaleRecord(id: id, amount: amt, date: Date(timeIntervalSince1970: ts)))
        }
        self.recentSales = rows
    }

    private func deleteAll() throws {
        guard let db else { throw Self.makeError("DB no abierta") }
        if sqlite3_exec(db, "DELETE FROM sales;", nil, nil, nil) != SQLITE_OK {
            throw Self.makeError("DELETE FROM sales falló")
        }
    }

    /// Recalcula totales del día y de la semana vía `SUM(amount)` en SQLite.
    public func refreshAggregates() throws {
        totalToday = try sumBetween(start: Calendar.current.startOfDay(for: Date()),
                                    end: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!)

        let week = Calendar.current.dateInterval(of: .weekOfYear, for: Date())
                    ?? DateInterval(start: Date(), duration: 0)
        totalThisWeek = try sumBetween(start: week.start, end: week.end)
    }

    /// SUM(amount) BETWEEN [start, end)
    private func sumBetween(start: Date, end: Date) throws -> Double {
        guard let db else { throw Self.makeError("DB no abierta") }
        let sql = "SELECT COALESCE(SUM(amount), 0) FROM sales WHERE ts >= ? AND ts < ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw Self.makeError("SUM prepare falló")
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, start.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 2, end.timeIntervalSince1970)

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw Self.makeError("SUM step falló")
        }
        return sqlite3_column_double(stmt, 0)
    }

    // MARK: - Utils

    private static func makeError(_ msg: String) -> NSError {
        NSError(domain: "SalesStore", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
    }
}
