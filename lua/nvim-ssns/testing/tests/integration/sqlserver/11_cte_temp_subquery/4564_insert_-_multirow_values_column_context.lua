-- Test 4564: INSERT - multirow VALUES column context

return {
  number = 4564,
  description = "INSERT - multirow VALUES column context",
  database = "vim_dadbod_test",
  query = [[INSERT INTO Employees (EmployeeID, FirstName, LastName)
VALUES (1, 'John', 'Doe'),
       (2, 'Jane', 'Smith'),
       (3, █, 'Johnson')]],
  expected = {
    items = {
    },
    type = "none",
  },
}
