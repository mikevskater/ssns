-- Test 4356: ON clause - compatible date types

return {
  number = 4356,
  description = "ON clause - compatible date types",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Projects p ON e.HireDate = p.StartDat█e",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
