# Cilium's `toPorts` from a flat list of ports as a NetworkPolicy writes them: port numbers, or `{ port; protocol; }`
# with `endPort` for a range. Cilium takes the port as a string. No ports gives null, which leaves the field out
ports:
if ports == [ ] then
  null
else
  [ { ports = map (p: if builtins.isInt p then { port = toString p; } else p // { port = toString p.port; }) ports; } ]
