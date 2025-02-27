////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import Foundation
import Realm
import Realm.Private

/// :nodoc:
/// Internal class. Do not use directly.
public class ListBase: RLMListBase {
    // Printable requires a description property defined in Swift (and not obj-c),
    // and it has to be defined as override, which can't be done in a
    // generic class.
    /// Returns a human-readable description of the objects contained in the List.
    @objc public override var description: String {
        return descriptionWithMaxDepth(RLMDescriptionMaxDepth)
    }

    @objc private func descriptionWithMaxDepth(_ depth: UInt) -> String {
        return RLMDescriptionWithMaxDepth("List", _rlmArray, depth)
    }

    /// Returns the number of objects in this List.
    public var count: Int { return Int(_rlmArray.count) }
}

/**
 `List` is the container type in Realm used to define to-many relationships.

 Like Swift's `Array`, `List` is a generic type that is parameterized on the type it stores. This can be either an `Object`
 subclass or one of the following types: `Bool`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`, `Float`, `Double`, `String`, `Data`,
 and `Date` (and their optional versions)

 Unlike Swift's native collections, `List`s are reference types, and are only immutable if the Realm that manages them
 is opened as read-only.

 Lists can be filtered and sorted with the same predicates as `Results<Element>`.

 Properties of `List` type defined on `Object` subclasses must be declared as `let` and cannot be `dynamic`.
 */
public final class List<Element: RealmCollectionValue>: ListBase {

    // MARK: Properties

    /// The Realm which manages the list, or `nil` if the list is unmanaged.
    public var realm: Realm? {
        return _rlmArray.realm.map { Realm($0) }
    }

    /// Indicates if the list can no longer be accessed.
    public var isInvalidated: Bool { return _rlmArray.isInvalidated }

    // MARK: Initializers

    /// Creates a `List` that holds Realm model objects of type `Element`.
    public override init() {
        super.init(array: Element._rlmArray())
    }

    internal init(rlmArray: RLMArray<AnyObject>) {
        super.init(array: rlmArray)
    }

    // MARK: Index Retrieval

    /**
     Returns the index of an object in the list, or `nil` if the object is not present.

     - parameter object: An object to find.
     */
    public func index(of object: Element) -> Int? {
        return notFoundToNil(index: _rlmArray.index(of: dynamicBridgeCast(fromSwift: object) as AnyObject))
    }

    /**
     Returns the index of the first object in the list matching the predicate, or `nil` if no objects match.

     - parameter predicate: The predicate with which to filter the objects.
    */
    public func index(matching predicate: NSPredicate) -> Int? {
        return notFoundToNil(index: _rlmArray.indexOfObject(with: predicate))
    }

    /**
     Returns the index of the first object in the list matching the predicate, or `nil` if no objects match.

     - parameter predicateFormat: A predicate format string, optionally followed by a variable number of arguments.
    */
    public func index(matching predicateFormat: String, _ args: Any...) -> Int? {
        return index(matching: NSPredicate(format: predicateFormat, argumentArray: unwrapOptionals(in: args)))
    }

    // MARK: Object Retrieval

    /**
     Returns the object at the given index (get), or replaces the object at the given index (set).

     - warning: You can only set an object during a write transaction.

     - parameter index: The index of the object to retrieve or replace.
     */
    public subscript(position: Int) -> Element {
        get {
            throwForNegativeIndex(position)
            return dynamicBridgeCast(fromObjectiveC: _rlmArray.object(at: UInt(position)))
        }
        set {
            throwForNegativeIndex(position)
            _rlmArray.replaceObject(at: UInt(position), with: dynamicBridgeCast(fromSwift: newValue) as AnyObject)
        }
    }

    /// Returns the first object in the list, or `nil` if the list is empty.
    public var first: Element? { return _rlmArray.firstObject().map(dynamicBridgeCast) }

    /// Returns the last object in the list, or `nil` if the list is empty.
    public var last: Element? { return _rlmArray.lastObject().map(dynamicBridgeCast) }

