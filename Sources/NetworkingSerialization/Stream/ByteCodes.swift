//
//  ByteCodes.swift
//  PopNetworking
//
//  Named constants for the ASCII byte values used by the streaming serializers' line/event
//  parsing. Spelling these out (rather than `0x0A`) keeps the parsing code readable.
//

import Foundation

internal extension UInt8 {
    /// `\n` — line feed (LF). Line terminator on Unix, and the line separator in NDJSON and SSE.
    static let lineFeed: UInt8 = 0x0A

    /// `\r` — carriage return (CR). Pairs with LF to form CRLF line endings on Windows / HTTP.
    static let carriageReturn: UInt8 = 0x0D

    /// `:` — colon. Separates SSE field names from their values (`field: value`).
    static let colon: UInt8 = 0x3A

    /// ` ` — single space. Optional leading character on an SSE field value (per spec).
    static let space: UInt8 = 0x20
}

/// UTF-8 byte-order mark (`EF BB BF`). The SSE spec requires stripping a single BOM at the
/// start of the stream if present — some servers/proxies emit it.
internal let utf8BOM: [UInt8] = [0xEF, 0xBB, 0xBF]
