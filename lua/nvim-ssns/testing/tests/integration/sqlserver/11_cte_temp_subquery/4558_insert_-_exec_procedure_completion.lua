-- Test 4558: INSERT - EXEC procedure completion
-- SKIPPED: INSERT EXEC procedure completion not yet supported

return {
  number = 4558,
  description = "INSERT - EXEC procedure completion",
  database = "vim_dadbod_test",
  skip = false,
  query = "INSERT INTO Projects EXEC █",
  expected = {
    items = {
      includes_any = {
        "usp_GetEmployeesByDepartment",
        "usp_InsertEmployee",
      },
    },
    type = "procedure",
  },
}
