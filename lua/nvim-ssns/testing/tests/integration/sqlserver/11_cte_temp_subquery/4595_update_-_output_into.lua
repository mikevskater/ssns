-- Test 4595: UPDATE - OUTPUT INTO
-- Tests table completion for OUTPUT INTO clause in UPDATE statement

return {
  number = 4595,
  description = "UPDATE - OUTPUT INTO",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #SalaryChanges (OldSalary DECIMAL(10,2), NewSalary DECIMAL(10,2))
UPDATE Employees SET Salary = Salary * 1.1
OUTPUT deleted.Salary, inserted.Salary INTO █]],
  expected = {
    items = {
      includes = {
        "#SalaryChanges",
      },
    },
    type = "table",
  },
}
