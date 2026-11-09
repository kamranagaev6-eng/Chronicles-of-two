class_name TransactionLog
extends RefCounted
## Host transactions with unique IDs: gifts, trades, crafting, reward claims and loadout changes.
## A repeated request returns the recorded result instead of running again, so a duplicated packet can
## neither duplicate nor lose anything.

var capacity: int = 4096
var _results: Dictionary = {}
var _order: Array[String] = []


func has(txn_id: String) -> bool:
	return _results.has(txn_id)


## Run `action` once for this transaction ID and return its result; later calls return the same result.
func execute(txn_id: String, action: Callable) -> Variant:
	if _results.has(txn_id):
		return _results[txn_id]
	var result: Variant = action.call()
	_results[txn_id] = result
	_order.append(txn_id)
	while _order.size() > capacity:
		_results.erase(_order[0])
		_order.remove_at(0)
	return result


func size() -> int:
	return _results.size()
