-- Test 4424: CTE - CTE used in INSERT

return {
  number = 4424,
  description = "CTE - CTE used in INSERT",
  database = "vim_dadbod_test",
  query = [[WITH SourceData AS (SELECT * FROM Employees WHERE DepartmentID = 1)
INSERT INTO Projects SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "SourceData",
        "Employees",
      },
    },
    type = "table",
  },
}