    // MARK: KVC

    /**
     Returns an `Array` containing the results of invoking `valueForKey(_:)` using `key` on each of the collection's
     objects.
     */
    @nonobjc public func value(forKey key: String) -> [AnyObject] {
        return _rlmArray.value(forKeyPath: key)! as! [AnyObject]
    }

    /**
     Returns an `Array` containing the results of invoking `valueForKeyPath(_:)` using `keyPath` on each of the
     collection's objects.

     - parameter keyPath: The key path to the property whose values are desired.
     */
    @nonobjc public func value(forKeyPath keyPath: String) -> [AnyObject] {
        return _rlmArray.value(forKeyPath: keyPath) as! [AnyObject]
    }

    /**
     Invokes `setValue(_:forKey:)` on each of the collection's objects using the specified `value` and `key`.

     - warning: This method can only be called during a write transaction.

     - parameter value: The object value.
     - parameter key:   The name of the property whose value should be set on each object.
    */
    public override func setValue(_ value: Any?, forKey key: String) {
        return _rlmArray.setValue(value, forKeyPath: key)
    }

    // MARK: Filtering

    /**
     Returns a `Results` containing all objects matching the given predicate in the list.

     - parameter predicateFormat: A predicate format string, optionally followed by a variable number of arguments.
    */
    public func filter(_ predicateFormat: String, _ args: Any...) -> Results<Element> {
        return Results<Element>(_rlmArray.objects(with: NSPredicate(format: predicateFormat,
                                                              argumentArray: unwrapOptionals(in: args))))
    }

    /**
     Returns a `Results` containing all objects matching the given predicate in the list.

     - parameter predicate: The predicate with which to filter the objects.
     */
    public func filter(_ predicate: NSPredicate) -> Results<Element> {
        return Results<Element>(_rlmArray.objects(with: predicate))
    }

    // MARK: Sorting

    /**
     Returns a `Results` containing the objects in the list, but sorted.

     Objects are sorted based on the values of the given key path. For example, to sort a list of `Student`s from
     youngest to oldest based on their `age` property, you might call
     `students.sorted(byKeyPath: "age", ascending: true)`.

     - warning: Lists may only be sorted by properties of boolean, `Date`, `NSDate`, single and double-precision
                floating point, integer, and string types.

     - parameter keyPath:  The key path to sort by.
     - parameter ascending: The direction to sort in.
     */
    public func sorted(byKeyPath keyPath: String, ascending: Bool = true) -> Results<Element> {
        return sorted(by: [SortDescriptor(keyPath: keyPath, ascending: ascending)])
    }

    /**
     Returns a `Results` containing the objects in the list, but sorted.

     - warning: Lists may only be sorted by properties of boolean, `Date`, `NSDate`, single and double-precision
                floating point, integer, and string types.

     - see: `sorted(byKeyPath:ascending:)`
    */
    public func sorted<S: Sequence>(by sortDescriptors: S) -> Results<Element>
        where S.Iterator.Element == SortDescriptor {
            return Results<Element>(_rlmArray.sortedResults(using: sortDescriptors.map { $0.rlmSortDescriptorValue }))
    }

    // MARK: Aggregate Operations

    /**
     Returns the minimum (lowest) value of the given property among all the objects in the list, or `nil` if the list is
     empty.

     - warning: Only a property whose type conforms to the `MinMaxType` protocol can be specified.

     - parameter property: The name of a property whose minimum value is desired.
     */
    public func min<T: MinMaxType>(ofProperty property: String) -> T? {
        return _rlmArray.min(ofProperty: property).map(dynamicBridgeCast)
    }

    /**
     Returns the maximum (highest) value of the given property among all the objects in the list, or `nil` if the list
     is empty.

     - warning: Only a property whose type conforms to the `MinMaxType` protocol can be specified.

     - parameter property: The name of a property whose maximum value is desired.
     */
    public func max<T: MinMaxType>(ofProperty property: String) -> T? {
        return _rlmArray.max(ofProperty: property).map(dynamicBridgeCast)
    }

