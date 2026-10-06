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
}
