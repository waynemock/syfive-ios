//
//  Logger.swift
//  SyFLUX
//
//  Created by Wayne Mock on 1/25/19.
//  Copyright © 2020 Syzygy Softwerks LLC. All rights reserved.
//

import Foundation
import os.log

/// Thread-safe logger that uses Swift's unified logging system.
///
/// Usage:
/// ```swift
/// private let logger = AppLogger(category: "MyClass")
///
/// logger.debug(self, "Debug message")
/// logger.info(self, "Info message")
/// logger.error(self, "Error message")
/// ```
struct AppLogger: Sendable {
	private let logger: Logger
	private let category: String

    /// Named output sinks invoked after every log entry with (category, level, formattedMessage).
    /// Register sinks at app startup before logging begins; do not mutate from concurrent contexts.
    nonisolated(unsafe) static var sinks: [String: (String, String, String) -> Void] = [:]

	/// Creates a new logger instance.
	///
	/// - Parameters:
	///   - subsystem: The subsystem identifier (defaults to app bundle ID)
	///   - category: A category for organizing logs (typically the class/file name)
	nonisolated init(subsystem: String = Bundle.main.bundleIdentifier ?? "com.syzygy", category: String) {
		self.logger = Logger(subsystem: subsystem, category: category)
		self.category = category
	}

	/// Logs a debug message.
	nonisolated func debug(_ object: Any, _ message: String, functionName: String = #function) {
		let typeName = String(describing: type(of: object))
		let formatted = "\(typeName).\(functionName): \(message)"
		logger.debug("\(formatted)")
		Self.sinks.values.forEach { $0(category, "DBG", formatted) }
	}

	/// Logs an info message.
	nonisolated func info(_ object: Any, _ message: String, functionName: String = #function) {
		let typeName = String(describing: type(of: object))
		let formatted = "\(typeName).\(functionName): \(message)"
		logger.info("\(formatted)")
		Self.sinks.values.forEach { $0(category, "INF", formatted) }
	}

	/// Logs a warning message.
	nonisolated func warning(_ object: Any, _ message: String, functionName: String = #function) {
		let typeName = String(describing: type(of: object))
		let formatted = "\(typeName).\(functionName): \(message)"
		logger.warning("\(formatted)")
		Self.sinks.values.forEach { $0(category, "WRN", formatted) }
	}

	/// Logs an error message.
	nonisolated func error(_ object: Any, _ message: String, functionName: String = #function) {
		let typeName = String(describing: type(of: object))
		let formatted = "\(typeName).\(functionName): \(message)"
		logger.error("\(formatted)")
		Self.sinks.values.forEach { $0(category, "ERR", formatted) }
	}

	/// Logs a verbose/trace message.
	nonisolated func verbose(_ object: Any, _ message: String, functionName: String = #function) {
		let typeName = String(describing: type(of: object))
		let formatted = "\(typeName).\(functionName): \(message)"
		logger.debug("\(formatted)")
		Self.sinks.values.forEach { $0(category, "VRB", formatted) }
	}
}
