-- Test 4612: DELETE - OUTPUT INTO
-- Tests table completion for OUTPUT INTO clause in DELETE statement

return {
  number = 4612,
  description = "DELETE - OUTPUT INTO",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #Deleted (EmployeeID INT, FirstName VARCHAR(50), LastName VARCHAR(50))
DELETE FROM Employees
OUTPUT deleted.* INTO █]],
  expected = {
    items = {
      includes = {
        "#Deleted",
      },
    },
    type = "table",
  },
}
