from std / json import JsonNode
from std / jsonutils import toJson

proc convertToJson*[T](a : T) : JsonNode = toJson(a)