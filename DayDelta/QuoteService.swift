import Foundation

/// Fetches a live price from Yahoo Finance's public v8 chart endpoint — no API
/// key, one endpoint for US/TW stocks, crypto (BTC-USD), and commodities (GC=F).
/// Fails soft: returns nil on any error so the manual price is kept.
/// ponytail: unofficial endpoint; parsing is the pure `parseQuotePrice` (tested).
enum QuoteService {
    static func price(for symbol: String) async -> Decimal? {
        let s = symbol.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty,
              let encoded = s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)")
        else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 10
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }
        return parseQuotePrice(data)
    }

    /// Live gold price in TWD per 台兩: international gold (GC=F, USD/oz) × USD→TWD.
    static func goldPricePerTael() async -> Decimal? {
        async let oz = price(for: "GC=F")
        async let fx = price(for: "TWD=X")   // USD→TWD
        guard let usdPerOz = await oz, let usdTwd = await fx else { return nil }
        return goldTWDPerTael(usdPerOz: usdPerOz, usdTwd: usdTwd)
    }

    /// A Yahoo `range` string wide enough to cover a window plus the one before it.
    private static func range(forDays days: Int) -> String {
        switch days { case ...7: return "1mo"; case ...30: return "3mo"; default: return "6mo" }
    }

    /// Daily close history for a symbol (ascending). Fail-soft → [].
    static func history(for symbol: String, days: Int) async -> [(date: Date, close: Decimal)] {
        let s = symbol.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty,
              let encoded = s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?range=\(range(forDays: days))&interval=1d")
        else { return [] }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 12
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return [] }
        return parseChartSeries(data)
    }

    /// Daily gold history in TWD per 兩 (international GC=F × current USD→TWD).
    static func goldHistory(days: Int) async -> [(date: Date, close: Decimal)] {
        async let ozHist = history(for: "GC=F", days: days)
        async let fx = price(for: "TWD=X")
        let series = await ozHist
        guard let usdTwd = await fx, !series.isEmpty else { return [] }
        return series.map { ($0.date, goldTWDPerTael(usdPerOz: $0.close, usdTwd: usdTwd)) }
    }
}