    /**
     Returns the sum of the values of a given property over all the objects in the list.

     - warning: Only a property whose type conforms to the `AddableType` protocol can be specified.

     - parameter property: The name of a property whose values should be summed.
     */
    public func sum<T: AddableType>(ofProperty property: String) -> T {
        return dynamicBridgeCast(fromObjectiveC: _rlmArray.sum(ofProperty: property))
    }

    /**
     Returns the average value of a given property over all the objects in the list, or `nil` if the list is empty.

     - warning: Only a property whose type conforms to the `AddableType` protocol can be specified.

     - parameter property: The name of a property whose average value should be calculated.
     */
    public func average(ofProperty property: String) -> Double? {
        return _rlmArray.average(ofProperty: property).map(dynamicBridgeCast)
    }

    // MARK: Mutation

    /**
     Appends the given object to the end of the list.

     If the object is managed by a different Realm than the receiver, a copy is made and added to the Realm managing
     the receiver.

     - warning: This method may only be called during a write transaction.

     - parameter object: An object.
     */
    public func append(_ object: Element) {
        _rlmArray.add(dynamicBridgeCast(fromSwift: object) as AnyObject)
    }

    /**
     Appends the objects in the given sequence to the end of the list.

     - warning: This method may only be called during a write transaction.
    */
    public func append<S: Sequence>(objectsIn objects: S) where S.Iterator.Element == Element {
        for obj in objects {
            _rlmArray.add(dynamicBridgeCast(fromSwift: obj) as AnyObject)
        }
    }

    /**
     Inserts an object at the given index.

     - warning: This method may only be called during a write transaction.

     - warning: This method will throw an exception if called with an invalid index.

     - parameter object: An object.
     - parameter index:  The index at which to insert the object.
     */
    public func insert(_ object: Element, at index: Int) {
        throwForNegativeIndex(index)
        _rlmArray.insert(dynamicBridgeCast(fromSwift: object) as AnyObject, at: UInt(index))
    }

    /**
     Removes an object at the given index. The object is not removed from the Realm that manages it.

     - warning: This method may only be called during a write transaction.

     - warning: This method will throw an exception if called with an invalid index.

     - parameter index: The index at which to remove the object.
     */
    public func remove(at index: Int) {
        throwForNegativeIndex(index)
        _rlmArray.removeObject(at: UInt(index))
    }

    /**
     Removes all objects from the list. The objects are not removed from the Realm that manages them.

     - warning: This method may only be called during a write transaction.
     */
    public func removeAll() {
        _rlmArray.removeAllObjects()
    }

    /**
     Replaces an object at the given index with a new object.

     - warning: This method may only be called during a write transaction.

     - warning: This method will throw an exception if called with an invalid index.

     - parameter index:  The index of the object to be replaced.
     - parameter object: An object.
     */
    public func replace(index: Int, object: Element) {
        throwForNegativeIndex(index)
        _rlmArray.replaceObject(at: UInt(index), with: dynamicBridgeCast(fromSwift: object) as AnyObject)
    }

    /**
     Moves the object at the given source index to the given destination index.

     - warning: This method may only be called during a write transaction.

     - warning: This method will throw an exception if called with invalid indices.

     - parameter from:  The index of the object to be moved.
     - parameter to:    index to which the object at `from` should be moved.
     */
    public func move(from: Int, to: Int) {
        throwForNegativeIndex(from)
        throwForNegativeIndex(to)
        _rlmArray.moveObject(at: UInt(from), to: UInt(to))
    }

