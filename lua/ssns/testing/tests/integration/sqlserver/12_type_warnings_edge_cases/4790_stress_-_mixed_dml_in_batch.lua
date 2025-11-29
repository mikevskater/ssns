-- Test 4790: Stress - mixed DML in batch

return {
  number = 4790,
  description = "Stress - mixed DML in batch",
  database = "vim_dadbod_test",
  query = "INSERT INTO Log VALUES (1); UPDATE Stats SET Count = Count + 1; SELECT  FRO█M Employees",
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
