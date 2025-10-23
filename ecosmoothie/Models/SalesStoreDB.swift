//
//  SalesStore.swift
//  ecosmoothie
//
//  Created by Freddy Morales on 22/10/25.
//

// SalesStore.swift
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
    // Exponer si quieres compartir una instancia
    static var shared: SalesStore?

    // Publicación para UI
    @Published private(set) var recentSales: [SaleRecord] = []
    @Published private(set) var totalToday: Double = 0
    @Published private(set) var totalThisWeek: Double = 0

    // Ruta de la DB y handle
    private let dbPath: String
    private var db: OpaquePointer?

    // MARK: - Init / Lifecycle
    init(path: String? = nil) {
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
            refreshAggregates()     // no lanza (maneja errores internamente)
        } catch {
            print("SalesStore init error:", error.localizedDescription)
        }
    }

    deinit { if let db { sqlite3_close(db) } }

    // MARK: - Public API

    func logSale(amount: Double, date: Date = Date()) {
        do {
            let id = try insert(amount: amount, date: date)
            recentSales.insert(.init(id: id, amount: amount, date: date), at: 0)
            refreshAggregates()
        } catch {
            print("logSale error:", error.localizedDescription)
            try? loadRecent(limit: 200)
            refreshAggregates()
        }
    }

    func reload() {
        do {
            try loadRecent(limit: 200)
            refreshAggregates()
        } catch {
            print("reload error:", error.localizedDescription)
        }
    }

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
            throw Self.makeError("No se pudo abrir la BD en \(dbPath)")
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
            let id  = sqlite3_column_int64(stmt, 0)
            let amt = sqlite3_column_double(stmt, 1)
            let ts  = sqlite3_column_double(stmt, 2)
            rows.append(.init(id: id, amount: amt, date: Date(timeIntervalSince1970: ts)))
        }
        recentSales = rows
    }

    private func deleteAll() throws {
        guard let db else { throw Self.makeError("DB no abierta") }
        if sqlite3_exec(db, "DELETE FROM sales;", nil, nil, nil) != SQLITE_OK {
            throw Self.makeError("DELETE FROM sales falló")
        }
    }

    /// Recalcula totales del día y de la semana (maneja errores, no lanza).
    func refreshAggregates() {
        do {
            totalToday = try dbTotalToday()
            totalThisWeek = try dbTotalThisWeek()
        } catch {
            print("SalesStore.refreshAggregates error:", error)
            totalToday = 0
            totalThisWeek = 0
        }
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

    // MARK: - 🔹 LO QUE FALTABA

    /// Total de HOY (de 00:00 a 24:00 locales)
    private func dbTotalToday() throws -> Double {
        let (start, end) = dayBounds(for: Date())
        return try sumBetween(start: start, end: end)
    }

    /// Total de ESTA SEMANA (inicio de semana según el Calendario del usuario)
    private func dbTotalThisWeek() throws -> Double {
        let (start, end) = weekBounds(for: Date())
        return try sumBetween(start: start, end: end)
    }

    /// Limites del día [00:00, 24:00) para una fecha dada
    private func dayBounds(for date: Date) -> (Date, Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    /// Limites de la semana [inicio, inicio+7d) para una fecha dada
    private func weekBounds(for date: Date) -> (Date, Date) {
        let cal = Calendar.current
        // Inicio de semana según configuración regional
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let start = cal.date(from: comps) ?? cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 7, to: start) ?? start
        return (start, end)
    }

    // MARK: - Utils
    private static func makeError(_ msg: String) -> NSError {
        NSError(domain: "SalesStore", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
    }
}