    /**
     Exchanges the objects in the list at given indices.

     - warning: This method may only be called during a write transaction.

     - warning: This method will throw an exception if called with invalid indices.

     - parameter index1: The index of the object which should replace the object at index `index2`.
     - parameter index2: The index of the object which should replace the object at index `index1`.
     */
    public func swapAt(_ index1: Int, _ index2: Int) {
        throwForNegativeIndex(index1, parameterName: "index1")
        throwForNegativeIndex(index2, parameterName: "index2")
        _rlmArray.exchangeObject(at: UInt(index1), withObjectAt: UInt(index2))
    }

    // MARK: Notifications

    /**
     Registers a block to be called each time the collection changes.

     The block will be asynchronously called with the initial results, and then called again after each write
     transaction which changes either any of the objects in the collection, or which objects are in the collection.

     The `change` parameter that is passed to the block reports, in the form of indices within the collection, which of
     the objects were added, removed, or modified during each write transaction. See the `RealmCollectionChange`
     documentation for more information on the change information supplied and an example of how to use it to update a
     `UITableView`.

     At the time when the block is called, the collection will be fully evaluated and up-to-date, and as long as you do
     not perform a write transaction on the same thread or explicitly call `realm.refresh()`, accessing it will never
     perform blocking work.

     Notifications are delivered via the standard run loop, and so can't be delivered while the run loop is blocked by
     other activity. When notifications can't be delivered instantly, multiple notifications may be coalesced into a
     single notification. This can include the notification with the initial collection.

     For example, the following code performs a write transaction immediately after adding the notification block, so
     there is no opportunity for the initial notification to be delivered first. As a result, the initial notification
     will reflect the state of the Realm after the write transaction.

     ```swift
     let results = realm.objects(Dog.self)
     print("dogs.count: \(dogs?.count)") // => 0
     let token = dogs.observe { changes in
         switch changes {
         case .initial(let dogs):
             // Will print "dogs.count: 1"
             print("dogs.count: \(dogs.count)")
             break
         case .update:
             // Will not be hit in this example
             break
         case .error:
             break
         }
     }
     try! realm.write {
         let dog = Dog()
         dog.name = "Rex"
         person.dogs.append(dog)
     }
     // end of run loop execution context
     ```

     You must retain the returned token for as long as you want updates to be sent to the block. To stop receiving
     updates, call `invalidate()` on the token.

     - warning: This method cannot be called during a write transaction, or when the containing Realm is read-only.

     - parameter block: The block to be called whenever a change occurs.
     - returns: A token which must be held for as long as you want updates to be delivered.
     */
    public func observe(_ block: @escaping (RealmCollectionChange<List>) -> Void) -> NotificationToken {
        return _rlmArray.addNotificationBlock { _, change, error in
            block(RealmCollectionChange.fromObjc(value: self, change: change, error: error))
        }
    }
}

extension List where Element: MinMaxType {
    /**
     Returns the minimum (lowest) value in the list, or `nil` if the list is empty.
     */
    public func min() -> Element? {
        return _rlmArray.min(ofProperty: "self").map(dynamicBridgeCast)
    }

    /**
     Returns the maximum (highest) value in the list, or `nil` if the list is empty.
     */
    public func max() -> Element? {
        return _rlmArray.max(ofProperty: "self").map(dynamicBridgeCast)
    }
}

extension List where Element: AddableType {
    /**
     Returns the sum of the values in the list.
     */
    public func sum() -> Element {
        return sum(ofProperty: "self")
    }

    /**
     Returns the average of the values in the list, or `nil` if the list is empty.
     */
    public func average() -> Double? {
        return average(ofProperty: "self")
    }
}

extension List: RealmCollection {
    /// The type of the objects stored within the list.
    public typealias ElementType = Element

    // MARK: Sequence Support

