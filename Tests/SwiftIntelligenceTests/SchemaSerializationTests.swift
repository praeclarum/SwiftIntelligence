import XCTest
import FoundationModels
@testable import SwiftIntelligence

@Generable
struct TestOutput {
    var answer: String
    var confidence: Double
}

final class SchemaSerializationTests: XCTestCase {

    func testGenerableSchemaProducesValidJSON() throws {
        let json = try TestOutput.getJSONSchema()
        XCTAssertFalse(json.isEmpty)
        let data = json.data(using: .utf8)
        XCTAssertNotNil(data)
        let parsed = try JSONSerialization.jsonObject(with: data!) as? [String: Any]
        XCTAssertNotNil(parsed)
        XCTAssertNotNil(parsed?["type"])
    }

    func testGenerableSchemaContainsProperties() throws {
        let json = try TestOutput.getJSONSchema(outputFormatting: .prettyPrinted)
        XCTAssertTrue(json.contains("answer"))
        XCTAssertTrue(json.contains("confidence"))
    }

    func testSchemaJsonSchemaProperty() {
        let schema = TestOutput.generationSchema
        let json = schema.jsonSchema
        XCTAssertFalse(json.isEmpty)
        XCTAssertNotEqual(json, "{}")
    }
}
