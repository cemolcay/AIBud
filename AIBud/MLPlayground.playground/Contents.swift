import Cocoa
import MusicTheorySwift
import CreateML
import CreateMLUI
import SwiftyJSON

extension Pitch: MLDataValueConvertible {
  public static var dataValueType: MLDataValue.ValueType {
    return .int
  }

  public init?(from dataValue: MLDataValue) {
    switch dataValue {
    case .int(let i) where i > 0:
      self = Pitch(midiNote: i)
    default:
      return nil
    }
  }

  public init() {
    self.init(midiNote: 0)
  }

  public var dataValue: MLDataValue {
    return .int(rawValue)
  }
}

extension Array {
  func unique<T:Hashable>(map: ((Element) -> (T)))  -> [Element] {
    var set = Set<T>() //the unique list kept in a Set for fast retrieval
    var arrayOrdered = [Element]() //keeping the unique list of elements but ordered
    for value in self {
      if !set.contains(map(value)) {
        set.insert(map(value))
        arrayOrdered.append(value)
      }
    }
    return arrayOrdered
  }
}

func generateAllScales() -> [Scale] {
  Accidental.shouldUseDoubleFlatAndDoubleSharpNotation = false
  let allKeys = (Key.keysWithFlats + Key.keysWithSharps)
    .unique(map: { $0.description })
    .sorted(by: { $0.type.rawValue + $0.accidental.rawValue <  $1.type.rawValue + $1.accidental.rawValue })
  let allScaleTypes = ScaleType.all
  return allKeys
    .map({ key in allScaleTypes.map({ type in Scale(type: type, key: key) }) })
    .flatMap({ $0 })
}

func generateJSONDataTable() {
  let allScales = generateAllScales()
  let jsonData: [[String: Any]] = allScales.enumerated().map({[
    "name": "\($0.element.key) \($0.element.type)",
    "index": $0.offset,
    "key": "\($0.element.key)",
    "keys": $0.element.keys.map{ $0.description },
    "pitches": $0.element.pitches(octaves: [Int](-1...8)).map{ $0.rawValue },
    "octave0": $0.element.pitches(octave: 0).map{ $0.rawValue },
    ]})
  let json = JSON(jsonData)
  try? json.rawString()?.write(
    to: URL(fileURLWithPath: "\(NSHomeDirectory())/Desktop/dataTable.json"),
    atomically: true,
    encoding: .utf8)
}

func generateMLDataTable() {
  let allScales = generateAllScales()
  let dataSource: [String: MLDataValueConvertible] = [
    "name": allScales.map({ "\($0.key) \($0.type)" }),
    "key": allScales.map({ "\($0.key)" }),
    "pitches": allScales.map({ $0.pitches(octaves: [Int](-1...8)) }),
    ]

  let dataTable = try? MLDataTable(dictionary: dataSource)
  try? dataTable?.description.write(
    to: URL(fileURLWithPath: "\(NSHomeDirectory())/Desktop/dataTable.txt"),
    atomically: true,
    encoding: .utf8)
}

func saveModel(testModel: Bool = false) {
  guard let dataTable = try? MLDataTable(contentsOf: URL(fileURLWithPath: "\(NSHomeDirectory())/Desktop/dataTable.json")) else { return }
  let (trainingData, testData) = dataTable.randomSplit(by: 0.8, seed: 5)

  do {
    // Create model
    let model = MLRegressor.decisionTree(try MLDecisionTreeRegressor(
      trainingData: trainingData,
      targetColumn: "index",
      featureColumns: ["octave0"]))

    // Metrics
    let metrics = model.evaluation(on: testData)

    // Prediction testing
    if testModel {
      if let cMajorPrediction = predictionData(scaleType: .major, keyType: .c, accidental: .natural) {
        try model.predictions(from: cMajorPrediction)
      }
      if let dSharpMinorPrediction = predictionData(scaleType: .minor, keyType: .d, accidental: .sharp) {
        try model.predictions(from: dSharpMinorPrediction)
      }
    }

    // Write model file
    try model.write(
      toFile: "\(NSHomeDirectory())/Desktop/model.mlmodel",
      metadata: MLModelMetadata(
        author: "Cem Olcay",
        shortDescription: "Music Theory Scale Predictor",
        license: "MIT",
        version: "0.0.1",
        additional: nil))

  } catch {
    print(error)
  }
}

func predictionData(scaleType: ScaleType, keyType: Key.KeyType, accidental: Accidental) -> MLDataTable? {
  let scale = Scale(type: scaleType, key: Key(type: keyType, accidental: accidental))
  let pitches = scale.pitches(octave: 0).map({ $0.rawValue })
  return try? MLDataTable(dictionary: [
    "octave0": pitches
  ])
}

generateJSONDataTable()
saveModel(testModel: false)
