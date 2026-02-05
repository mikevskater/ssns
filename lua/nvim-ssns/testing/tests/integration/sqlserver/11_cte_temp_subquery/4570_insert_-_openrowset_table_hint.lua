-- Test 4570: INSERT - OPENROWSET table hint

return {
  number = 4570,
  description = "INSERT - OPENROWSET table hint",
  database = "vim_dadbod_test",
  query = [[INSERT INTO Employees WITH (TABLOCK) ()█
VALUES (1, 'John')]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
