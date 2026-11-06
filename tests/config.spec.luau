assert(type(Config) == "table", "Config is a table")
assert(type(Config.displayName) == "string" and #Config.displayName > 0, "Config has a display name")
assert(type(Config.readyAttribute) == "string", "Config names the readiness attribute")
print("PASS Config: display name and readiness attribute present")
