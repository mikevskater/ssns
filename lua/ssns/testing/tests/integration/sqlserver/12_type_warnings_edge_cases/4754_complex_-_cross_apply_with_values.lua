-- Test 4754: Complex - CROSS APPLY with VALUES

return {
  number = 4754,
  description = "Complex - CROSS APPLY with VALUES",
  database = "vim_dadbod_test",
  query = "SELECT e.EmployeeID, v. FR█OM Employees e CROSS APPLY (VALUES (1, 'A'), (2, 'B')) v(Num, Letter)",
  expected = {
    items = {
      includes = {
        "Num",
        "Letter",
      },
    },
    type = "column",
  },
}