    /// Returns a `RLMIterator` that yields successive elements in the `List`.
    public func makeIterator() -> RLMIterator<Element> {
        return RLMIterator(collection: _rlmArray)
    }

#if swift(>=4)
    /**
     Replace the given `subRange` of elements with `newElements`.

     - parameter subrange:    The range of elements to be replaced.
     - parameter newElements: The new elements to be inserted into the List.
     */
    public func replaceSubrange<C: Collection, R>(_ subrange: R, with newElements: C)
        where C.Iterator.Element == Element, R: RangeExpression, List<Element>.Index == R.Bound {
            let subrange = subrange.relative(to: self)
            for _ in subrange.lowerBound..<subrange.upperBound {
                remove(at: subrange.lowerBound)
            }
            for x in newElements.reversed() {
                insert(x, at: subrange.lowerBound)
            }
    }
#else
    /**
     Replace the given `subRange` of elements with `newElements`.

     - parameter subrange:    The range of elements to be replaced.
     - parameter newElements: The new elements to be inserted into the List.
     */
    public func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with newElements: C)
        where C.Iterator.Element == Element {
            for _ in subrange.lowerBound..<subrange.upperBound {
                remove(at: subrange.lowerBound)
            }
            for x in newElements.reversed() {
                insert(x, at: subrange.lowerBound)
            }
    }
#endif

    /// The position of the first element in a non-empty collection.
    /// Identical to endIndex in an empty collection.
    public var startIndex: Int { return 0 }

    /// The collection's "past the end" position.
    /// endIndex is not a valid argument to subscript, and is always reachable from startIndex by
    /// zero or more applications of successor().
    public var endIndex: Int { return count }

    public func index(after i: Int) -> Int { return i + 1 }
    public func index(before i: Int) -> Int { return i - 1 }

    /// :nodoc:
    public func _observe(_ block: @escaping (RealmCollectionChange<AnyRealmCollection<Element>>) -> Void) -> NotificationToken {
        let anyCollection = AnyRealmCollection(self)
        return _rlmArray.addNotificationBlock { _, change, error in
            block(RealmCollectionChange.fromObjc(value: anyCollection, change: change, error: error))
        }
    }
}

#if swift(>=4.0)
// MARK: - MutableCollection conformance, range replaceable collection emulation
extension List: MutableCollection {
#if swift(>=4.1)
    public typealias SubSequence = Slice<List>
#else
    public typealias SubSequence = RandomAccessSlice<List>
#endif

    /**
     Returns the objects at the given range (get), or replaces the objects at the
     given range with new objects (set).

     - warning: Objects may only be set during a write transaction.

     - parameter index: The index of the object to retrieve or replace.
     */
    public subscript(bounds: Range<Int>) -> SubSequence {
        get {
            return SubSequence(base: self, bounds: bounds)
        }
        set {
            replaceSubrange(bounds.lowerBound..<bounds.upperBound, with: newValue)
        }
    }

    /**
     Removes the specified number of objects from the beginning of the list. The
     objects are not removed from the Realm that manages them.

     - warning: This method may only be called during a write transaction.
     */
    public func removeFirst(_ number: Int = 1) {
        let count = Int(_rlmArray.count)
        guard number <= count else {
            throwRealmException("It is not possible to remove more objects (\(number)) from a list"
                + " than it already contains (\(count)).")
            return
        }
        for _ in 0..<number {
            _rlmArray.removeObject(at: 0)
        }
    }

    /**
     Removes the specified number of objects from the end of the list. The objects
     are not removed from the Realm that manages them.

     - warning: This method may only be called during a write transaction.
     */
    public func removeLast(_ number: Int = 1) {
        let count = Int(_rlmArray.count)
        guard number <= count else {
            throwRealmException("It is not possible to remove more objects (\(number)) from a list"
                + " than it already contains (\(count)).")
            return
        }
        for _ in 0..<number {
            _rlmArray.removeLastObject()
        }
    }

