import Foundation

public extension KeyedDecodingContainer where K == AnyCodingKey {
    func decode<Value: Decodable>(type: Value.Type,
                                  keys: [String],
                                  nestedKeys: [String]) throws -> Value {
        //前边的有值优先使用
        for key in nestedKeys {
            if let value = tryNestedKeyDecode(type: type, key: key) {
                return value
            }
        }
        for key in keys {
            if let value = tryNormalKeyDecode(type: type, key: key) {
                return value
            }
        }
        // if Value is Optional，return nil
        if let valueType = Value.self as? ExpressibleByNilLiteral.Type {
            return valueType.init(nilLiteral: ()) as! Value
        }

        throw CodableWrapperError("decode failure: keys: \(keys), nestedKeys: \(nestedKeys)")
    }
}

private extension KeyedDecodingContainer where K == AnyCodingKey {
    func tryNormalKeyDecode<Value>(type: Value.Type, key: String) -> Value? {
        func _decode(key: String) -> Value? {
            guard let key = Key(stringValue: key) else {
                return nil
            }
            let value = try? decodeIfPresent(AnyDecodable.self, forKey: key)?.value
            if let value = value {
                if let converted = value as? Value {
                    return converted
                }
                if let _bridged = (Value.self as? _BuiltInBridgeType.Type)?._transform(from: value), let __bridged = _bridged as? Value {
                    return __bridged
                }
                if let valueType = Value.self as? Decodable.Type {
                    if let value = try? valueType.decode(from: self, forKey: key) as? Value {
                        return value
                    }
                }
            }
            return nil
        }
        //_ 和 不带 _ 两种都算
        for newKey in [key, key.snakeCamelConvert()].compactMap({ $0 }) {
            if let value = _decode(key: newKey) {
                return value
            }
        }
        return nil
    }

    private func tryNestedKeyDecode<Value>(type: Value.Type, key: String) -> Value? {
        var keyComps = key.components(separatedBy: ".")
        guard let rootKey = AnyCodingKey(stringValue: keyComps.removeFirst()) else {
            return nil
        }
        var container: KeyedDecodingContainer<AnyCodingKey>?
        container = try? nestedContainer(keyedBy: AnyCodingKey.self, forKey: rootKey)
        let lastKey = keyComps.removeLast()
        for keyComp in keyComps {
            container = try? container?.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .init(stringValue: keyComp)!)
        }
        if let container = container {
            if let value = container.tryNormalKeyDecode(type: type, key: lastKey) {
                return value
            }
        }
        return nil
    }
}

private extension Decodable {
    static func decode<K>(from container: KeyedDecodingContainer<K>, forKey key: KeyedDecodingContainer<K>.Key) throws -> Self {
        return try container.decode(Self.self, forKey: key)
    }
}
