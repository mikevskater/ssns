-- Test 4790: Stress - mixed DML in batch

return {
  number = 4790,
  description = "Stress - mixed DML in batch",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Multi-statement batch table resolution not yet supported",
  query = "INSERT INTO Log VALUES (1); UPDATE Stats SET Count = Count + 1; SELECT █ FROM Employees",
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
