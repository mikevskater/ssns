-- Test 4560: INSERT - OUTPUT clause columns
-- SKIPPED: inserted/deleted pseudo-table column completion not yet supported

return {
  number = 4560,
  description = "INSERT - OUTPUT clause columns",
  database = "vim_dadbod_test",
  skip = false,
  query = [[INSERT INTO Employees (FirstName, LastName)
OUTPUT inserted.█
VALUES ('John', 'Doe')]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