    /**
     Inserts the items in the given collection into the list at the given position.

     - warning: This method may only be called during a write transaction.
     */
    public func insert<C: Collection>(contentsOf newElements: C, at i: Int) where C.Iterator.Element == Element {
        var currentIndex = i
        for item in newElements {
            insert(item, at: currentIndex)
            currentIndex += 1
        }
    }
    #if swift(>=4.1.50)
    /**
     Removes objects from the list at the given range.

     - warning: This method may only be called during a write transaction.
     */
    public func removeSubrange<R>(_ boundsExpression: R) where R: RangeExpression, List<Element>.Index == R.Bound {
        let bounds = boundsExpression.relative(to: self)
        for _ in bounds {
            remove(at: bounds.lowerBound)
        }
    }
    #else
    /**
     Removes objects from the list at the given range.

     - warning: This method may only be called during a write transaction.
     */
    public func removeSubrange(_ bounds: Range<Int>) {
        removeSubrange(bounds.lowerBound..<bounds.upperBound)
    }

    /// :nodoc:
    public func removeSubrange(_ bounds: ClosedRange<Int>) {
        removeSubrange(bounds.lowerBound...bounds.upperBound)
    }

    /// :nodoc:
    public func removeSubrange(_ bounds: CountableRange<Int>) {
        for _ in bounds {
            remove(at: bounds.lowerBound)
        }
    }

    /// :nodoc:
    public func removeSubrange(_ bounds: CountableClosedRange<Int>) {
        for _ in bounds {
            remove(at: bounds.lowerBound)
        }
    }

    /// :nodoc:
    public func removeSubrange(_ bounds: DefaultRandomAccessIndices<List>) {
        removeSubrange(bounds.startIndex..<bounds.endIndex)
    }

    /// :nodoc:
    public func replaceSubrange<C: Collection>(_ subrange: ClosedRange<Int>, with newElements: C)
        where C.Iterator.Element == Element {
            removeSubrange(subrange)
            insert(contentsOf: newElements, at: subrange.lowerBound)
    }

    /// :nodoc:
    public func replaceSubrange<C: Collection>(_ subrange: CountableRange<Int>, with newElements: C)
        where C.Iterator.Element == Element {
            removeSubrange(subrange)
            insert(contentsOf: newElements, at: subrange.lowerBound)
    }

    /// :nodoc:
    public func replaceSubrange<C: Collection>(_ subrange: CountableClosedRange<Int>, with newElements: C)
        where C.Iterator.Element == Element {
            removeSubrange(subrange)
            insert(contentsOf: newElements, at: subrange.lowerBound)
    }


    /// :nodoc:
    public func replaceSubrange<C: Collection>(_ subrange: DefaultRandomAccessIndices<List>, with newElements: C)
        where C.Iterator.Element == Element {
            removeSubrange(subrange)
            insert(contentsOf: newElements, at: subrange.startIndex)
    }
#endif
}
#else
// MARK: - RangeReplaceableCollection support
extension List: RangeReplaceableCollection {
    /**
     Removes the last object in the list. The object is not removed from the Realm that manages it.

     - warning: This method may only be called during a write transaction.
     */
    public func removeLast() {
        guard _rlmArray.count > 0 else {
            throwRealmException("It is not possible to remove an object from an empty list.")
            return
        }
        _rlmArray.removeLastObject()
    }

}
#endif

// MARK: - Codable

extension List: Decodable where Element: Decodable {
    public convenience init(from decoder: Decoder) throws {
        self.init()
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            append(try container.decode(Element.self))
        }
    }
}

extension List: Encodable where Element: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for value in self {
            try container.encode(value)
        }
    }
}

// MARK: - AssistedObjectiveCBridgeable

extension List: AssistedObjectiveCBridgeable {
    internal static func bridging(from objectiveCValue: Any, with metadata: Any?) -> List {
        guard let objectiveCValue = objectiveCValue as? RLMArray<AnyObject> else { preconditionFailure() }
        return List(rlmArray: objectiveCValue)
    }

    internal var bridged: (objectiveCValue: Any, metadata: Any?) {
        return (objectiveCValue: _rlmArray, metadata: nil)
    }
}
// MARK: - Unavailable

extension List {
    @available(*, unavailable, renamed: "remove(at:)")
    public func remove(objectAtIndex: Int) { fatalError() }
}
