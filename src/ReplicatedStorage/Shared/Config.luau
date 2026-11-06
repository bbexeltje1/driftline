--!strict
-- Shared tuning. The server owns every authoritative number; this is read by both sides.
return {
	displayName = "Game 2",
	buildLabel = "0.1.0",
	-- Publish this attribute and the client knows the server finished starting up.
	readyAttribute = "ServerReady",
}
