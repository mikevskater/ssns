-- Test 4786: Stress - complex WHERE with many conditions

return {
  number = 4786,
  description = "Stress - complex WHERE with many conditions",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE (A = 1 OR B = 2) AND (C = 3 OR D = 4) AND (E = 5 OR F = 6) AND (G = 7 OR H = 8) █AND ",
  expected = {
    items = {
      includes_any = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
