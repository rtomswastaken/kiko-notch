import XCTest
@testable import KikoNotchKit

final class WakaTimeTests: XCTestCase {
    
    // MARK: - 1. JSON Response Decoding Tests
    
    func testWakaTimeAllTimeResponseDecoding() throws {
        let json = """
        {
          "data": {
            "daily_average": 7200.5,
            "decimal": "1250.45",
            "digital": "1250:27",
            "is_up_to_date": true,
            "text": "1,250 hrs 27 mins",
            "total_seconds": 4501627.84
          }
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(WakaTimeAllTimeResponse.self, from: json)
        XCTAssertNotNil(response.data)
        XCTAssertEqual(response.data?.total_seconds, 4501627.84)
        XCTAssertEqual(response.data?.text, "1,250 hrs 27 mins")
        XCTAssertEqual(response.data?.is_up_to_date, true)
    }
    
    func testWakaTimeSummariesResponseDecoding() throws {
        let json = """
        {
          "data": [
            {
              "grand_total": {
                "digital": "2:34",
                "hours": 2,
                "minutes": 34,
                "text": "2 hrs 34 mins",
                "total_seconds": 9240.0
              },
              "range": {
                "date": "2026-10-20",
                "text": "Tue Oct 20th, 2026",
                "start": "2026-10-20T00:00:00Z",
                "end": "2026-10-20T23:59:59Z"
              }
            },
            {
              "grand_total": {
                "digital": "4:15",
                "hours": 4,
                "minutes": 15,
                "text": "4 hrs 15 mins",
                "total_seconds": 15300.0
              },
              "range": {
                "date": "2026-10-19",
                "text": "Mon Oct 19th, 2026",
                "start": "2026-10-19T00:00:00Z",
                "end": "2026-10-19T23:59:59Z"
              }
            }
          ],
          "cumulative_total": {
            "total_seconds": 24540.0,
            "text": "6 hrs 49 mins"
          },
          "start": "2026-10-19T00:00:00Z",
          "end": "2026-10-20T23:59:59Z"
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(WakaTimeSummariesResponse.self, from: json)
        XCTAssertNotNil(response.data)
        XCTAssertEqual(response.data?.count, 2)
        XCTAssertEqual(response.data?.first?.grand_total?.total_seconds, 9240.0)
        XCTAssertEqual(response.data?.first?.range?.date, "2026-10-20")
        XCTAssertEqual(response.cumulative_total?.total_seconds, 24540.0)
    }
    
    func testWakaTimeUserResponseDecoding() throws {
        let json = """
        {
          "data": {
            "id": "user_12345",
            "username": "kikodev",
            "display_name": "Kiko Developer",
            "email": "dev@kiko.local"
          }
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(WakaTimeUserResponse.self, from: json)
        XCTAssertEqual(response.data?.username, "kikodev")
        XCTAssertEqual(response.data?.display_name, "Kiko Developer")
    }
    
    // MARK: - 2. Calculation & Formatting Tests
    
    func testDurationFormatting() {
        XCTAssertEqual(WakaTimeDayActivity.formatDuration(seconds: 0), "0m")
        XCTAssertEqual(WakaTimeDayActivity.formatDuration(seconds: -10), "0m")
        XCTAssertEqual(WakaTimeDayActivity.formatDuration(seconds: 45 * 60), "45m")
        XCTAssertEqual(WakaTimeDayActivity.formatDuration(seconds: 60 * 60), "1h")
        XCTAssertEqual(WakaTimeDayActivity.formatDuration(seconds: (2 * 3600) + (34 * 60)), "2h 34m")
        XCTAssertEqual(WakaTimeDayActivity.formatDuration(seconds: 842 * 3600), "842h")
    }
    
    func testIntensityClassification() {
        XCTAssertEqual(WakaTimeDayActivity.computeIntensity(seconds: 0), 0)
        XCTAssertEqual(WakaTimeDayActivity.computeIntensity(seconds: -100), 0)
        XCTAssertEqual(WakaTimeDayActivity.computeIntensity(seconds: 30 * 60), 1) // 30m < 1h
        XCTAssertEqual(WakaTimeDayActivity.computeIntensity(seconds: 2 * 3600), 2) // 2h < 3h
        XCTAssertEqual(WakaTimeDayActivity.computeIntensity(seconds: 4.5 * 3600), 3) // 4.5h < 6h
        XCTAssertEqual(WakaTimeDayActivity.computeIntensity(seconds: 8 * 3600), 4) // 8h >= 6h
    }
    
    // MARK: - 3. Heatmap 365 Days Date Boundary Tests
    
    func test365DaysDateRangeCalculation() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -364, to: today)!
        
        var generatedDays: [Date] = []
        for offset in 0..<365 {
            if let d = calendar.date(byAdding: .day, value: offset, to: startDate) {
                generatedDays.append(d)
            }
        }
        
        XCTAssertEqual(generatedDays.count, 365, "Must produce exactly 365 calendar days")
        XCTAssertEqual(generatedDays.last, today, "Last day must equal today")
    }
    
    // MARK: - 4. API Error Handling Tests
    
    func testWakaTimeAPIErrorDescriptions() {
        XCTAssertEqual(WakaTimeAPIError.unauthorized.errorDescription, "Unauthorized: Invalid API Key")
        XCTAssertEqual(WakaTimeAPIError.rateLimited.errorDescription, "WakaTime API rate limit exceeded")
        XCTAssertEqual(WakaTimeAPIError.invalidURL.errorDescription, "Invalid WakaTime URL")
        XCTAssertEqual(WakaTimeAPIError.invalidResponse.errorDescription, "Invalid server response")
        XCTAssertEqual(WakaTimeAPIError.httpError(500).errorDescription, "HTTP Error 500")
    }
    
    // MARK: - 5. Credential Masking & Storage Integration
    
    @MainActor
    func testWakaTimeCredentialHandling() {
        let service = WakaTimeService()
        
        // Save test key
        service.saveApiKey("waka_sec_test_1234567890abcdef")
        XCTAssertTrue(service.isConfigured)
        XCTAssertEqual(service.apiKey, "waka_sec_test_1234567890abcdef")
        XCTAssertTrue(service.maskedApiKey.contains("cdef"))
        XCTAssertFalse(service.maskedApiKey.contains("1234567890"))
        
        // Disconnect
        service.disconnect()
        XCTAssertFalse(service.isConfigured)
        XCTAssertNil(service.apiKey)
        XCTAssertEqual(service.stats, .empty)
    }
}
